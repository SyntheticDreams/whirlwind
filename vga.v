/*
   Whirlwind NES - NES compatible FPGA core
   Copyright (C) 2020  Anthony Westbrook (twestbrook@oursyntheticdreams.com)

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

module vga(
	input vga_clk_in,
	input write_clk_in,
	input write_in,
	input [7:0] data_in,
	output wire vga_csync_out,
	output wire vga_blank_out,
	output reg vga_hsync_out, 
	output reg vga_vsync_out,
	output reg [7:0] vga_red_out,
	output reg [7:0] vga_green_out,
	output reg [7:0] vga_blue_out,
	
	input [9:0] switches_in,
	output reg [15:0] debug_out
);

// Variable parameters - timing (assumes correct dot clock) and playfield related
parameter HORIZ_ACTIVE = 16'd640;
parameter HORIZ_FRONT = 16'd16;
parameter HORIZ_SYNC = 16'd96; 
parameter HORIZ_BACK = 16'd48;
parameter VERT_ACTIVE = 16'd480;
parameter VERT_FRONT = 16'd11;
parameter VERT_SYNC = 16'd2;
parameter VERT_BACK = 16'd31;

parameter FRAME_WIDTH = 16'd256;
parameter FRAME_HEIGHT = 16'd240;
parameter FRAME_SHIFT_X = 16'd1;
parameter FRAME_SHIFT_Y = 16'd1;

// Precompute values based off of parameters (A=Active, F=Front Porch, S=Sync, B=Back Porch)
localparam HORIZ_AF = HORIZ_ACTIVE + HORIZ_FRONT;
localparam HORIZ_AFS = HORIZ_ACTIVE + HORIZ_FRONT + HORIZ_SYNC;
localparam HORIZ_AFSB = HORIZ_ACTIVE + HORIZ_FRONT + HORIZ_SYNC + HORIZ_BACK;
localparam VERT_AF = VERT_ACTIVE + VERT_FRONT;
localparam VERT_AFS = VERT_ACTIVE + VERT_FRONT + VERT_SYNC;
localparam VERT_AFSB = VERT_ACTIVE + VERT_FRONT + VERT_SYNC + VERT_BACK;

localparam FRAME_VGA_START_X = (HORIZ_ACTIVE - (FRAME_WIDTH << FRAME_SHIFT_X)) >> 1;
localparam FRAME_VGA_END_X = HORIZ_ACTIVE - FRAME_VGA_START_X;
localparam FRAME_VGA_START_Y = (VERT_ACTIVE - (FRAME_HEIGHT << FRAME_SHIFT_Y)) >> 1;
localparam FRAME_VGA_END_Y = VERT_ACTIVE - FRAME_VGA_START_Y;

// Registers
reg [15:0] vga_raster_x;
reg [15:0] vga_raster_y;
reg [1:0] frame_read_cur;
reg [1:0] frame_write_cur;
reg [1:0] frame_write_last;
reg [15:0] frame_write_address;

// Wires and assignments
wire raster_active;
wire [15:0] frame_read_address;
wire [7:0] frame_read_data;
wire [2:0] frame_clock;
wire [2:0] frame_write_en;
wire [15:0] frame_address[2:0];
wire [7:0] frame_data_out[2:0];

assign vga_csync_out = 0;  
assign vga_blank_out = 1;
assign raster_active = (vga_raster_x >= FRAME_VGA_START_X && vga_raster_x < FRAME_VGA_END_X && vga_raster_y >= FRAME_VGA_START_Y && vga_raster_y < FRAME_VGA_END_Y);
assign frame_read_address = (((vga_raster_x - FRAME_VGA_START_X + 16'd1) >> FRAME_SHIFT_X) + (((vga_raster_y - FRAME_VGA_START_Y) >> FRAME_SHIFT_Y) * FRAME_WIDTH)) % (FRAME_WIDTH * FRAME_HEIGHT);
assign frame_read_data = frame_data_out[frame_read_cur];

// Setup frame memory
genvar frame;
generate
	for (frame = 0; frame < 3; frame = frame + 1) begin : frame_instantiate
		frame_ram frame_ram(.address(frame_address[frame]), .clock(frame_clock[frame]), .data(data_in), .wren(frame_write_en[frame]), .q(frame_data_out[frame]));	
		assign frame_clock[frame] = (frame_read_cur == frame) ? vga_clk_in : (frame_write_cur == frame) ? write_clk_in : 1'd0;
		assign frame_write_en[frame] = (frame_write_cur == frame) ? write_in : 1'd0;
		assign frame_address[frame] = (frame_read_cur == frame) ? frame_read_address : (frame_write_cur == frame) ? frame_write_address : 16'd0;
	end
endgenerate



// Process vertical and horizontal sync lines according to timing
task process_vga_sync;
	begin
		vga_hsync_out <= ~(vga_raster_x >= HORIZ_AF && vga_raster_x < HORIZ_AFS);
		vga_vsync_out <= ~(vga_raster_y >= VERT_AF && vga_raster_y < VERT_AFS);
	end
endtask

// Raster processing
task raster;
	begin
		{vga_blue_out, vga_green_out, vga_red_out} <= 0;
		
		if (raster_active) begin
			vga_red_out <= {frame_read_data[7:5], 5'b00000};
			vga_green_out <= {frame_read_data[4:2], 5'b00000};
			vga_blue_out <= {frame_read_data[1:0], 6'b000000};
		end
		
	end
endtask

// Advance for next read cycle
task next_read_cycle;
	reg [15:0] temp_raster_x;
	reg [15:0] temp_raster_y;
	
	begin
		temp_raster_x = vga_raster_x;
		temp_raster_y = vga_raster_y;
		
		// Advance raster
		temp_raster_x = temp_raster_x + 16'b1;
		
		if (temp_raster_x == HORIZ_AFSB) begin
			temp_raster_x = 16'b0;
			temp_raster_y = temp_raster_y + 16'b1;
		end
		
		if (temp_raster_y == VERT_AFSB) begin
			temp_raster_y = 0;
		end
		
		// Switch to last written frame during vsync
		if (~vga_vsync_out) begin
			frame_read_cur <= frame_write_last;
		end
		
		vga_raster_x <= temp_raster_x;
		vga_raster_y <= temp_raster_y;
	end
endtask

// Advance for next write cycle
task next_write_cycle;
	reg [15:0] temp_write_address;
	
	begin
		temp_write_address = frame_write_address;
		
		if (write_in) begin
			temp_write_address = temp_write_address + 16'h0001;
		end
		
		if (temp_write_address == (FRAME_WIDTH * FRAME_HEIGHT)) begin			
			// Record last frame and select new frame
			frame_write_last <= frame_write_cur;
			if (frame_write_cur != 0 && frame_read_cur != 0) frame_write_cur <= 2'h0;
			else if (frame_write_cur != 1 && frame_read_cur != 1) frame_write_cur <= 2'h1;
			else if (frame_write_cur != 2 && frame_read_cur != 2) frame_write_cur <= 2'h2;

			// Reset write position
			temp_write_address = 16'h0000;
		end
		
		frame_write_address <= temp_write_address;
	end
endtask


/*************** Synchronous Processing ***************/
initial begin
	vga_hsync_out <= 1; 
	vga_vsync_out <= 1;
	vga_red_out <= 8'b0;
	vga_green_out <= 8'b0;
	vga_blue_out <= 8'b0;
	vga_raster_x <= 16'h00;
	vga_raster_y <= 16'h00;
	
	frame_read_cur <= 2'h0;
	frame_write_cur <= 2'h2;
	frame_write_last <= 2'h0;
	frame_write_address <= 16'h0000;
end

// Frame reading
always @ (posedge vga_clk_in) begin
	// VGA sync timing
	process_vga_sync();

	// Rasterize
	raster();
			
	// Prepare for next read cycle
	next_read_cycle();	
end

// Frame writing
always @ (posedge write_clk_in) begin		
	// Prepare for next write cycle
	next_write_cycle();	
end


endmodule