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

module mapper000(
	input cart_clk_in,
	input prg_read_in,
	input prg_write_in,	
	input chr_read_in,
	input chr_write_in,
	input [15:0] prg_address_in,
	input [7:0] prg_data_in,
	input [13:0] chr_address_in,
	input [7:0] chr_data_in,
	output vram_enable_out,
	output cart_address_out,
	output reg prg_data_en_out,	
	output reg chr_data_en_out,
	output [7:0] prg_data_out,
	output [7:0] chr_data_out	
);

localparam ROM_PRG_SIZE = 16'h8000;
localparam ROM_VERT_MIRROR = 1;

// IO Addresses
localparam PRG_START = 16'h8000;
localparam PRG_SIZE = 16'h8000;
localparam CHR_START = 14'h0000;
localparam CHR_SIZE = 14'h2000;

// Private registers and wires
wire prg_enable;
wire chr_enable;

assign prg_enable = (prg_address_in >= PRG_START);
assign chr_enable = (chr_address_in >= CHR_START) && (chr_address_in < (CHR_START + CHR_SIZE));
assign vram_enable_out = chr_address_in[13];
assign cart_address_out = ROM_VERT_MIRROR ? chr_address_in[10] : chr_address_in[11];

// Modules
prg_rom cart_prg_rom(.address((prg_address_in - PRG_START) % ROM_PRG_SIZE), .clock(cart_clk_in), .rden(prg_read_in), .q(prg_data_out));
chr_ram cart_chr_rom(.address(chr_address_in - CHR_START), .clock(cart_clk_in), .data(chr_data_in), .rden(chr_read_in), .wren(chr_enable && chr_write_in && 0), .q(chr_data_out));

always @ (posedge cart_clk_in) begin
	chr_data_en_out <= (chr_enable && chr_read_in);
	prg_data_en_out <= (prg_enable && prg_read_in);
end

endmodule
