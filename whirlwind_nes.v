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

module whirlwind_nes(
	input clk_50_in,
	input [9:0] switches_in,
	input [3:0] buttons_in,
	inout [6:0] joystick_io,
	
	output vga_clk_out,
	output vga_csync_out,
	output vga_blank_out,
	output vga_hsync_out,
	output vga_vsync_out,
	output [7:0] vga_red_out,
	output [7:0] vga_green_out,
	output [7:0] vga_blue_out,
	
	inout i2c_data_io,
	output i2c_clk_out,
	output aud_chip_clk_out,
	output aud_bit_clk_out,
	output aud_channel_out,
	output aud_data_out,
		
	output [6:0] hex_data0_out,
	output [6:0] hex_data1_out,
	output [6:0] hex_addr0_out,
	output [6:0] hex_addr1_out,
	output [6:0] hex_addr2_out,
	output [6:0] hex_addr3_out,
	output [9:0] led_out
);

// NES clocks
wire master_clk;
wire ppu_clk;
wire cpu_clk;

// CPU
wire cpu_read;
wire cpu_write;
wire cpu_irq;
wire [15:0] cpu_address;
wire [7:0] cpu_data_out;
wire [7:0] cpu_data_in;

assign cpu_irq = apu_irq;
assign cpu_data_in = ppu_cpu_data_en ? ppu_cpu_data_out :
							apu_cpu_data_en ? apu_cpu_data_out :
							joy_cpu_data_en ? joy_cpu_data_out :
                     cart_prg_data_en ? cart_prg_data_out : ram_data_out;
												
// RAM controller
wire ram_read;
wire [15:0] ram_address;
wire [7:0] ram_data_out;

assign ram_read = cpu_read | ppu_cpu_address_en;
assign ram_address = ppu_cpu_address_en ? ppu_cpu_address : cpu_address;
//assign ram_address = cpu_address; //DEBUG


// PPU
wire ppu_read;
wire ppu_write;
wire ppu_raster_write;
wire ppu_nmi;
wire ppu_cpu_address_en;
wire ppu_cpu_data_en;
wire ppu_cpu_disable;
wire [15:0] ppu_cpu_address;
wire [13:0] ppu_address;
wire [7:0] ppu_data_in;
wire [7:0] ppu_data_out;
wire [7:0] ppu_cpu_data_out;
wire [7:0] ppu_raster_data;

assign ppu_data_in = cart_chr_data_en ? cart_chr_data_out : vram_data_out;

// VGA
wire vga_clk;

assign vga_clk_out = vga_clk;

// VRAM controller
wire [7:0] vram_data_out;

// APU
wire aud_clk;
wire apu_irq;
wire apu_cpu_data_en;
wire apu_cpu_data_out;

// Joypads
wire joy_cpu_data_en;
wire [7:0] joy_cpu_data_out;

assign joystick_io[6] = 0;

// Cart
wire cart_address;
wire cart_prg_data_en;
wire cart_chr_data_en;
wire cart_vram_enable;
wire [7:0] cart_prg_data_out;
wire [7:0] cart_chr_data_out;

// Debug
wire [15:0] debug_pc;
wire [15:0] debug_module;

assign led_out[7] = ppu_nmi;
assign led_out[8] = cpu_read;
assign led_out[9] = cpu_write;

