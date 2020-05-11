module seg_decode(
	input [3:0] val_in,
	output [6:0] hex_out
);


assign hex_out = (val_in == 4'h0) ? 7'b1000000 :
                 (val_in == 4'h1) ? 7'b1111001 : 
					  (val_in == 4'h2) ? 7'b0100100 :
					  (val_in == 4'h3) ? 7'b0110000 :
					  (val_in == 4'h4) ? 7'b0011001 :
					  (val_in == 4'h5) ? 7'b0010010 :
					  (val_in == 4'h6) ? 7'b0000010 :
					  (val_in == 4'h7) ? 7'b1111000 :
					  (val_in == 4'h8) ? 7'b0000000 :
					  (val_in == 4'h9) ? 7'b0011000 : 
					  (val_in == 4'ha) ? 7'b0001000 : 
					  (val_in == 4'hb) ? 7'b0000011 :
					  (val_in == 4'hc) ? 7'b0100111 : 
					  (val_in == 4'hd) ? 7'b0100001 : 
					  (val_in == 4'he) ? 7'b0000110 : 
					                     7'b0001110;
					  
endmodule
