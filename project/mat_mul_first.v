
`define OUTPUT_NODE_NUM 5
`define INPUT_NODE_NUM 2
`define HIDDEN_NODE_NUM 4
`define DATA_BIT_NUM 16

module mat_mul_first(
	input wire clk,
	input wire reset_n,
	input wire [ (`INPUT_NODE_NUM * `DATA_BIT_NUM)-1 : 0] IN,
	input wire [ (`INPUT_NODE_NUM * `DATA_BIT_NUM)-1 : 0] W,
	input wire data_in1,



	output wire ready1,
	output reg [ `DATA_BIT_NUM-1 : 0] element1
);

reg [2:0] STATE;
reg [2:0] NEXT_STATE;

parameter IDLE = 0;
parameter START = 1;
parameter ADD = 3;
parameter DONE = 4;

reg temp_ready;
reg parse_done;
reg operation_done;
reg [9:0] count;

reg [(`DATA_BIT_NUM-1) : 0] parse_in [0: `INPUT_NODE_NUM-1];
reg [(`DATA_BIT_NUM-1) : 0] parse_w [0: `INPUT_NODE_NUM-1];
reg [(`DATA_BIT_NUM-1) : 0] temp_element;

assign ready1 = temp_ready;


always @(posedge clk) begin
	// IDLE
	if(STATE == IDLE) begin
		if(data_in1==1) begin
			element1 = 0;
			count = 0;
			parse_done = 0;
			operation_done = 0;
			NEXT_STATE = START;
		end
		else begin
			temp_ready = 1;
			NEXT_STATE = IDLE;
		end
	end

	// START
	else if(STATE == START) begin
		temp_ready = 0;
		if(count == `INPUT_NODE_NUM) begin
			if(element1[15] == 1) element1 = 0;
			NEXT_STATE = DONE;
		end
		else if(parse_done == 1)begin
			if((parse_in[count] == 16'd0) || parse_w[count] == 16'd0) begin
				temp_element = 0;
			end
			else begin
				temp_element[(`DATA_BIT_NUM - 2):0] = parse_in[count][(`DATA_BIT_NUM - 2):0] * parse_w[count][(`DATA_BIT_NUM - 2):0] ;
		    		temp_element[`DATA_BIT_NUM - 1] = (parse_in[count][`DATA_BIT_NUM - 1] ^ parse_w[count][`DATA_BIT_NUM - 1]);
			end
			parse_done = 0;
			operation_done = 1;
			NEXT_STATE = START;

		end
		else if(operation_done == 1)begin
			element1 = element1 + temp_element;
			count = count + 1;
			parse_done = 0;
			operation_done = 0;
			NEXT_STATE = START;
		end 
		else begin
			parse_in[count] = IN[`DATA_BIT_NUM*count+: 16];
			parse_w[count] = W[`DATA_BIT_NUM*count+: 16];
			parse_done = 1;
			operation_done = 0;
			NEXT_STATE = START;
		end

	end
	else if(STATE == DONE) begin

		NEXT_STATE = IDLE;
		temp_ready = 1;
	end
	else begin
		NEXT_STATE = IDLE;
	end
end

always @(posedge clk) begin
	if(reset_n == 0) begin
		STATE <= IDLE;
	end
	else begin 
		STATE <= NEXT_STATE;
	end
end




endmodule 
