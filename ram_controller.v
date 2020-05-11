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

module ram_controller(
	input ram_clk_in,
	input ram_read_in,
	input ram_write_in,
	input [15:0] ram_address_in,	
	input [7:0] ram_data_in,
	output [7:0] ram_data_out,
	
	input [9:0] switches_in,
	output reg [15:0] debug_out
);

// IO Addresses
localparam RAM_START = 16'h0000;
localparam RAM_SIZE = 16'h2000;

// Private registers and wires
wire ram_enable;

assign ram_enable = (ram_address_in >= RAM_START) && (ram_address_in < (RAM_START + RAM_SIZE));

ram ram_controller_ram(.address(ram_address_in[10:0]), .clock(ram_clk_in), .data(ram_data_in), .rden(ram_read_in), .wren(ram_enable && ram_write_in), .q(ram_data_out));

endmodule