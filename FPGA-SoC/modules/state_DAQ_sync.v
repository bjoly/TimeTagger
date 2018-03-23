/*
* DAQ state synchronisation module
* receives command code, emits reset_bcid and enable_acq signals
*/

module state_DAQ_sync(
	input clk_50, rst,
	input [3:0] cmd_code,
	input h2f_ack_cmd,			//for debug - the HPS acknowledges having read "cmd_code_mem"	
	output reg f2h_notify_cmd,	//for debug - alert the HPS about a non-idle command
	output reg [3:0] cmd_code_mem, 	//for debug - store the non-idle command before "cmd_code" is overwritten
	output reg rst_time, enable_acq
);

wire cmd_idle=(cmd_code==4'hE);
wire cmd_reset_dif=(cmd_code==4'h0);
wire cmd_reset_bcid=(cmd_code==4'h1);
wire cmd_start_acq=(cmd_code==4'h2);
wire cmd_ramfull_ext=(cmd_code==4'h3);
wire cmd_stop_acq=(cmd_code==4'h5);

reg timer;

/* toggle "enable_acq" */
always@(posedge clk_50 or posedge rst) begin
	if(rst)
		enable_acq<=0;
	else if(cmd_ramfull_ext || cmd_stop_acq || cmd_reset_dif || cmd_reset_bcid)
		enable_acq<=0;
	else if(cmd_start_acq)
		enable_acq<=1;
	else
		enable_acq<=enable_acq;
end


/* toggle "rst_time" */
always@(posedge clk_50 or posedge rst) begin
	if(rst)
		rst_time<=1;
	else if(cmd_reset_bcid || cmd_reset_dif) 
		rst_time<=1;
	else 
		rst_time<=0;
end

/* HPS-FPGA handshaking */
always@(posedge clk_50 or posedge rst) begin
	if(rst) begin		
		f2h_notify_cmd <= 0;
		cmd_code_mem <= 4'hE;
	end
	else if(h2f_ack_cmd) begin
		f2h_notify_cmd <= 0;
		cmd_code_mem <= 4'hE;
	end
	//if command other than "idle" or than last command
	else if(!cmd_idle && (cmd_code!=cmd_code_mem)) begin  
		f2h_notify_cmd <= 1;
		cmd_code_mem <= cmd_code;
	end	
end

endmodule
