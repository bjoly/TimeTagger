/**
* The main module implements the whole functionality:
*		event tagger, command reception, command execution
*		
*/

module main_module(
	input clk_5, clk_50, clk_250,
	input reset,  	
	input single_L1, single_L2, trigger,
	input dcc_data_in,
	input [31:0] command,
	output [31:0] data_0, data_1, data_2,
	output [31:0] data_3, data_4, data_5,
	output [31:0] data_6,
	output serial2scope,
	output frame_aligned
);


wire [3:0] cmd_code;
wire h2f_ack_evt, h2f_ack_cmd;
wire f2h_notify_evt, f2h_notify_cmd;
wire [3:0] cmd_code_mem;	
wire reset_time, enable_acq;
wire [47:0] cnt_clk_5;

/************* interface assignements ******************/

assign h2f_ack_evt=command[3];
assign h2f_ack_cmd=command[4];


assign data_6={16'b0,cnt_clk_5[29:22],cmd_code_mem[3:0],enable_acq,
reset_time,f2h_notify_cmd,f2h_notify_evt}; 


/*	event tagger
*/

tagger_block tagger_block_inst(
	.clk_5(clk_5), 
	.clk_fast(clk_250),	
	.rst(reset_time), 
	.ena_acq(enable_acq),		
	.sL1(single_L1),
	.sL2(single_L2), 
	.trig(trigger),
	.h2f_ack_evt(h2f_ack_evt),	
	.f2h_notify_evt(f2h_notify_evt), 
	.data_mem_0(data_0),
	.data_mem_1(data_1),
	.data_mem_2(data_2),
	.data_mem_3(data_3),
	.data_mem_4(data_4),
	.data_mem_5(data_5),
	.cnt_clk_5(cnt_clk_5)
);	



/* command receiver 	
*/

hdmi_cmd_Rx hdmi_cmd_Rx_inst(
	.clk_50(clk_50), 
	.reset(reset), 
	.data_in(dcc_data_in),	
	.cmd_code(cmd_code),
	.frame_aligned(frame_aligned)
);


/* command execution : 
	act on reset_time and enable_acq	
*/

state_DAQ_sync state_DAQ_sync_inst(
	.clk_50(clk_50), 
	.rst(reset),
	.cmd_code(cmd_code),
	.h2f_ack_cmd(h2f_ack_cmd),		
	.f2h_notify_cmd(f2h_notify_cmd),
	.cmd_code_mem(cmd_code_mem),
	.rst_time(reset_time), 
	.enable_acq(enable_acq)
);


/*  timestamp serializer 
	for oscilloscope acquisition
*/
serializer2scope serializer2scope_inst(
	.rst(reset_time), 
	.clk(clk_250), 
	.startb(clk_5),
	.frame(cnt_clk_5[31:0]),	
	.data_out(serial2scope)		
);


endmodule