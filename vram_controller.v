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

module vram_controller(
	input vram_clk_in,
	input vram_enable_in,
	input vram_read_in,
	input vram_write_in,
	input cart_address_in,		
	input [9:0] vram_address_in,	
	input [7:0] vram_data_in,
	output [7:0] vram_data_out,

	input [9:0] switches_in,
	output reg [15:0] debug_out
);

// Private registers and wires
wire [10:0] vram_address;
wire [7:0] nametable_out;
assign vram_address = {cart_address_in, vram_address_in};
	
vram vram_controller_vram(.address(vram_address), .clock(vram_clk_in), .data(vram_data_in), .rden(vram_read_in), .wren(vram_enable_in && vram_write_in), .q(vram_data_out));

endmodule
