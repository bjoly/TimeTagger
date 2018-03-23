/**
* The tagger block implements the time counters,
* the scaler counters, and a single-event memory.
*
* This implementation is highly asynchronous.
* For understanding, wire/reg names are postfixed 
* with the signal/clock that drives the transitions.
*/

module tagger_block(
	input clk_5, clk_fast,	
	input rst, ena_acq,		
	input sL1, sL2, trig,
	input h2f_ack_evt,	
	output reg f2h_notify_evt, 
	output reg [31:0] data_mem_0,data_mem_1,data_mem_2,
	output reg [31:0] data_mem_3,data_mem_4,data_mem_5,
	output [47:0] cnt_clk_5
);	
	
wire [31:0] data_bus_0, data_bus_1, data_bus_2;
wire [31:0] data_bus_3, data_bus_4, data_bus_5;	

wire [5:0] cnt_clk_fast;
reg [6:0] tdc_L1, tdc_L2, tdc_trig;
wire [31:0] scaler_sL1, scaler_sL2, scaler_trig;		
reg trig_timed, timer;

/* output bus array	*/

assign data_bus_0=cnt_clk_5[31:0];

assign data_bus_1[15:0]=cnt_clk_5[47:32];
assign data_bus_1[31:16]=16'b0;

assign data_bus_2[6:0]=tdc_L1;
assign data_bus_2[13:7]=tdc_L2;
assign data_bus_2[20:14]=tdc_trig;
assign data_bus_2[21]=ena_acq;
assign data_bus_2[31:22]=10'b0;

assign data_bus_3=scaler_trig;
assign data_bus_4=scaler_sL1;
assign data_bus_5=scaler_sL2;





/********* counters ************/

	/* timestamp counter */
counter #(.WIDTH(48)) counter_timestamp(
	.clk(clk_5),		
	.rst(rst),		
	.cnt(cnt_clk_5)
);		
	

	/* fine TDC counter */ 
counter #(.WIDTH(6)) counter_tdc(
	.clk(clk_fast),		
	.rst(rst),			
	.cnt(cnt_clk_fast)
);		

	/* scalers	*/
counter #(.WIDTH(32)) counter_scaler_sL1 (
	.clk(sL1),		
	.rst(rst),			
	.cnt(scaler_sL1)
);	

counter #(.WIDTH(32)) counter_scaler_sL2 (
	.clk(sL2),		
	.rst(rst),			
	.cnt(scaler_sL2)
);	

counter #(.WIDTH(32)) counter_scaler_trig (
	.clk(trig),		
	.rst(rst),			
	.cnt(scaler_trig)
);	



/*********** D flip_flops on clk_fast ***********/


	/* enable pulses 
	* with metastability-killing shift reg */
	
reg sL1_d, sL2_d, trig_d;
reg sL1_dd, sL2_dd, trig_dd;
reg ena_tdc_L1_clk_fast;
reg ena_tdc_L2_clk_fast;
reg ena_tdc_trig_clk_fast;

		
always@(posedge clk_fast) begin
	sL1_d <= sL1;	
	sL2_d <= sL2;
	trig_d <= trig;	
	sL1_dd <= sL1_d;	
	sL2_dd <= sL2_d;
	trig_dd <= trig_d;
	ena_tdc_L1_clk_fast <= sL1_d & ~sL1_dd;  
	ena_tdc_L2_clk_fast <= sL2_d & ~sL2_dd; 
	ena_tdc_trig_clk_fast <= trig_d & ~trig_dd; 		
end

	/* TDC flip-flops */

always@(posedge clk_fast or posedge rst) begin
	if(rst)
		tdc_L1[6:1] <= 6'b0;
	else if(ena_tdc_L1_clk_fast)
		tdc_L1[6:1] <= cnt_clk_fast;		
end	
	 
//the lsb is the clock state latched asynchronously
//to get half-period time precision
always@(posedge sL1 or posedge rst) begin
	if(rst)
		tdc_L1[0] <= 1'b0;
	else
		tdc_L1[0] <= clk_fast;		
end


always@(posedge clk_fast or posedge rst) begin
	if(rst)
		tdc_L2[6:1] <= 6'b0;
	else if(ena_tdc_L2_clk_fast)
		tdc_L2[6:1] <= cnt_clk_fast;		
end


//the lsb is the clock state latched asynchronously
always@(posedge sL2 or posedge rst) begin
	if(rst)
		tdc_L2[0] <= 1'b0;
	else
		tdc_L2[0] <= clk_fast;		
end


always@(posedge clk_fast or posedge rst) begin
	if(rst)
		tdc_trig[6:1] <= 6'b0;
	else if(ena_tdc_trig_clk_fast)
		tdc_trig[6:1] <= cnt_clk_fast;		
end

	 
//the lsb is the clock state latched asynchronously
always@(posedge trig or posedge rst) begin
	if(rst)
		tdc_trig[0] <= 1'b0;
	else
		tdc_trig[0] <= clk_fast;		
end




/******** output memory ********/
	
	/* 
	* NOTE : we assume that (posedge trigger) always occurs after 
	* posedge single_L1 and single_L2 with sufficient delay 
	* to avoid metastability. 	
	*/


	/* enable pulse (sync 5MHz) for D flip-flop */
	
reg trig_long, ena_mem_clk5;
	
always@(posedge trig or posedge h2f_ack_evt) begin
	if(h2f_ack_evt) trig_long <= 0;
	else trig_long <= 1;
end
			/* NOTE : trig_long stays 1 as long as the memory 
			* is not read and acknowledged by the HPS. 
			* In case of pile-up, all new events are lost.
			*/  

always@(posedge clk_5) begin	
	ena_mem_clk5 <= trig_long & ~f2h_notify_evt;	
end

	/* D flip-flop with handshake */

always@(negedge clk_5 or posedge rst) begin
	if(rst) begin		
		f2h_notify_evt <= 0;		
		data_mem_0 <= 32'h0;
		data_mem_1 <= 32'h0;
		data_mem_2 <= 32'h0;
		data_mem_3 <= 32'h0;
		data_mem_4 <= 32'h0;
		data_mem_5 <= 32'h0;
	end
	else if(ena_mem_clk5) begin
		f2h_notify_evt <= 1;		
		data_mem_0 <= data_bus_0;
		data_mem_1 <= data_bus_1;
		data_mem_2 <= data_bus_2;
		data_mem_3 <= data_bus_3;
		data_mem_4 <= data_bus_4;
		data_mem_5 <= data_bus_5;
	end
	else if(h2f_ack_evt) begin
		f2h_notify_evt <= 0;	
		data_mem_0 <= 32'h0;
		data_mem_1 <= 32'h0;
		data_mem_2 <= 32'h0;
		data_mem_3 <= 32'h0;
		data_mem_4 <= 32'h0;
		data_mem_5 <= 32'h0;
	end
end	

	
endmodule