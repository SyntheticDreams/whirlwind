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

module ppu(
	input ppu_clk_in,
	input cpu_clk_in,
	input cpu_read_in,
	input cpu_write_in,
	input [15:0] cpu_address_in,
	input [7:0] cpu_data_in,
	input [7:0] ppu_data_in,
	input [7:0] ram_data_in,
	output ppu_nmi_out,
	output reg ppu_read_out,
	output reg ppu_write_out,
	output reg ppu_raster_write_out,
	output reg cpu_address_en_out,
	output reg cpu_data_en_out,
	output reg cpu_disable_out,
	output reg [15:0] cpu_address_out,
	output reg [13:0] ppu_address_out,
	output reg [7:0] cpu_data_out,
	output reg [7:0] ppu_data_out,
	output reg [7:0] ppu_raster_data_out,
	
	input [9:0] switches_in,
	output reg [15:0] debug_out
);

// Constant parameters
localparam HORIZ_TOTAL = 16'd340;
localparam VERT_TOTAL = 16'd262;
localparam HORIZ_VISIBLE = 16'd256;
localparam VERT_VISIBLE = 16'd240;
localparam SET_FLAGS_X = 16'd1;
localparam FINAL_NT_FETCH_X = 16'd321;
localparam OAM_DMA_SETUP = 9'h00A;
localparam IO_PPU_START = 16'h2000;
localparam IO_PPU_SIZE = 16'h1FFF;
localparam IO_PALETTE_START = 16'h3F00;
localparam IO_PALETTE_SIZE = 16'h0100;
localparam IO_PPU_CTRL = 16'h2000;
localparam IO_PPU_MASK = 16'h2001;
localparam IO_PPU_STATUS = 16'h2002;
localparam IO_OAM_ADDR = 16'h2003;
localparam IO_OAM_DATA = 16'h2004;
localparam IO_PPU_SCROLL = 16'h2005;
localparam IO_PPU_ADDR = 16'h2006;
localparam IO_PPU_DATA = 16'h2007;
localparam IO_OAM_DMA = 16'h4014;
localparam IO_PATTERN_START = 14'h0000;
localparam IO_VRAM_START = 14'h2000;
localparam IO_ATTRIBUTE_OFFSET = 14'h03C0;

// Public registers and derived wires
reg [7:0] ppu_registers [3:0];
reg [7:0] vram_data_cache;
reg [14:0] vram_scroll_address; // NESDev "t"
reg [2:0] scroll_x_fine; // NESDev "x"

wire [7:0] ppu_ctrl;
wire [7:0] ppu_mask;
wire [7:0] ppu_status;
wire [7:0] oam_addr;
wire [4:0] scroll_x_coarse;
wire [4:0] scroll_y_coarse;
wire [2:0] scroll_y_fine;
wire [1:0] scroll_nt;

assign ppu_nmi_out = ppu_ctrl[7] & ppu_status[7];
assign ppu_ctrl = ppu_registers[IO_PPU_CTRL - IO_PPU_START];
assign ppu_mask = ppu_registers[IO_PPU_MASK - IO_PPU_START];
assign ppu_status = ppu_registers[IO_PPU_STATUS - IO_PPU_START];
assign oam_addr = ppu_registers[IO_OAM_ADDR - IO_PPU_START];
assign scroll_x_coarse = vram_scroll_address[4:0];
assign scroll_y_coarse = vram_scroll_address[9:5];
assign scroll_y_fine = vram_scroll_address[14:12];
assign scroll_nt = vram_scroll_address[11:10];

// Private registers and wires
reg cpu_clk_last;
reg [15:0] raster_x;
reg [15:0] raster_y;
reg [14:0] vram_fetch_address; // NESDev "v"
reg addr_set_state; // NESDev "w"
reg [1:0] data_fetch_state;
reg [5:0] oam_scan_address;
reg [8:0] oam_store_address;
reg [7:0] oam_dma_base;
reg [8:0] oam_dma_state;
reg [7:0] nametable_load;
reg [23:0] tile_pattern_load [1:0];
reg [23:0] tile_attribute_load;
reg [7:0] sprite_pattern0_load [7:0];
reg [7:0] sprite_pattern1_load [7:0];
reg [7:0] colors [63:0];
reg [7:0] palettes [31:0];
reg [7:0] oam_store [255:0];
reg [7:0] oam_scan [63:0];

