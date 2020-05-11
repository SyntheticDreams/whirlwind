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

module apu(
	input cpu_clk_in,
	input aud_clk_in,
	input cpu_read_in,
	input cpu_write_in,
	input [15:0] cpu_address_in,
	input [7:0] cpu_data_in,
	inout i2c_data_io,
	output i2c_clk_out,
	output aud_chip_clk_out,
	output aud_bit_clk_out,	
	output reg aud_channel_out,	
	output reg aud_data_out,
	output reg apu_irq_out,	
	output reg cpu_data_en_out,
	output reg [7:0] cpu_data_out,
	
	input [9:0] switches_in,	
	output reg [15:0] debug_out
);

localparam IO_APU_START = 16'h4000;
localparam IO_APU_SIZE = 16'h0020;
localparam IO_APU_PLS1_DUTY = 16'h4000;
localparam IO_APU_PLS1_SWEEP = 16'h4001;
localparam IO_APU_PLS1_TIMER = 16'h4002;
localparam IO_APU_PLS1_LENGTH = 16'h4003;
localparam IO_APU_PLS2_DUTY = 16'h4004;
localparam IO_APU_PLS2_SWEEP = 16'h4005;
localparam IO_APU_PLS2_TIMER = 16'h4006;
localparam IO_APU_PLS2_LENGTH = 16'h4007;
localparam IO_APU_TRI_LENGTH2 = 16'h4008;
localparam IO_APU_TRI_TIMER = 16'h400A;
localparam IO_APU_TRI_LENGTH = 16'h400B;
localparam IO_APU_NOISE_DUTY = 16'h400C;
localparam IO_APU_NOISE_TIMER = 16'h400E;
localparam IO_APU_NOISE_LENGTH = 16'h400F;

localparam IO_APU_STATUS = 16'h4015;
localparam IO_APU_FRAME = 16'h4017;

localparam APU_FUNC_DUTY = 4'h0;
localparam APU_FUNC_SWEEP = 4'h1;
localparam APU_FUNC_TIMER = 4'h2;
localparam APU_FUNC_LENGTH = 4'h3;

// Public registers and derived wires
reg [7:0] apu_registers [IO_APU_SIZE-1:0];

wire reg_frame_mode;
wire reg_frame_int;
wire reg_channel_enable [3:0];
wire reg_channel_halt [3:0];
wire reg_channel_const_vol [3:0];
wire reg_channel_sweep_enable [3:0];
wire reg_channel_sweep_negate [3:0];
wire reg_channel_mode [3:0];
wire [1:0] reg_channel_duty [3:0];
wire [2:0] reg_channel_sweep_period [3:0];
wire [2:0] reg_channel_sweep_shift [3:0];
wire [10:0] reg_channel_timer [3:0];
wire [4:0] reg_channel_length [3:0];
wire [6:0] reg_channel_length2 [3:0];
wire [3:0] reg_channel_volume [3:0];

assign aud_chip_clk_out = aud_clk_in;
assign aud_bit_clk_out = aud_clk_in;
assign reg_frame_mode = apu_registers[IO_APU_FRAME - IO_APU_START][7];
assign reg_frame_int = apu_registers[IO_APU_FRAME - IO_APU_START][6];

