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

module joy(
	input cpu_clk_in,
	input cpu_read_in,
	input cpu_write_in,	
	input [15:0] cpu_address_in,
	input [7:0] cpu_data_in,
	input [5:0] joystick_in,
	input [3:0] buttons_in,
	output reg cpu_data_en_out,
	output reg [7:0] cpu_data_out,
	
	input [9:0] switches_in,	
	output reg [15:0] debug_out
);

localparam IO_JOY_START = 16'h4016;
localparam IO_JOY_SIZE = 16'h0001;
localparam IO_JOY_STATUS = 16'h4016;
localparam JOY_UP = 0;
localparam JOY_LEFT = 1;
localparam JOY_RIGHT = 2;
localparam JOY_DOWN = 3;
localparam JOY_BUTTON_A = 4;
localparam JOY_BUTTON_B = 5;

reg strobe;
reg [3:0] bit_pos;
reg [7:0] state;

wire io_enable;

assign io_enable = (cpu_address_in >= IO_JOY_START) && (cpu_address_in < (IO_JOY_START + IO_JOY_SIZE));

// Process CPU IO
task cpu_io;
	reg update_registers;
	
	begin
		update_registers = 0;
		
		if (io_enable) begin
			// Writes
			if (cpu_write_in) begin
				if (cpu_address_in == IO_JOY_STATUS) begin
					state <= {joystick_in[JOY_RIGHT], joystick_in[JOY_LEFT], joystick_in[JOY_DOWN], joystick_in[JOY_UP], buttons_in[0], buttons_in[1], joystick_in[JOY_BUTTON_B], joystick_in[JOY_BUTTON_A]};
					strobe <= cpu_data_in[0];
					bit_pos <= 0;
				end
			end
		
			// Reads
			if (cpu_read_in) begin
				// Provide data for status register
				if (cpu_address_in == IO_JOY_STATUS) begin
					if (strobe) begin
						cpu_data_out <= {7'b0000000, ~joystick_in[JOY_BUTTON_A]};
					end
					else if (bit_pos < 8) begin
						cpu_data_out <= {7'b0000000, ~state[bit_pos]};
						bit_pos <= bit_pos + 4'h1;
					end
					else begin
						cpu_data_out <= 8'h01;
						
					end
					
					cpu_data_en_out <= 1;
				end
			end
		end		
	end
endtask

task init_output;
	begin
		cpu_data_out <= 0;
		cpu_data_en_out <= 0;
	end
endtask

initial begin
	strobe = 0;
	bit_pos = 4'h0;
	state = 8'h00;
end

// CPU clock - process logic and IO
always @ (posedge cpu_clk_in) begin
	init_output();
	cpu_io();
end

endmodule