// Modules
r6502_tc nes_cpu(.clk_clk_i(~cpu_clk),  .a_o(cpu_address), .rd_o(cpu_read), .wr_o(cpu_write), .d_i(cpu_data_in), .d_o(cpu_data_out), .rdy_i(~ppu_cpu_disable), .rst_rst_n_i(buttons_in[3]), .irq_n_i(~cpu_irq), .nmi_n_i (~ppu_nmi), .so_n_i(1), .pc_o(debug_pc));
ram_controller nes_ram_controller(.ram_clk_in(ppu_clk), .ram_read_in(ram_read), .ram_write_in(cpu_write), .ram_address_in(ram_address), .ram_data_in(cpu_data_out), .ram_data_out(ram_data_out));
ppu nes_ppu(.ppu_clk_in(ppu_clk), .cpu_clk_in(cpu_clk), .cpu_read_in(cpu_read), .cpu_write_in(cpu_write), .cpu_address_in(cpu_address), .cpu_data_in(cpu_data_out), .ppu_data_in(ppu_data_in), .ram_data_in(ram_data_out), .ppu_read_out(ppu_read), .ppu_write_out(ppu_write), .ppu_raster_write_out(ppu_raster_write), .ppu_nmi_out(ppu_nmi), .cpu_address_out(ppu_cpu_address), .ppu_address_out(ppu_address), .cpu_data_out(ppu_cpu_data_out), .ppu_data_out(ppu_data_out), .cpu_address_en_out(ppu_cpu_address_en), .cpu_data_en_out(ppu_cpu_data_en), .cpu_disable_out(ppu_cpu_disable), .ppu_raster_data_out(ppu_raster_data));
vga nes_vga(.vga_clk_in(vga_clk), .write_clk_in(ppu_clk), .write_in(ppu_raster_write), .data_in(ppu_raster_data), .vga_csync_out(vga_csync_out), .vga_blank_out(vga_blank_out), .vga_hsync_out(vga_hsync_out), .vga_vsync_out(vga_vsync_out), .vga_red_out(vga_red_out), .vga_green_out(vga_green_out), .vga_blue_out(vga_blue_out));
vram_controller nes_vram_controller(.vram_clk_in(ppu_clk), .vram_enable_in(cart_vram_enable), .vram_read_in(ppu_read), .vram_write_in(ppu_write), .cart_address_in(cart_address), .vram_address_in(ppu_address[9:0]), .vram_data_in(ppu_data_out), .vram_data_out(vram_data_out));
apu nes_apu(.cpu_clk_in(cpu_clk), .aud_clk_in(aud_clk), .cpu_read_in(cpu_read), .cpu_write_in(cpu_write), .cpu_address_in(cpu_address), .cpu_data_in(cpu_data_out), .i2c_data_io(i2c_data_io), .i2c_clk_out(i2c_clk_out), .aud_chip_clk_out(aud_chip_clk_out), .aud_bit_clk_out(aud_bit_clk_out), .aud_channel_out(aud_channel_out), .aud_data_out(aud_data_out), .apu_irq_out(apu_irq), .cpu_data_en_out(apu_cpu_data_en), .cpu_data_out(apu_cpu_data_out));
joy nes_joy(.cpu_clk_in(cpu_clk), .cpu_read_in(cpu_read), .cpu_write_in(cpu_write), .cpu_address_in(cpu_address), .cpu_data_in(cpu_data_out), .joystick_in(joystick_io[5:0]), .buttons_in(buttons_in), .cpu_data_en_out(joy_cpu_data_en), .cpu_data_out(joy_cpu_data_out));
mapper001 nes_mapper(.cart_clk_in(ppu_clk), .cpu_clk_in(cpu_clk), .prg_read_in(cpu_read), .prg_write_in(cpu_write), .chr_read_in(ppu_read), .chr_write_in(ppu_write), .prg_address_in(cpu_address), .prg_data_in(cpu_data_out), .chr_address_in(ppu_address), .chr_data_in(ppu_data_out), .prg_data_en_out(cart_prg_data_en), .chr_data_en_out(cart_chr_data_en), .vram_enable_out(cart_vram_enable), .cart_address_out(cart_address), .prg_data_out(cart_prg_data_out), .chr_data_out(cart_chr_data_out)); //, .switches_in(switches_in), .debug_out(debug_module));

pll0 nes_pll0(.refclk(clk_50_in), .rst(0), .outclk_0(master_clk));
pll1 nes_pll1(.refclk(master_clk), .rst(0), .outclk_0(ppu_clk), .outclk_1(cpu_clk));
pll2 nes_pll2(.refclk(clk_50_in), .rst(0), .outclk_0(vga_clk));
pll3 nes_pll3(.refclk(clk_50_in), .rst(0), .outclk_0(aud_clk));

// Debug modules
//vga_test nes_vga_test(.test_clk_in(ppu_clk), .write_out(ppu_raster_write), .data_out(ppu_raster_data));
//temp nes_cpu(.cpu_clk_in(cpu_clk), .cpu_nmi_in(ppu_nmi), .cpu_irq_in(cpu_irq), .cpu_data_in(cpu_data_in), .cpu_disable(ppu_cpu_disable), .cpu_read_out(cpu_read), .cpu_write_out(cpu_write), .cpu_address_out(cpu_address), .cpu_data_out(cpu_data_out));
//seg_decode seg_data0(.val_in(debug_module[3:0]), .hex_out(hex_data0_out));
//seg_decode seg_data1(.val_in(debug_module[7:4]), .hex_out(hex_data1_out));
//seg_decode seg_data2(.val_in(debug_module[11:8]), .hex_out(hex_addr0_out));
//seg_decode seg_data3(.val_in(debug_module[15:12]), .hex_out(hex_addr1_out));


/*
seg_decode seg_data0(.val_in(switches_in[1] ? cpu_data_in[3:0] : cpu_data_out[3:0]), .hex_out(hex_data0_out));
seg_decode seg_data1(.val_in(switches_in[1] ? cpu_data_in[7:4] : cpu_data_out[7:4]), .hex_out(hex_data1_out));
seg_decode seg_addr0(.val_in(cpu_address[3:0]), .hex_out(hex_addr0_out));
seg_decode seg_addr1(.val_in(cpu_address[7:4]), .hex_out(hex_addr1_out));
seg_decode seg_addr2(.val_in(cpu_address[11:8]), .hex_out(hex_addr2_out));
seg_decode seg_addr3(.val_in(cpu_address[15:12]), .hex_out(hex_addr3_out));
*/
endmodule
