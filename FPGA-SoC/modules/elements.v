// Baptiste Joly -- 08 2017
// collection of elementary blocks


//one-shot D Flip Flop
	//triggered by (posedge clk), 
	//enabled by positive transition of "trig"

module OneShotDFF(d, trig, clk, rst, q);
// port declaration
input   d;
input	trig, clk, rst;
output  q;


wire mem;

//copy d to mem when trig is low
dffe dff_in (.d (d), .clk (clk),
		.clrn(~rst), .prn(1'b1), .ena(~trig), 
		.q (mem));
		
//copy mem to q when trig is high 	
dffe dff_out (.d (mem), .clk (clk),
		.clrn(~rst), .prn(1'b1), .ena(trig),
		.q (q));	

endmodule





/* counter with asynchronous reset */

module counter #(parameter WIDTH=32)(
	input clk, rst,
	output reg [WIDTH-1:0] cnt
);

	always@(posedge clk or posedge rst) begin
		if(rst) 		
			cnt <= 0;			
		else  			
			cnt<=cnt+1'b1;			
	end

endmodule


/**---------SPECIAL COUNTERS-------------
*/


/* counter with periodic reset 
for synchronisation with a slower clock
*/

module counter_sync #(parameter WIDTH=32)(
	input clk, sync,
	output reg [WIDTH-1:0] cnt
);

	reg reset, sync_dly;
	
	//one-shot synchronous reset pulse
	//edge detector
	always@(posedge clk) begin		
		reset <= sync & ~sync_dly;	
		sync_dly <= sync;
	end
	
	//counter
	always@(posedge clk) begin
		if(reset) 		
			cnt <= 0;			
		else  			
			cnt<=cnt+1'b1;	
	end

endmodule