wire cpu_frame;
wire io_enable;
wire [7:0] sprite_height;
wire [4:0] fetch_x_coarse;
wire [4:0] fetch_y_coarse;
wire [2:0] fetch_y_fine;
wire [1:0] fetch_nt;

assign cpu_frame = (~cpu_clk_last && cpu_clk_in);
assign io_enable = (cpu_address_in >= IO_PPU_START) && (cpu_address_in < (IO_PPU_START + IO_PPU_SIZE));
assign sprite_height = (ppu_ctrl[5]) ? 8'd16 : 8'd8;
assign fetch_x_coarse = vram_fetch_address[4:0];
assign fetch_y_coarse = vram_fetch_address[9:5];
assign fetch_y_fine = vram_fetch_address[14:12];
assign fetch_nt = vram_fetch_address[11:10];
				
// Temporary static palette
function [7:0] get_palette_rgb;
	input [1:0] palette;
	
	begin
		case(palette)
			0: get_palette_rgb = colors[6'h00d];
			1: get_palette_rgb = colors[6'h15];
			2: get_palette_rgb = colors[6'h20];
			3: get_palette_rgb = colors[6'h21];
		endcase
	end
endfunction

// Switch bit direction
function [7:0] msb_lsb;
	input [7:0] data;
	
	begin
		msb_lsb = {data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]};
	end
endfunction

function [7:0] filter_color;
	input [7:0] color_idx;
	
	begin
		// Convert to greyscale, if applicable
		filter_color = (ppu_mask[0]) ? color_idx & 8'h30 : color_idx;
	end
endfunction

// Set RGB values for given color index in current palette for tile and applicable sprites
task set_rgb;
	output [7:0] rgb; 
	reg sprite_back;
	reg [1:0] tile_color_idx;
	reg [1:0] sprite_color_idx;
	reg [1:0] sprite0_color_idx;
	reg [7:0] tile_palette_idx;
	reg [1:0] sprite_palette_idx;	
	reg [3:0] sprite_idx;
	reg [7:0] total_scroll_x;
	reg [7:0] total_scroll_y;
	
	
	begin
		// Calculate total effective scroll
		total_scroll_x = ((scroll_x_coarse << 3) + scroll_x_fine);
		total_scroll_y = ((scroll_y_coarse << 3) + scroll_y_fine);
		
		// Compute tile color index
		tile_color_idx = {tile_pattern_load[1][scroll_x_fine + (raster_x % 8)], tile_pattern_load[0][scroll_x_fine + (raster_x % 8)]};
		
		// Select palette from attributes (switch to next attribute when scrolling past edge)			
		if ((raster_x % 32) + (total_scroll_x % 32) < 32) begin
			tile_palette_idx = tile_attribute_load[7:0];
		end 
		else begin
			tile_palette_idx = tile_attribute_load[15:8];
		end
		
		// Adjust for bottom half of quadrant
		if ((((total_scroll_y + raster_y) % 32) >= 16) ^ ((total_scroll_y + raster_y) >= 240)) begin
			tile_palette_idx = tile_palette_idx >> 4;
		end
		
		// Adjust for right half of quadrant
		if (((total_scroll_x + raster_x) % 32) >= 16) begin
			tile_palette_idx = tile_palette_idx >> 2;
		end

		// Compute sprite color index, palette, and front/back priority
		sprite_color_idx = 2'h0;
		sprite0_color_idx = 2'h0;
		sprite_palette_idx = 2'h0;
		sprite_back = 1;
		
		for (sprite_idx = 4'h0; sprite_idx < 4'h8 ; sprite_idx = sprite_idx + 4'h1) begin
			// Continue while current pixel is transparent
			if (sprite_color_idx == 2'h0) begin
				// Check if sprite is active and at this location oam_store_address
				if ((oam_scan[(sprite_idx << 2) + 32] < 8'hEF) && (oam_scan[(sprite_idx << 2) + 35] <= raster_x) && ((oam_scan[(sprite_idx << 2) + 35] + 8) > raster_x)) begin
					sprite_color_idx = {sprite_pattern1_load[sprite_idx][raster_x - oam_scan[(sprite_idx << 2) + 35]], sprite_pattern0_load[sprite_idx][raster_x - oam_scan[(sprite_idx << 2) + 35]]};
					sprite_palette_idx = oam_scan[(sprite_idx << 2) + 34][1:0];
					sprite_back = oam_scan[(sprite_idx << 2) + 34][5];
					
					// Cache sprite 0 color for hit check
					if (oam_scan[(sprite_idx << 2) + 34][2]) begin
						sprite0_color_idx = sprite_color_idx;
					end
				end
			end
		end

		// Set pixels to disabled where applicable
		if (~ppu_mask[3] || (~ppu_mask[1] && (raster_x < 8))) begin
			tile_color_idx = 2'h0;
		end
		
		if (~ppu_mask[4] || (~ppu_mask[2] && (raster_x < 8))) begin
			sprite_color_idx = 2'h0;
		end
		
		// Default to universal background
		rgb = colors[filter_color(palettes[6'h00])];
		
		// Draw tile
		if (tile_color_idx != 2'h0) begin
			rgb = colors[filter_color(palettes[{(tile_palette_idx & 2'h3), tile_color_idx}])];
		end
		
		// Overwrite if sprite is in front with opaque pixel, or tile's pixel is transparent
		if (((sprite_back == 0) && (sprite_color_idx != 2'h0)) || (tile_color_idx == 2'h0)) begin
			if (sprite_color_idx != 2'h0) begin
				rgb = colors[filter_color(palettes[{1'h1, sprite_palette_idx, sprite_color_idx}])];
			end
		end
		
		// Set sprite 0 hit, if applicable
		if ((tile_color_idx > 2'h0) && (sprite_color_idx > 2'h0) && (sprite0_color_idx > 2'h0) && (raster_x != (HORIZ_VISIBLE - 1))) begin
			ppu_registers[IO_PPU_STATUS - IO_PPU_START][6] <= 1'b1;
		end		
	end
endtask
	
task set_fetch_coords;
	input [15:0] next_raster_x;
	input [15:0] next_raster_y;
	
	begin
		// Only update VRAM during render/pre-render
		if ((next_raster_y < VERT_VISIBLE) || (next_raster_y == (VERT_TOTAL - 1))) begin
			// Update fetch X every 8 pixels or during end-of-scanline fetch for next line
			if (((next_raster_x < HORIZ_VISIBLE) && ((next_raster_x % 8) == 0)) || (next_raster_x == FINAL_NT_FETCH_X) || (next_raster_x == (FINAL_NT_FETCH_X + 8))) begin
				vram_fetch_address[4:0] <= vram_fetch_address[4:0] + 5'h01;

				// If wrapping, switch nametable horizontally
				if (fetch_x_coarse == 5'd31) begin
					vram_fetch_address[10] <= ~vram_fetch_address[10];
				end
			end
			
			// Update fetch Y on end of scanline
			if (next_raster_x == HORIZ_VISIBLE) begin
				vram_fetch_address[14:12] <= vram_fetch_address[14:12] + 3'h1;
				
				// Overflow fine y to coarse y
				if (fetch_y_fine == 3'd7) begin
					vram_fetch_address[9:5] <= vram_fetch_address[9:5] + 5'h01;
		
					// If wrapping, switch nametable vertically
					if (fetch_y_coarse == 5'd29) begin
						vram_fetch_address[9:5] <= 5'h00;
						vram_fetch_address[11] <= ~vram_fetch_address[11];
					end
				end
			end
			
			// Update horizontal fetch with horizontal scroll TODO: Check if this needs to go back to HORIZ_VISIBLE
			//if (raster_x == (HORIZ_VISIBLE + 1)) begin
			if (next_raster_x == FINAL_NT_FETCH_X) begin
				vram_fetch_address[10] <= scroll_nt[0];
				vram_fetch_address[4:0] <= scroll_x_coarse;
			end
			
			// Update vertical fetch with vertical scroll
			if ((next_raster_x == FINAL_NT_FETCH_X) && (next_raster_y == (VERT_TOTAL - 1))) begin
				vram_fetch_address[11] <= scroll_nt[1];
				vram_fetch_address[9:5] <= scroll_y_coarse;
				vram_fetch_address[14:12] <= scroll_y_fine;
			end
		end
	end
endtask

task process_sprites;
	begin
		// 1-32 (NES: 1-64) - Initialize load-half (bottom) of secondary OAM with 8'hFF
		if ((raster_x >= 0) && (raster_x < 32)) begin
			oam_scan[raster_x] = 8'hFF;
		end
				
		// Sprite evaluation does not occur on pre-render (no sprites on line 0) - NOTE this timing is different than real NES (starts at 128 and not 64)
		if ((raster_x >= 128) && (raster_x < HORIZ_VISIBLE) && ((raster_x % 2) == 0) && (raster_y < VERT_VISIBLE)) begin
			
			// Reset OAM addresses
			if (raster_x == 128) begin
				oam_store_address = oam_addr;
				oam_scan_address = 6'h00;
			end
							
			// Initial non-0 OAMADDR will evaluate fewer sprites (since it will hit end of OAM sooner)
			if (oam_store_address <= 252) begin
				// Sprites are shifted by 1 line, so check if matches current scanline
				if ((raster_y >= oam_store[oam_store_address]) && (raster_y < (oam_store[oam_store_address] + sprite_height))) begin
					if (oam_scan_address <= 28) begin
						oam_scan[oam_scan_address + 0] = oam_store[oam_store_address + 0];
						oam_scan[oam_scan_address + 1] = oam_store[oam_store_address + 1];
						oam_scan[oam_scan_address + 2] = oam_store[oam_store_address + 2];
						oam_scan[oam_scan_address + 3] = oam_store[oam_store_address + 3];
						
						// Store sprite 0 status in attribute bit 2 (unimplemented in standard NES)
						oam_scan[oam_scan_address + 2][2] = (oam_store_address == oam_addr);
						
						oam_scan_address = oam_scan_address + 6'h04;
					end
					else begin
						// Sprite overflow
						ppu_registers[IO_PPU_STATUS - IO_PPU_START][5] <= 1'b1;
					end
				end
			end
			
			oam_store_address = oam_store_address + 9'h004;
		end

		// Transfer load-half (bottom) of secondary OAM to active-half (top) of secondary OAM
		if ((raster_x >= HORIZ_VISIBLE) && (raster_x < (HORIZ_VISIBLE + 32))) begin
			oam_scan[((raster_x - HORIZ_VISIBLE) << 2) + 32] = oam_scan[((raster_x - HORIZ_VISIBLE) << 2) + 0];
			oam_scan[((raster_x - HORIZ_VISIBLE) << 2) + 33] = oam_scan[((raster_x - HORIZ_VISIBLE) << 2) + 1];
			oam_scan[((raster_x - HORIZ_VISIBLE) << 2) + 34] = oam_scan[((raster_x - HORIZ_VISIBLE) << 2) + 2];
			oam_scan[((raster_x - HORIZ_VISIBLE) << 2) + 35] = oam_scan[((raster_x - HORIZ_VISIBLE) << 2) + 3];
		end
	
		// Reset OAM address on all visible and pre-render
		if (((raster_x > HORIZ_VISIBLE) && (raster_x <= 320)) && ((raster_y < VERT_VISIBLE) || (raster_y == (VERT_TOTAL - 1)))) begin
			ppu_registers[IO_OAM_ADDR - IO_PPU_START] <= 8'h00;
		end		
	end
endtask

task fetch_tile_data;
	reg [13:0] new_vram_address;
	reg initiate;

	begin
		new_vram_address = 0;
		initiate = 0;
		
		// Fetch tile data during rendering or end of scanline/frame
		if (((raster_x < HORIZ_VISIBLE) || ((raster_x >> 3) == (FINAL_NT_FETCH_X >> 3)) || ((raster_x >> 3) == ((FINAL_NT_FETCH_X + 8) >> 3))) &&
		    ((raster_y < VERT_VISIBLE) || (raster_y == (VERT_TOTAL - 1)))) begin
			case(raster_x % 8)
				0: begin
						tile_pattern_load[0] = {8'h00, tile_pattern_load[0][23:8]};
						tile_pattern_load[1] = {8'h00, tile_pattern_load[1][23:8]};
						tile_attribute_load = {8'h00, tile_attribute_load[23:8]};
					end				
				1: begin
						// Fetch tile
						new_vram_address = IO_VRAM_START + vram_fetch_address[11:0];
						initiate = 1;
					end
				2: begin
						// Fetch attributes
						new_vram_address = IO_VRAM_START + (fetch_nt << 10) + IO_ATTRIBUTE_OFFSET + ((fetch_y_coarse >> 2) << 3) + (fetch_x_coarse >> 2);
						initiate = 1;
				end
				3: begin
						// Nametable data ready
						nametable_load = ppu_data_in;						
						
						// Fetch top plane of pattern
						new_vram_address = IO_PATTERN_START + (ppu_ctrl[4] << 12) + (nametable_load << 4) + fetch_y_fine; 
						initiate = 1;
					end
				4: begin
						// Attributes ready
						tile_attribute_load[23:16] = ppu_data_in;
				
						// Fetch bottom plane of pattern
						new_vram_address = IO_PATTERN_START + (ppu_ctrl[4] << 12) + (nametable_load << 4) + 14'd8 + fetch_y_fine;
						initiate = 1;
				end
				5: begin
						// Top plane of pattern ready
						tile_pattern_load[0][23:16] = msb_lsb(ppu_data_in);
				end
				6: begin
						// Bottom plane of pattern ready
						tile_pattern_load[1][23:16] = msb_lsb(ppu_data_in);				
					end
			endcase		
		end
		
		if (initiate) begin
			ppu_address_out <= new_vram_address;
			ppu_read_out <= 1;
		end
	end
endtask

task fetch_sprite_data;
	reg [7:0] sprite_idx;
	reg [13:0] new_vram_address;
	reg [7:0] y_offset;
	reg initiate;

	begin
		new_vram_address = 0;
		sprite_idx = (raster_x - HORIZ_VISIBLE) >> 3;
		y_offset = oam_scan[(sprite_idx << 2) + 2][7] ? ((sprite_height - 1) - (raster_y - oam_scan[sprite_idx << 2])) : (raster_y - oam_scan[sprite_idx << 2]);
		initiate = 0;
		
		// Fetch sprite data afer rendering
		if ((raster_x > HORIZ_VISIBLE)  && (raster_x < FINAL_NT_FETCH_X) && (raster_y < VERT_VISIBLE)) begin		
			case(raster_x % 8)
				1: begin
						// Fetch sprite's top plane of pattern
						if (~ppu_ctrl[5]) begin
							// 8x8
							new_vram_address = IO_PATTERN_START + (ppu_ctrl[3] << 12) + (oam_scan[(sprite_idx << 2) + 1] << 4) + y_offset;
						end
						else begin
							// 8x16
							if (y_offset < 8) begin
								new_vram_address = IO_PATTERN_START + (oam_scan[(sprite_idx << 2) + 1][0] << 12) + ((oam_scan[(sprite_idx << 2) + 1] & 8'hFE) << 4) + y_offset;
							end
							else begin
								new_vram_address = IO_PATTERN_START + (oam_scan[(sprite_idx << 2) + 1][0] << 12) + ((oam_scan[(sprite_idx << 2) + 1] & 8'hFE) << 4) + 14'd16 + y_offset - 14'd8;
							end
						end
						initiate = 1;
					end
				2: begin
						// Fetch sprite's bottom plane of pattern
						if (~ppu_ctrl[5]) begin
							// 8x8
							new_vram_address = IO_PATTERN_START + (ppu_ctrl[3] << 12) + (oam_scan[(sprite_idx << 2) + 1] << 4) + 14'd8 + y_offset;
						end
						else begin
							// 8x16
							if (y_offset < 8) begin
								new_vram_address = IO_PATTERN_START + (oam_scan[(sprite_idx << 2) + 1][0] << 12) + ((oam_scan[(sprite_idx << 2) + 1] & 8'hFE) << 4) + 14'd8 + y_offset;
							end
							else begin
								new_vram_address = IO_PATTERN_START + (oam_scan[(sprite_idx << 2) + 1][0] << 12) + ((oam_scan[(sprite_idx << 2) + 1] & 8'hFE) << 4) + 14'd24 + y_offset - 14'd8;							
							end
						end
						initiate = 1;
					end					
				3: begin
						// Top plane of pattern ready
						if (oam_scan[(sprite_idx << 2) + 2][6]) begin
							// Flipped horizontal
							sprite_pattern0_load[sprite_idx] = ppu_data_in;
						end
						else begin
							// Normal horizontal
							sprite_pattern0_load[sprite_idx] = msb_lsb(ppu_data_in);
						end
				end
				4: begin
						// Bottom plane of pattern ready
						if (oam_scan[(sprite_idx << 2) + 2][6]) begin
							// Flipped horizontal
							sprite_pattern1_load[sprite_idx] = ppu_data_in;
						end
						else begin
							// Normal horizontal
							sprite_pattern1_load[sprite_idx] = msb_lsb(ppu_data_in);
						end
					end
			endcase		
		end
		
		if (initiate) begin
			ppu_address_out <= new_vram_address;
			ppu_read_out <= 1;
		end
	end
endtask
	
// Fetch data from cart and VRAM
task fetch_data;
	reg temp_read_out;
	reg [13:0] new_vram_address;
	
	begin	
		// Process sprites and setup OAM secondary memory
		process_sprites();
		
		// Fetch tile data, if enabled and applicable
		if (ppu_mask[3]) begin
			fetch_tile_data();
		end
		
		// Fetch sprite data, if enabled and applicable
		if (ppu_mask[4]) begin
			fetch_sprite_data();
		end
	end	
endtask

task raster;
	reg temp_write;
	reg [7:0] temp_rgb;
	
	begin
		temp_write = 0;
		temp_rgb = 8'h00;
		
		// Write raster data if in active portion of screen
		if ((raster_x < HORIZ_VISIBLE) && (raster_y < VERT_VISIBLE)) begin
			//ppu_raster_data_out <= raster_x[7:0];
			//ppu_raster_data_out <= tile_pattern_load[0][7:0];
			//ppu_raster_data_out <= current_vram_address[7:0];
			set_rgb(temp_rgb);
			temp_write = 1;
		end
	
		ppu_raster_write_out <= temp_write;
		ppu_raster_data_out <= temp_rgb;
	end
endtask

// Reset status and set vertical blanking, if applicable
task set_flags;
	begin
		if ((raster_x == SET_FLAGS_X) && (raster_y == (VERT_VISIBLE + 1))) begin
			ppu_registers[IO_PPU_STATUS - IO_PPU_START][7] <= 1'b1;
		end
		
		// Reset PPU Status (vertical blank, sprite 0 hit, and sprite overflow) on pre-render x=1)
		if ((raster_x == SET_FLAGS_X) && (raster_y == (VERT_TOTAL - 1))) begin
			ppu_registers[IO_PPU_STATUS - IO_PPU_START][7:5] <= 3'b000;			
		end		
	end
endtask

// Process IO requests
task cpu_io();
	reg update_registers;
	
	begin
		update_registers = 0;
		
		if (io_enable) begin
			// Write on CPU aligned frame
			if (cpu_write_in && cpu_frame) begin
				// Registers are mirrored every 8 bytes
				case (IO_PPU_START + (cpu_address_in % 8))
					IO_PPU_CTRL: begin
						vram_scroll_address[11:10] <= cpu_data_in[1:0];
						update_registers = 1;
					end
					
					// Set OAM data
					IO_OAM_DATA: begin
						oam_store[oam_addr] <= cpu_data_in;
						ppu_registers[IO_OAM_ADDR - IO_PPU_START] <= oam_addr + 8'h01;
					end

					// Set scroll VRAM address
					IO_PPU_SCROLL: begin
						if (addr_set_state == 0) begin
							// Set coarse and fine X
							vram_scroll_address[4:0] <= cpu_data_in[7:3];
							scroll_x_fine <= cpu_data_in[2:0];
						end
						
						if (addr_set_state == 1) begin
							// Set coarse and fine Y
							vram_scroll_address[9:5] <= cpu_data_in[7:3];
							vram_scroll_address[14:12] <= cpu_data_in[2:0];
						end
						
						addr_set_state <= ~addr_set_state;
					end
					
					// Set fetch and scroll VRAM address
					IO_PPU_ADDR: begin
						if (addr_set_state == 0) begin
							vram_scroll_address[13:8] <= cpu_data_in[5:0];
							vram_scroll_address[14] <= 0;
						end
						
						if (addr_set_state == 1) begin
							vram_scroll_address[7:0] <= cpu_data_in;
							vram_fetch_address <= {vram_scroll_address[14:8], cpu_data_in};
						end
						
						addr_set_state <= ~addr_set_state;
					end
					
					// Set VRAM/palette data
					IO_PPU_DATA: begin
						if (vram_fetch_address[13:0] < IO_PALETTE_START) begin
							// VRAM/cart write
							ppu_address_out <= vram_fetch_address[13:0];
							ppu_write_out <= 1;
							ppu_data_out <= cpu_data_in;	
						end
						else begin
							
							// Palette write
							if ((vram_fetch_address[13:0] % 4) == 0) begin
								// Sprite background mirror tile backgrounds
								palettes[(vram_fetch_address[13:0] - IO_PALETTE_START) % 16] <= cpu_data_in;
							end
							else begin
								palettes[(vram_fetch_address[13:0] - IO_PALETTE_START ) % 32] <= cpu_data_in;
							end
						end
						
						// Increment VRAM address
						vram_fetch_address[13:0] <= vram_fetch_address[13:0] + (ppu_ctrl[2] ? 14'h0020 : 14'h0001);												
					end

					// Normal registers, directly set
					default: begin
						update_registers = 1;
					end
					
				endcase
				
				// NES sets 5 bits of status for every write
				ppu_registers[IO_PPU_STATUS - IO_PPU_START][4:0] <= cpu_data_in[4:0];
				
				if (update_registers) begin
					ppu_registers[cpu_address_in % 8] <= cpu_data_in;
				end
			end
		
			// Read on all CPU frames
			if (cpu_read_in && cpu_frame) begin
				// Provide data for registers
				if ((IO_PPU_START + (cpu_address_in % 8)) <= IO_OAM_ADDR) begin
					cpu_data_out <= ppu_registers[IO_PPU_START + (cpu_address_in % 8)];
					cpu_data_en_out <= 1;
				end
				
				// OAM Data
				if ((IO_PPU_START + (cpu_address_in % 8)) == IO_OAM_DATA) begin
					cpu_data_out <= oam_store[oam_store_address];
					cpu_data_en_out <= 1;					
				end
				
				// PPU Data
				if ((IO_PPU_START + (cpu_address_in % 8)) == IO_PPU_DATA) begin
					// Immediately return last VRAM read/current palette
					if (vram_fetch_address[13:0] < IO_PALETTE_START) begin					
						cpu_data_out <= vram_data_cache;
					end
					else begin
						if ((vram_fetch_address[13:0] % 4) == 0) begin
							// Sprite background mirror tile backgrounds
							cpu_data_out <= palettes[(vram_fetch_address[13:0] - IO_PALETTE_START) % 16];
						end
						else begin
							cpu_data_out <=  palettes[(vram_fetch_address[13:0] - IO_PALETTE_START ) % 32];
						end
					end
					
					cpu_data_en_out <= 1;
					
					// Queue next read
					ppu_address_out <= vram_fetch_address[13:0];
					ppu_read_out <= 1;
					data_fetch_state <= 2;
					
					// Increment VRAM address
					vram_fetch_address[13:0] <= vram_fetch_address[13:0] + (ppu_ctrl[2] ? 14'h0020 : 14'h0001);	
				end				
				
				// Status - reset NMI and address set state
				if ((IO_PPU_START + (cpu_address_in % 8)) == IO_PPU_STATUS) begin
					ppu_registers[IO_PPU_STATUS - IO_PPU_START][7] <= 0;
					addr_set_state <= 0;
				end				
			end
		end
	
		// Process in-progress PPU read
		if (data_fetch_state > 0) begin
			if (data_fetch_state == 1) begin
				vram_data_cache <= ppu_data_in;
			end
			
			data_fetch_state <= data_fetch_state - 2'h1;
		end
	end
endtask

// Advance for next cycle
task next_cycle;
	reg [15:0] temp_raster_x;
	reg [15:0] temp_raster_y;
	
	begin	
		// Set next CPU frame
		cpu_clk_last <= cpu_clk_in;
				
		// Set next raster position
		temp_raster_x = raster_x + 16'h0001;
		temp_raster_y = raster_y;
		
		if (temp_raster_x == HORIZ_TOTAL) begin
			temp_raster_x = 16'h0000;
			temp_raster_y = temp_raster_y + 16'h0001;
		end
		
		if (temp_raster_y == VERT_TOTAL) begin
			temp_raster_y = 16'h0000;
		end
		
		// Set next fetch position, if enabled
		if (ppu_mask[3]) begin
			set_fetch_coords(temp_raster_x, temp_raster_y);
		end
		
		raster_x <= temp_raster_x;
		raster_y <= temp_raster_y;
	end
endtask

// Process DMA on CPU bus and associated IO (Note: this adds 1.5 mins to fitter)
task cpu_dma;
	reg [15:0] init_idx;
	reg [15:0] fetch_idx;
	
	begin
		init_idx = 16'h0000;
		fetch_idx = 16'h0000;
	
		// Check for OAM DMA (outside normal range and not mirrored)
		if ((cpu_address_in == IO_OAM_DMA) && cpu_frame && cpu_write_in) begin
			oam_dma_base <= cpu_data_in;
			oam_dma_state <= 0;
			cpu_disable_out <= 1;
		end

		// Perform DMA (Setup time + 256 bytes + 2 cycles to retrieve last read)
		if (oam_dma_state < (OAM_DMA_SETUP + 9'h102)) begin
			cpu_disable_out <= 1;

			// Initiate request
			if (oam_dma_state >= OAM_DMA_SETUP) begin
				init_idx = (oam_dma_state - OAM_DMA_SETUP);
				cpu_address_out <= {oam_dma_base, init_idx[7:0]};
				cpu_address_en_out <= 1;
			end
		
			// Retrieve request
			if (oam_dma_state >= (OAM_DMA_SETUP + 9'h002)) begin
				fetch_idx = (oam_dma_state - OAM_DMA_SETUP - 9'h002);
				oam_store[fetch_idx] <= ram_data_in;
			end

			oam_dma_state <= oam_dma_state + 9'h001;
		end
	end
endtask

task init_output;
	begin
		ppu_read_out <= 0;
		ppu_write_out <= 0;
		ppu_address_out <= 0;
		ppu_data_out <= 0;
		ppu_raster_write_out <= 0;
		ppu_raster_data_out <= 0;

		cpu_address_en_out <= 0;
		cpu_disable_out <= 0;
		cpu_address_out <= 16'h0000;
	
		// Only reset CPU bus output on CPU frame
		if (cpu_frame) begin
			cpu_data_en_out <= 0;
			cpu_data_out <= 8'h00;		
		end
	end
endtask

initial begin
	// Ports
	init_output();
	
	// Public registers
	ppu_registers[IO_PPU_CTRL - IO_PPU_START] = 8'b00000000; //8'b10010100;
	ppu_registers[IO_PPU_MASK - IO_PPU_START] = 8'b00000000; //8'b00011110;
	ppu_registers[IO_PPU_STATUS - IO_PPU_START] = 8'h00;
	ppu_registers[IO_OAM_ADDR - IO_PPU_START] = 8'h00;
	vram_data_cache = 8'h00;
	vram_scroll_address = 15'h0000;
	scroll_x_fine = 3'h0;
	
	// Private registers
	cpu_clk_last = 0;
	raster_x = 16'h0000;
	raster_y = 16'h0000;	
	vram_fetch_address = 15'h0000;
	oam_dma_base = 8'h00;
	oam_dma_state = 9'h1FF;
	addr_set_state = 0;
	data_fetch_state = 0;
	
	$readmemh("roms/colors.txt", colors);
   $readmemh("roms/palette_test.txt", palettes);
	$readmemh("roms/oam_test.txt", oam_store);
end

// Raster and process IO
always @ (posedge ppu_clk_in) begin
	// Initialize PPU clock domain output to avoid latches
	init_output();
	
	// Fetch data
	fetch_data();

	// Raster processing
	raster();
	
	// Reset flags and check for NMI
	set_flags();
	
	// Process IO requests
	cpu_io();
	cpu_dma();
	
	// Prepare for next cycle
	next_cycle();
end

endmodule