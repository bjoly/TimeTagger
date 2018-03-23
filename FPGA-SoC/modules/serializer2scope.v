// Baptiste Joly -- 11 2017

//Serializer
//encodes the timestamp in a (single wire) frame
//with synchronisation rising edges

/*
rst:		reset
clk:		clock (250 MHz)
startb:	triggers the sequence on neg edge
frame:	data to be serialised
data_out:	serialised data
*/


module serializer2scope (
	input rst, clk, startb,
	input [31:0] frame,	
	output data_out		
);
 
	reg [39:0] shiftreg;
	reg [5:0] cnt;	
	reg [1:0] state;  	
	reg load, shift;
	
	/* sequence timing */
	always@(posedge clk) begin
		if(rst) begin
			state<=2'd0;
			cnt<=6'd0;
		end
		else 
			case(state)
				2'd0: //wait
					if(startb) begin
						state<=2'd1;	
						cnt<=6'd0;
					end			
					else begin
						state<=2'd0;	
						cnt<=6'd0;
					end			
				2'd1: //ready
					if(~startb) begin
						state<=2'd2;
						cnt<=6'd0;
					end				
					else begin
						state<=2'd1;
						cnt<=6'd0;
					end				
				2'd2: //load 
				begin
					state<=2'd3;
					cnt<=6'd0;
				end
				2'd3: //shift
					if(cnt==6'd39) begin
						state<=2'd0;
						cnt<=6'd0;
					end
					else begin
						state<=2'd3;
						cnt<=cnt+6'd1;
					end
				default:
				begin
					state<=2'd0;
					cnt<=6'd0;
				end
			endcase
	end	
		
	/* shift and load pulses */
	always @(state) begin
		case (state)
			2'd2:	
				begin
					load <= 1;
					shift <= 0;						
				end
			2'd3:
				begin
					load <= 0;
					shift <= 1;	
				end
			default:
				begin
					load <= 0;
					shift <= 0;	
				end
		endcase	
	end
	
	/* main process */
			
	always@(posedge clk) begin
		if(rst)
			shiftreg<=40'd0;			
		else if(load) 	
		begin
			shiftreg[1:0]<=2'b10; //synchronisation edge
			shiftreg[9:2]<=frame[7:0];
			shiftreg[11:10]<=2'b10;
			shiftreg[19:12]<=frame[15:8];
			shiftreg[21:20]<=2'b10;
			shiftreg[29:22]<=frame[23:16];
			shiftreg[31:30]<=2'b10;
			shiftreg[39:32]<=frame[31:24];			
		end
		else if(shift)		
			shiftreg <= shiftreg >> 1;			
		else 
			shiftreg <= 40'd0;			
	end

	assign data_out=shift & shiftreg[0];

endmodule
