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

module mapper001(
	input cart_clk_in,
	input cpu_clk_in,
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
	output [7:0] chr_data_out,
	
	input [9:0] switches_in,	
	output reg [15:0] debug_out	
);

localparam PRG_ROM_SIZE = 131072; // 262144;

localparam PRG_RAM_START = 16'h6000;
localparam PRG_RAM_BANK_SIZE = 16'h2000;
localparam PRG_BANK0_START = 16'h8000;
localparam PRG_BANK1_START = 16'hC000;
localparam PRG_ROM_BANK_SIZE = 16'h4000;
localparam PRG_ROM_LAST_BANK = PRG_ROM_SIZE - PRG_ROM_BANK_SIZE;
localparam CHR_BANK0_START = 14'h0000;
localparam CHR_BANK1_START = 14'h1000;
localparam CHR_BANK_SIZE = 16'h1000;

// Public registers and wires
reg [2:0] load_pos;
reg [4:0] load_register;
reg [4:0] cart_registers [3:0];
wire [4:0] reg_control;
wire [4:0] reg_chr0;
wire [4:0] reg_chr1;
wire [4:0] reg_prg;

assign reg_control = cart_registers[0];
assign reg_chr0 = cart_registers[1];
assign reg_chr1 = cart_registers[2];
assign reg_prg = cart_registers[3];