genvar assign_idx;
generate
	for (assign_idx = 0; assign_idx < 4; assign_idx = assign_idx + 1) begin : channel_assign
		assign reg_channel_enable[assign_idx] = apu_registers[IO_APU_STATUS - IO_APU_START][assign_idx];
		assign reg_channel_duty[assign_idx] = (assign_idx < 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_DUTY)][7:6] : 2'b00;
		assign reg_channel_halt[assign_idx] = (assign_idx != 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_DUTY)][5] : apu_registers[channel_offset(assign_idx, APU_FUNC_DUTY)][7];
		assign reg_channel_const_vol[assign_idx] = (assign_idx != 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_DUTY)][4] : 1'h1;
		assign reg_channel_volume[assign_idx] = (assign_idx != 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_DUTY)][3:0] : 4'hF;
		assign reg_channel_sweep_enable[assign_idx] = (assign_idx < 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_SWEEP)][7] : 1'h0;
		assign reg_channel_sweep_period[assign_idx] = (assign_idx < 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_SWEEP)][6:4] : 3'h0;
		assign reg_channel_sweep_negate[assign_idx] = (assign_idx < 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_SWEEP)][3] : 1'h1;
		assign reg_channel_sweep_shift[assign_idx] = (assign_idx < 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_SWEEP)][2:0] : 3'h0;
		assign reg_channel_timer[assign_idx] = (assign_idx < 3) ? {apu_registers[channel_offset(assign_idx, APU_FUNC_LENGTH)][2:0], apu_registers[channel_offset(assign_idx, APU_FUNC_TIMER)][7:0]} : {7'h00, apu_registers[channel_offset(assign_idx, APU_FUNC_TIMER)][3:0]};
		assign reg_channel_length[assign_idx] = apu_registers[channel_offset(assign_idx, APU_FUNC_LENGTH)][7:3];
		assign reg_channel_length2[assign_idx] = (assign_idx == 2) ? apu_registers[channel_offset(assign_idx, APU_FUNC_DUTY)][6:0] : 7'h00;
		assign reg_channel_mode[assign_idx] = (assign_idx == 3) ? apu_registers[channel_offset(assign_idx, APU_FUNC_TIMER)][7] : 1'h0;
	end
endgenerate

// Private registers and wires
reg i2c_load;
reg [7:0] i2c_idx;
reg [15:0] i2c_command;
reg [6:0] aud_frame_idx;
reg apu_cycle;
reg [15:0] apu_frame_idx;
reg [19:0] sample [3:0];  // 3 = APU, 2:1 = Sync, 0 = DAC
reg [7:0] pulse_waveforms [3:0];
reg [4:0] channel_sequence [3:0];
reg [11:0] channel_timer [3:0];
reg [7:0] channel_length [3:0];
reg [2:0] channel_sweep_divider [3:0];
reg channel_sweep_reload [3:0];
reg channel_mute [3:0];
reg [3:0] channel_envelope_divider [3:0];
reg [3:0] channel_envelope_volume [3:0];
reg channel_envelope_reload [3:0];
reg [3:0] channel_volume [3:0];
reg [6:0] channel_length2 [3:0];
reg channel_length2_reload [3:0];
reg [14:0] channel_feedback [3:0];

reg [7:0] apu_lengths [31:0];
reg [23:0] apu_waveforms [31:0];
reg [15:0] noise_periods [15:0];

wire i2c_ready;
wire io_enable;

assign io_enable = (cpu_address_in >= IO_APU_START) && (cpu_address_in < (IO_APU_START + IO_APU_SIZE)) && (cpu_address_in != 16'h4014) && (cpu_address_in != 16'h4016);

// Modules
i2c_master i2c(.mclk_in(cpu_clk_in), .i2c_command_in(i2c_command), .i2c_load_in(i2c_load), .i2c_data_io(i2c_data_io), .i2c_clk_out(i2c_clk_out), .i2c_ready_out(i2c_ready));//, .i2c_debug_out(debug_out));

// Get channel offset
function [4:0] channel_offset;
	input [4:0] channel;
	input [4:0] func;
	
	begin
		channel_offset = (channel << 2) + func;
	end
endfunction

// Determine if clock-advancing APU cycle
function is_clock_cycle;
	input quarter;
	
	begin
		is_clock_cycle = 0;
		
		if (reg_frame_mode) begin
			is_clock_cycle = is_clock_cycle || ((apu_frame_idx == 16'd7456) && quarter);
			is_clock_cycle = is_clock_cycle || (apu_frame_idx == 16'd14912);
			is_clock_cycle = is_clock_cycle || ((apu_frame_idx == 16'd22370) && quarter);
			is_clock_cycle = is_clock_cycle || (apu_frame_idx == 16'd37280);		
		end
		else begin
			is_clock_cycle = is_clock_cycle || ((apu_frame_idx == 16'd7456) && quarter);
			is_clock_cycle = is_clock_cycle || (apu_frame_idx == 16'd14912);
			is_clock_cycle = is_clock_cycle || ((apu_frame_idx == 16'd22370) && quarter);
			is_clock_cycle = is_clock_cycle || (apu_frame_idx == 16'd29828);
		end
	end
endfunction

// Initialize DAC 
task init_dac;
	begin
		if (i2c_ready) begin
		
			// Power down control - turn off mic and ADC, everything else on
			if (i2c_idx == 0) begin 
				i2c_load <= 1;
				i2c_command <= 16'b0000110_0000_00110;
			end

			// Analog control - enable bypass and DAC
			if (i2c_idx == 10) begin 
				i2c_load <= 1;
				i2c_command <= 16'b0000100_0000_11000;
			end

			// DAC control - disable high pass filter
			if (i2c_idx == 20) begin 
				i2c_load <= 1;
				i2c_command <= 16'b0000101_0000_00001;
			end

			// DAC format - DSP input mode, 20 bit samples, sample MSB on 1st bit clock rising edge
			if (i2c_idx == 30) begin
				i2c_load <= 1;
				i2c_command <= 16'b0000111_0000_00111;
			end

			// Sampling control - 96 KhZ, 128fs (256/2 for 96khz)
			if (i2c_idx == 40) begin
				i2c_load <= 1;
				i2c_command <= 16'b0001000_0000_11100;
			end
			
			// Activate DSP and audio interface
			if (i2c_idx == 50) begin
				i2c_load <= 1;
				i2c_command <= 16'b0001001_0000_00001;
			end
			
			if (i2c_idx < 100) i2c_idx = i2c_idx + 8'h01;			
		end	
	end
endtask

task init_output;
	begin
		cpu_data_out <= 0;
		cpu_data_en_out <= 0;
		i2c_load <= 0;
		channel_mute[0] <= 0;
		channel_mute[1] <= 0;
		channel_mute[2] <= 0;
		channel_mute[3] <= 0;
		channel_volume[0] <= 4'hF;
		channel_volume[1] <= 4'hF;
		channel_volume[2] <= 4'hF;
		channel_volume[3] <= 4'hF;
	end
endtask

// Process timer and length
task process_timer;
	integer channel_idx;
	
	begin
		for (channel_idx = 0 ; channel_idx < 4 ; channel_idx = channel_idx + 1) begin
			if (apu_cycle || (channel_idx == 2)) begin
				// Check for timer reset
				if (channel_timer[channel_idx] == 12'h000) begin
					// Reset pulse and triangle timer directly
					if (channel_idx < 3) begin
						channel_timer[channel_idx] <= {1'b0, reg_channel_timer[channel_idx]};
						channel_sequence[channel_idx] <= channel_sequence[channel_idx] + 5'h1;
					end
					
					// Reset noise timer using period lookup
					else begin
						channel_timer[channel_idx] <= noise_periods[reg_channel_timer[channel_idx][3:0]];
					end
					
					// Reset pulse sequence
					if ((channel_idx < 2) && (channel_sequence[channel_idx] == 5'h07)) begin
						channel_sequence[channel_idx]	<= 5'h00;
					end

				end
				else begin
					channel_timer[channel_idx] <= channel_timer[channel_idx] - 12'h001;
				end
				
				// Decrement length if enabled and half APU clock cycle
				if (~reg_channel_halt[channel_idx] && (channel_length[channel_idx] > 0) && is_clock_cycle(0)) begin
					channel_length[channel_idx] <= channel_length[channel_idx] - 8'h01;
				end
				
				// Process length2 if triangle channel and quarter APU clock cycle
				if ((channel_idx == 2) && is_clock_cycle(1)) begin
					// Reload if requested
					if (channel_length2_reload[channel_idx]) begin
						channel_length2[channel_idx] <= reg_channel_length2[channel_idx];
					end
					
					// Otherwise, if non-zero, decrement
					else if (channel_length2[channel_idx] > 0) begin
						channel_length2[channel_idx] <= channel_length2[channel_idx] - 7'h01;
					end
				
					// Clear request if not enabled
					if (~reg_channel_halt[channel_idx]) begin
						channel_length2_reload[channel_idx] <= 0;
					end
				end
				
				// Ensure all other channels have length2 values
				if (channel_idx != 2) begin
					channel_length2[channel_idx] <= 7'h01;
				end
			end			
		end
	end
endtask

// Process channel sweeps
task process_sweep;
	integer channel_idx;
	reg [11:0] change_amount;
	reg [11:0] target_amount;

	begin
		// Only pulse channels have sweeps
		for (channel_idx = 0 ; channel_idx < 2 ; channel_idx = channel_idx + 1) begin
			// Compute target period
			change_amount = reg_channel_timer[channel_idx] >> reg_channel_sweep_shift[channel_idx];

			if (reg_channel_sweep_negate[channel_idx]) begin
				// Pulse1 = One's complement, Pulse2 = Two's complement
				change_amount = (channel_idx == 0) ? ~change_amount : -change_amount;
			end
			
			target_amount = reg_channel_timer[channel_idx] + change_amount;
			
			// Mute channel if target amount is greater than 0x7ff, regardless if sweep is enabled
			if (target_amount > 11'h7ff) begin
				channel_mute[channel_idx] <= 1;
			end
			
			// Mute channel if current period is less than 8
			else if (reg_channel_timer[channel_idx] < 11'h008) begin
				channel_mute[channel_idx] <= 1;
			end
			
			// Update period if enabled, divider active, shift was not 0, not muted, and APU clock cycle
			else if (reg_channel_sweep_enable[channel_idx] && (channel_sweep_divider[channel_idx] == 0) && (reg_channel_sweep_shift[channel_idx] > 0) && is_clock_cycle(0)) begin
				{apu_registers[channel_offset(channel_idx, APU_FUNC_LENGTH)][2:0], apu_registers[channel_offset(channel_idx, APU_FUNC_TIMER)][7:0]} <= target_amount;
			end

			// Update divider
			if (is_clock_cycle(0)) begin
				if ((channel_sweep_divider[channel_idx] == 0) || channel_sweep_reload[channel_idx]) begin
					channel_sweep_divider[channel_idx] <= reg_channel_sweep_period[channel_idx];
					channel_sweep_reload[channel_idx] <= 0;
				end
				else begin
					channel_sweep_divider[channel_idx] <= channel_sweep_divider[channel_idx] - 3'h1;
				end
			end
		end
	end
endtask

// Process channel envelope
task process_envelope;
	integer channel_idx;
	
	begin
		for (channel_idx = 0 ; channel_idx < 4 ; channel_idx = channel_idx + 1) begin
			// Apply constant or envelope volume
			if (reg_channel_const_vol[channel_idx]) begin
				channel_volume[channel_idx] <= reg_channel_volume[channel_idx];
			end
			else begin
				channel_volume[channel_idx] <= channel_envelope_volume[channel_idx];
			end
			
			if (is_clock_cycle(1)) begin
				if (channel_envelope_divider[channel_idx] == 0) begin
					// If envelope volume 0 and loop flag is enabled, reset
					if ((channel_envelope_volume[channel_idx] == 0) && reg_channel_halt[channel_idx]) begin
						channel_envelope_volume[channel_idx] <= 4'hF;
					end
					
					// If volume > 0, decrement
					if (channel_envelope_volume[channel_idx] > 0) begin
						channel_envelope_volume[channel_idx] <= channel_envelope_volume[channel_idx] - 4'h1;
					end
				
					// Reload divider
					channel_envelope_divider[channel_idx] <= reg_channel_volume[channel_idx];
				end
				else begin
					channel_envelope_divider[channel_idx] <= channel_envelope_divider[channel_idx] - 4'h1;
				end
				
				// Reset all values if reload requested
				if (channel_envelope_reload[channel_idx]) begin
					channel_envelope_divider[channel_idx] <= reg_channel_volume[channel_idx];
					channel_envelope_volume[channel_idx] <= 4'hF;
					channel_envelope_reload[channel_idx] <= 0;				
				end
			end
		end
	end
endtask

task get_pulse_sample;
	input [1:0] channel_idx;
	output [19:0] pulse_sample;
	reg [7:0] cur_sequence;
	
	begin
		cur_sequence = pulse_waveforms[reg_channel_duty[channel_idx]]; // Inverts bits of reg_pls_duty[0] if not assigned to a separate register/constant value is used? Bug in synthesis?
		pulse_sample = cur_sequence[channel_sequence[channel_idx]] ? apu_waveforms[0][19:0] : apu_waveforms[16][19:0];	
	end
endtask

task get_triangle_sample;
	input [1:0] channel_idx;
	output [19:0] triangle_sample;
	reg [7:0] cur_sequence;
	
	begin
		cur_sequence = channel_sequence[channel_idx];
		triangle_sample = apu_waveforms[cur_sequence][19:0];
	end
endtask

task get_noise_sample;
	input [1:0] channel_idx;
	output [19:0] noise_sample;
	reg feedback;
	
	begin
		feedback = channel_feedback[channel_idx][0] ^ ((reg_channel_mode[channel_idx]) ? channel_feedback[channel_idx][6] : channel_feedback[channel_idx][1]);
		channel_feedback[channel_idx] <= {feedback, channel_feedback[channel_idx][14:1]};
		noise_sample = feedback ? 20'h0FFFF : 20'h000;
	end
endtask

// Calculate, mix, and set samples for channels
task mix_channels;
	integer channel_idx;
	reg signed [19:0] channel_sample [3:0];
	
	begin
		for (channel_idx = 0 ; channel_idx < 4 ; channel_idx = channel_idx + 1) begin
			// Pulse
			if (channel_idx < 2) begin
				get_pulse_sample(channel_idx, channel_sample[channel_idx]);
			end
			
			// Triangle
			if (channel_idx == 2) begin
				get_triangle_sample(channel_idx, channel_sample[channel_idx]);
			end

			// Noise
			if (channel_idx == 3) begin
				get_noise_sample(channel_idx, channel_sample[channel_idx]);
			end
			
			// Enable/appy volume
			if ((channel_length[channel_idx] > 0) && (channel_length2[channel_idx] > 0) && ~channel_mute[channel_idx]) begin
				channel_sample[channel_idx] = (channel_sample[channel_idx] * channel_volume[channel_idx]);
				if (channel_idx < 2) begin
					channel_sample[channel_idx] = channel_sample[channel_idx] >>> 6;   
				end
				else begin
					channel_sample[channel_idx] = channel_sample[channel_idx] >>> 5;
				end
			end
			else begin
				channel_sample[channel_idx] = 0;
			end
		end
		
		sample[3] <= channel_sample[0] + channel_sample[1] + channel_sample[2] + channel_sample[3];
	end
endtask

// Process CPU IO
task cpu_io;
	reg update_registers;
	
	begin
		update_registers = 0;
		
		if (io_enable) begin
			// Writes
			if (cpu_write_in) begin
				// Registers are mirrored every 8 bytes
				case (cpu_address_in)
				
					// Set pulse 1 length loader
					IO_APU_PLS1_LENGTH: begin
						// Reset all pulse values
						channel_length[0] <= reg_channel_enable[0] ? apu_lengths[cpu_data_in[7:3]] : 8'h00;
						channel_sequence[0] <= 5'h0;
						//pls_timer[0] <= 11'h000; // Not reset per hardware spec
						channel_envelope_reload[0] <= 1;
						update_registers = 1;
					end

					// Set pulse 2 length loader
					IO_APU_PLS2_LENGTH: begin
						channel_length[1] <= reg_channel_enable[1] ? apu_lengths[cpu_data_in[7:3]] : 8'h00;
						channel_sequence[1] <= 5'h0;
						//pls_timer[1] <= 11'h000; // Not reset per hardware spec
						channel_envelope_reload[1] <= 1;
						update_registers = 1;
					end

					// Set triangle length loader
					IO_APU_TRI_LENGTH: begin
						channel_length[2] <= reg_channel_enable[2] ? apu_lengths[cpu_data_in[7:3]] : 8'h00;
						channel_sequence[2] <= 5'h0;
						//pls_timer[2] <= 11'h000; // Not reset per hardware spec
						channel_length2_reload[2] <= 1;
						update_registers = 1;
					end

					// Set noise length loader
					IO_APU_NOISE_LENGTH: begin
						channel_length[3] <= reg_channel_enable[3] ? apu_lengths[cpu_data_in[7:3]] : 8'h00;
						//pls_timer[2] <= 11'h000; // Not reset per hardware spec
						channel_envelope_reload[3] <= 1;
						update_registers = 1;
					end
					
					// Set pulse 1 sweep
					IO_APU_PLS1_SWEEP: begin
						channel_sweep_reload[0] <= 0;
						update_registers = 1;
					end
					
					// Set pulse 2 sweep
					IO_APU_PLS2_SWEEP: begin
						channel_sweep_reload[1] <= 0;
						update_registers = 1;
					end
					
					// Disabled channels are immediately silenced
					IO_APU_STATUS: begin
						if (~cpu_data_in[0]) begin
							channel_length[0] <= 8'h00;
						end

						if (~cpu_data_in[1]) begin
							channel_length[1] <= 8'h00;
						end

						if (~cpu_data_in[2]) begin
							channel_length[2] <= 8'h00;
						end

						if (~cpu_data_in[3]) begin
							channel_length[3] <= 8'h00;
						end
						
						update_registers = 1;
					end
					
					// Normal registers, directly set
					default: begin
						update_registers = 1;
					end
				endcase				
			end
		
			if (update_registers) begin
				apu_registers[cpu_address_in - IO_APU_START] <= cpu_data_in;
			end
			
			// Reads
			if (cpu_read_in) begin
				// Provide data for status register
				if (cpu_address_in == IO_APU_STATUS) begin
					cpu_data_out <= {1'b0, apu_irq_out, 2'b00, (channel_length[3] > 0), (channel_length[2] > 0),(channel_length[1] > 0),(channel_length[0] > 0)};
					cpu_data_en_out <= 1;
					apu_irq_out <= 0;
				end
			end
		end		
	end
endtask

// Process APU frame
task process_apu_frame;
	begin
		// Check for IRQ
		if (~reg_frame_mode) begin
			if ((apu_frame_idx == 0) || (apu_frame_idx >= 16'd29828)) begin
				apu_irq_out <= 1;
			end
		end
		
		// Advance APU frame index
		apu_cycle <= ~apu_cycle;
		apu_frame_idx <= apu_frame_idx + 16'h0001;
		
		if (((apu_frame_idx == 16'd29829) && ~reg_frame_mode) || ((apu_frame_idx == 16'd37281) && reg_frame_mode)) begin
			apu_frame_idx <= 0;
		end
	end
endtask

initial begin
	integer channel_idx;
	integer init_idx;
	
	// Ports
	init_output();		
	
	// Public registers
	for (init_idx = 0 ; init_idx < IO_APU_SIZE ; init_idx = init_idx + 1) begin
		apu_registers[init_idx] = 8'h00;
	end
	
	// Private registers
	aud_frame_idx = 7'h00;
	apu_irq_out <= 0;
	apu_cycle = 1;
	apu_frame_idx = 16'h0000;
	sample[0] = 20'h00000;
	sample[1] = 20'h00000;
	sample[2] = 20'h00000;
	sample[3] = 20'h00000;
	pulse_waveforms[0] = 8'b01000000; // 12.5% duty
	pulse_waveforms[1] = 8'b01100000; // 25% duty
	pulse_waveforms[2] = 8'b01111000; // 50% duty
	pulse_waveforms[3] = 8'b10011111; // 75% duty
	
	for (channel_idx = 0 ; channel_idx < 4 ; channel_idx = channel_idx + 1) begin
		channel_sequence[channel_idx] = 5'h0;
		channel_timer[channel_idx] = 12'h000;
		channel_length[channel_idx] = 8'h00;
		channel_sweep_divider[channel_idx] = 3'h0;
		channel_sweep_reload[channel_idx] = 0;
		channel_envelope_divider[channel_idx] = 4'h0;
		channel_envelope_volume[channel_idx] = 4'h0;
		channel_envelope_reload[channel_idx] = 0;
		channel_length2[channel_idx] = 7'h00;
		channel_length2_reload[channel_idx] = 0;
		channel_feedback[channel_idx] = 15'h0001; // Feedback loaded with 1
	end
	
   $readmemh("roms/apu_lengths.txt", apu_lengths);
	$readmemh("roms/apu_waveforms.txt", apu_waveforms);
	$readmemh("roms/apu_noise.txt", noise_periods);		
end

// CPU clock - process logic and IO
always @ (posedge cpu_clk_in) begin
	// Initialize output to avoid latches
	init_output();
	
	// Initialize DAC, if required
	init_dac();

	// Process channels
	process_timer();
	process_sweep();
	process_envelope();
	
	// Process and mix channels
	mix_channels();
	
	// CPU IO
	cpu_io();
	
	// Process and advance next APU cycle
	process_apu_frame();
end

// Audio clock - send audio data on negative edge
always @ (negedge aud_clk_in) begin	
	aud_channel_out <= 0;
	aud_data_out <= 0;

	// Synchronize sample from APU on last 3 cycles
	if (aud_frame_idx == 7'd80) begin
		sample[2] <= sample[3];
	end
	if (aud_frame_idx == 7'd126) begin
		sample[1] <= sample[3];
	end
	if ((aud_frame_idx == 7'd127) && (sample[2] == sample[1])) begin
		sample[0] <= sample[1];
	end
		
	// Indicate start of DSP frame on index 0
	if (aud_frame_idx == 0) begin 
		aud_channel_out <= 1;
	end

	// Only 40 bits (20 bits per channel) of 128 frame are used by DAC
	if (aud_frame_idx < 40) begin
		aud_data_out <= sample[0][19 - (aud_frame_idx % 20)];
	end
	
	// Advance frame
	aud_frame_idx <= aud_frame_idx + 7'h01;
end

endmodule