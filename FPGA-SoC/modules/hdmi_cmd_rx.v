//sDCC->DIF command receiver
//

module hdmi_cmd_Rx(
	input clk_50, reset, 
	input data_in,	
	output reg [3:0] cmd_code,
	output frame_aligned //for debug
);


reg [119:0] frame_50;
wire [11:0] frame_5;


//shift register
always@(posedge clk_50 or posedge reset) begin
	if(reset) 	
		frame_50 <= 0;
	else begin		
		frame_50[118:0] <= frame_50[119:1];
		frame_50[119] <= data_in;
	end
end


//picks the sample at the center of each period
assign frame_5[0]=frame_50[5];
assign frame_5[1]=frame_50[15];
assign frame_5[2]=frame_50[25];
assign frame_5[3]=frame_50[35];
assign frame_5[4]=frame_50[45];
assign frame_5[5]=frame_50[55];
assign frame_5[6]=frame_50[65];
assign frame_5[7]=frame_50[75];
assign frame_5[8]=frame_50[85];
assign frame_5[9]=frame_50[95];
assign frame_5[10]=frame_50[105];
assign frame_5[11]=frame_50[115];


//when the frame is aligned with the register,
//2 conditions are met
assign frame_aligned=((frame_5[3:0]==4'hD) && (frame_5[11:8]==(frame_5[7:4]^4'hD)));

always@(posedge clk_50 or posedge reset) begin
	if(reset) 
		cmd_code <= 4'hE;		//idle command			
	else if(frame_aligned) 
		cmd_code <= frame_5[7:4];	
	else 
		cmd_code <= 4'hE;			
end

	
endmodule