assign vram_enable_out = chr_address_in[13];
assign cart_address_out = (reg_control[1:0] == 2'h0) ? 1'b0 :
								  (reg_control[1:0] == 2'h1) ? 1'b1 :
								  (reg_control[1:0] == 2'h2) ? chr_address_in[10] :
								  chr_address_in[11];


// Private registers and wires
reg cpu_clk_last;
reg prg_write_last;

wire prg_ram_enable;
wire prg_rom_enable;
wire chr_ram_enable;
wire reg_enable;
wire cpu_frame;
wire prg_first_write;
wire [7:0] prg_ram_data_out;
wire [7:0] prg_rom_data_out;
wire [14:0] prg_ram_address_abs;
wire [16:0] prg_rom_address_abs;
wire [16:0] prg_rom0_address_abs;
wire [16:0] prg_rom1_address_abs;
wire [16:0] chr_ram_address_abs;
wire [16:0] chr_ram0_address_abs;
wire [16:0] chr_ram1_address_abs;

assign prg_ram_enable = (prg_address_in >= PRG_RAM_START) && (prg_address_in < PRG_BANK0_START) && ~reg_prg[4] && ~reg_chr0[4] && ~reg_chr1[4];
assign prg_rom_enable = (prg_address_in >= PRG_BANK0_START);
assign chr_ram_enable = (chr_address_in >= CHR_BANK0_START) && (chr_address_in < (CHR_BANK1_START + CHR_BANK_SIZE));
assign reg_enable = (prg_address_in >= PRG_BANK0_START);
assign cpu_frame = (~cpu_clk_last && cpu_clk_in);
assign prg_first_write = (~prg_write_last && prg_write_in);
assign prg_data_out = prg_ram_enable ? prg_ram_data_out : prg_rom_data_out;

// Only support fixed 8KB PRG RAM SxROM carts
assign prg_ram_address_abs = (prg_address_in - PRG_RAM_START) % PRG_RAM_BANK_SIZE;

assign prg_rom0_address_abs = ((prg_address_in - PRG_BANK0_START) % PRG_ROM_BANK_SIZE) + ((reg_control[3:2] == 2'h2) ? 17'h00000 : (reg_prg[3:0] << 14)); // Mode 2 -> Fixed first 16K, Mode 3 -> 16K banked
assign prg_rom1_address_abs = ((prg_address_in - PRG_BANK1_START) % PRG_ROM_BANK_SIZE) + ((reg_control[3:2] == 2'h2) ? (reg_prg[3:0] << 14) : PRG_ROM_LAST_BANK); // Mode 2 -> 16K banked, Mode 3 -> Fixed last 16K
assign prg_rom_address_abs = (reg_control[3:2] < 2'h2) ? (((prg_address_in - PRG_BANK0_START) % (PRG_ROM_BANK_SIZE << 1)) + ({reg_prg[3:1], 1'b0} << 14)) : // Mode 0/1 -> 32KB bank across Bank0/Bank1
                             (prg_address_in < PRG_BANK1_START) ? prg_rom0_address_abs : // Mode 2/3, Bank 0
									  prg_rom1_address_abs; // Mode 2/3, Bank 1

									  
assign chr_ram0_address_abs = ((chr_address_in - CHR_BANK0_START) % CHR_BANK_SIZE) + (reg_chr0 << 12);
assign chr_ram1_address_abs = ((chr_address_in - CHR_BANK1_START) % CHR_BANK_SIZE) + (reg_chr1 << 12);
assign chr_ram_address_abs = (~reg_control[4] ) ? (((chr_address_in - CHR_BANK0_START) % (CHR_BANK_SIZE << 1)) + ({reg_chr0[4:1], 1'b0} << 12)): // Mode 0 -> 8K banked
                             (chr_address_in < CHR_BANK1_START) ? chr_ram0_address_abs : // Mode 1, Bank 0
									  chr_ram1_address_abs; // Mode 1, Bank 1
/*
assign chr_ram0_address_abs = ((chr_address_in - CHR_BANK0_START) % CHR_BANK_SIZE) + (reg_chr0[0] << 12);
assign chr_ram1_address_abs = ((chr_address_in - CHR_BANK1_START) % CHR_BANK_SIZE) + (reg_chr1[0] << 12);
assign chr_ram_address_abs = (~reg_control[4] ) ? ((chr_address_in - CHR_BANK0_START) % (CHR_BANK_SIZE << 1)) : // Mode 0 -> 8K banked (SNROM fixed first 8K)
                             (chr_address_in < CHR_BANK1_START) ? chr_ram0_address_abs : // Mode 1, Bank 0
									  chr_ram1_address_abs; // Mode 1, Bank 1
*/

									  
// Modules
prg_ram cart_prg_ram(.address(prg_ram_address_abs), .clock(cart_clk_in), .data(prg_data_in), .rden(prg_ram_enable && prg_read_in), .wren(prg_ram_enable && prg_write_in), .q(prg_ram_data_out));
prg_rom cart_prg_rom(.address(prg_rom_address_abs), .clock(cart_clk_in), .rden(prg_rom_enable && prg_read_in), .q(prg_rom_data_out));
chr_ram cart_chr_ram(.address(chr_ram_address_abs), .clock(cart_clk_in), .data(chr_data_in), .rden(chr_ram_enable && chr_read_in), .wren(chr_ram_enable && chr_write_in), .q(chr_data_out));

// Process register load
task reg_load;
	begin
		// Only process first non-consecutive write within load register range
		if (cpu_frame && prg_first_write && reg_enable) begin
			// Set/Reset load register
			if (prg_data_in[7]) begin
				load_pos <= 3'h0;
			end
			else begin
				if (load_pos < 3'h4) begin
					load_register[load_pos] <= prg_data_in[0];
					load_pos <= load_pos + 3'h1;
				end
				else begin
					cart_registers[prg_address_in[14:13]] <= {prg_data_in[0], load_register[3:0]};
					load_pos <= 3'h0;					
				end
			end
		end
	end
endtask

task init_output;
	begin
		chr_data_en_out <= (chr_ram_enable && chr_read_in);
		prg_data_en_out <= ((prg_ram_enable || prg_rom_enable) && prg_read_in);
	end
endtask


initial begin
	// Public registers
	load_pos = 3'h0;
	load_register = 5'h00;
	cart_registers[0] = 5'b01100;
	cart_registers[1] = 5'b00000;
	cart_registers[2] = 5'b00000;
	cart_registers[3] = 5'b01111;
	
	// Private registers
	cpu_clk_last = 0;
	prg_write_last = 0;
	
	debug_out = 16'h0000;
end

always @ (posedge cart_clk_in) begin
	// Ports
	init_output();
	
	// Process load register
	reg_load();
	
	// Set CPU frame info	
	cpu_clk_last <= cpu_clk_in;
	if (cpu_frame) begin
		prg_write_last <= prg_write_in;
	end	
end

endmodule
