module i2c_master(
	input mclk_in,
	input [15:0] i2c_command_in,
	input i2c_load_in,
	inout i2c_data_io,
	output i2c_clk_out,	
	output i2c_ready_out,
	output reg i2c_debug_out
);

// Variable parameters
localparam SLAVE_ADDRESS = 8'b00110100;
localparam CLOCK_DIVIDER = 3;

// Constant parameters
localparam STATE_I2C_START = 2'h0;
localparam STATE_I2C_PAYLOAD = 2'h1;
localparam STATE_I2C_ACK = 2'h2;
localparam STATE_I2C_STOP = 2'h3;
localparam STATE_BUFFER_READY = 2'h0;
localparam STATE_BUFFER_LOADED = 2'h1;
localparam STATE_BUFFER_BUSY = 2'h2;

reg data_out;
reg data_enable;
reg idle_mode;
reg ack_fail;
reg [CLOCK_DIVIDER:0] clock_div;
reg [1:0] i2c_state;
reg [1:0] buffer_state;
reg [4:0] bit_idx;
reg [23:0] buffer;

assign i2c_clk_out = idle_mode ? 1'b1 : clock_div[CLOCK_DIVIDER];
assign i2c_data_io = data_enable ? (data_out ? 1'bZ : 1'b0) : 1'bZ;
assign i2c_ready_out = (buffer_state == STATE_BUFFER_READY);
//assign i2c_debug_out = ack_fail;

task i2c_init;
	begin
		data_enable <= 1;
		data_out <= 1;
		bit_idx <= 23;
	end
endtask

initial begin
	i2c_state = STATE_I2C_STOP;
	buffer_state = STATE_BUFFER_READY;
	clock_div = 0;
	idle_mode = 1;
	ack_fail = 0;
	//i2c_debug_out = 0;

	i2c_init();
end

// Advance i2c clock
always @ (posedge mclk_in) begin
	clock_div <= clock_div + 4'h1;
end


// Buffer load handling
always @ (posedge mclk_in) begin
	// Command ready for load
	if (buffer_state == STATE_BUFFER_READY && i2c_load_in) begin
		buffer = {SLAVE_ADDRESS, i2c_command_in};
		buffer_state <= STATE_BUFFER_LOADED;
	end
	
	// Command executing
	else if (i2c_state == STATE_I2C_START) buffer_state <= STATE_BUFFER_BUSY;
	
	// Command complete (Stop state, buffer busy, idle mode, and data high), reset
	else if (i2c_state == STATE_I2C_STOP && buffer_state == STATE_BUFFER_BUSY &&
				idle_mode && i2c_data_io) buffer_state <= STATE_BUFFER_READY;
		
end

// ACK and idle mode check
always @ (posedge clock_div[CLOCK_DIVIDER]) begin
//always @ (posedge mclk_in) begin
//	if (clock_div == 8) begin
	// Disable idle mode when in payload state, reenable for start/stop state
	if (i2c_state == STATE_I2C_PAYLOAD) idle_mode <= 0;
	if (i2c_state == STATE_I2C_START) idle_mode <= 1;
	if (i2c_state == STATE_I2C_STOP && data_enable) idle_mode <= 1;

	// Reset ACK failure when reset to start state
	if (i2c_state == STATE_I2C_START) ack_fail <= 0;
	
	// Check for ACK from slave (data line low)
	else begin
		if (~data_enable && i2c_data_io) begin
			ack_fail <= 1;
			i2c_debug_out <= i2c_data_io;
		end	
	end
	//end
end

always @ (negedge clock_div[CLOCK_DIVIDER]) begin
	// Check for command
	if (buffer_state == STATE_BUFFER_LOADED) i2c_state <= STATE_I2C_START;
	
	// Check for ACK failures
	if (ack_fail) i2c_state <= STATE_I2C_START;
	
	// Process states
	case (i2c_state)
		STATE_I2C_START: begin
			i2c_init();
			if (idle_mode && data_enable && data_out) begin
				data_out <= 0;
				i2c_state <= STATE_I2C_PAYLOAD;
			end
		end
		
		STATE_I2C_STOP: begin
			//i2c_debug_out = (buffer[15:0] == 16'b0000100111111111);
			data_enable <= 1;
			data_out <= 0;
			if (idle_mode) data_out <= 1;				
		end
		
		STATE_I2C_ACK: begin
			if (bit_idx == 0) i2c_state <= STATE_I2C_STOP;
			else i2c_state <= STATE_I2C_PAYLOAD;
			data_enable <= 0;
		end
		
		STATE_I2C_PAYLOAD: begin
			data_enable <= 1;
			data_out <= buffer[bit_idx];
			if (bit_idx % 8 == 0) i2c_state <= STATE_I2C_ACK;
			
			// Advance counters
			if (bit_idx > 0) bit_idx <= bit_idx - 5'h01;
		end
	endcase
end


endmodule
