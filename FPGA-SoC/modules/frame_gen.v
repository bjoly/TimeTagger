//module that emits a given frame
	//ena low: load the "frame"
	//ena high: generate the ouptut
	//rotate low: one-shot frame (then 0)
	//rotate high: periodic frame

module frame_gen #(parameter WIDTH=32)(
	input clk, ena, 
	input [WIDTH-1:0] frame,
	input rotate,
	output pulse		
);
 
	reg [WIDTH-1:0] shiftreg;
	assign pulse=shiftreg[0]; //lsb outputs first, msb last

	reg ena_sync;

	always@(posedge clk) begin
		ena_sync <= ena;
	end
	
	always@(posedge clk) begin
		if(~ena_sync)
			shiftreg<=frame;
		else if(rotate) begin	
			shiftreg[WIDTH-1]<=shiftreg[0];
			shiftreg[WIDTH-2:0]<=shiftreg[WIDTH-1:1];
		end
		else			
			shiftreg <= shiftreg >> 1;			
	end

endmodule
