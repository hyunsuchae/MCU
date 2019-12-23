//`define HIDDEN_LAYER_NUM 2
//`define OUTPUT_NODE_NUM 10
//`define INPUT_NODE_NUM 3
//`define HIDDEN_NODE_NUM 3
//`define DATA_BIT_NUM 16      

module NN_core(

  input wire            clk,
  input wire            reset_n,

  input wire            first_chunk_flag,
  input wire            middle_chunk_flag,
  input wire            last_chunk_flag,

//  input wire [3:0]      middle_chunk_count,

  input wire [ (`DATA_BIT_NUM * `INPUT_NODE_NUM)-1 : 0]  input_block,
  input wire [ (`DATA_BIT_NUM * `INPUT_NODE_NUM * `HIDDEN_NODE_NUM)-1 : 0] first_weight_block,
  input wire [ (`DATA_BIT_NUM * `HIDDEN_NODE_NUM * `HIDDEN_NODE_NUM)-1 : 0] middle_weight_block,
  input wire [ (`DATA_BIT_NUM * `HIDDEN_NODE_NUM * `OUTPUT_NODE_NUM)-1 : 0] last_weight_block,

  output wire           ready,
  output wire [(`DATA_BIT_NUM * `OUTPUT_NODE_NUM)-1 : 0] final_output
//  output wire           activation_valid
);

//----------------------------------------------------------------
// wire and reg
//----------------------------------------------------------------

	reg [3:0] STATE;
	reg [3:0] NEXT_STATE;


parameter IDLE          = 0;
parameter PARSE1        = 1;
parameter MATRIX_MUL1   = 2;
parameter HOLD1         = 3;
parameter DONE1         = 4;

parameter PARSE2        = 5;
parameter MATRIX_MUL2   = 6;
parameter HOLD2         = 7;
parameter DONE2         = 8;

parameter PARSE3        = 9;
parameter MATRIX_MUL3   = 10;
parameter HOLD3         = 11;
parameter DONE3         = 12;



//----------------------------------------------------------------
// Registers 
//----------------------------------------------------------------

  reg [10:0] count;
  reg [10:0] count_i;
  reg [10:0] temp;
  reg [10:0] shift;
  reg parse_done;


  reg [(`DATA_BIT_NUM * `INPUT_NODE_NUM)-1 : 0] temp_parse_w_first [0: `HIDDEN_NODE_NUM-1];
  reg [(`DATA_BIT_NUM * `HIDDEN_NODE_NUM)-1 : 0] temp_parse_w_middle [0: `HIDDEN_NODE_NUM-1];
  reg [(`DATA_BIT_NUM * `HIDDEN_NODE_NUM)-1 : 0] temp_parse_w_last [0: `OUTPUT_NODE_NUM-1];
//  reg [(`DATA_BIT_NUM * `INPUT_NODE_NUM)-1 : 0] parse_w0 [0: `HIDDEN_NODE_NUM-1];


  wire [(`DATA_BIT_NUM-1) : 0] layer_output1;
  wire [(`DATA_BIT_NUM-1) : 0] layer_output2;
  wire [(`DATA_BIT_NUM-1) : 0] layer_output3;
  reg [(`DATA_BIT_NUM * `HIDDEN_NODE_NUM)-1 : 0] layer_output_reg;

  reg [(`DATA_BIT_NUM * `HIDDEN_NODE_NUM) -1 : 0] layer_input;

  reg data_in1;
  reg data_in2;
  reg data_in3;
 
      // parse_in[count] = IN[`DATA_BIT_NUM*count+: 16];
      // parse_w0[count] = W0[`DATA_BIT_NUM*count+: 16];


//----------------------------------------------------------------
// assign
//----------------------------------------------------------------
  reg ready_flag;
  assign ready = ready_flag;
  reg [(`DATA_BIT_NUM * `OUTPUT_NODE_NUM) -1 : 0] final_output_reg;
  assign final_output = final_output_reg;
  reg check;

  wire ready1;
  wire ready2;
  wire ready3;

//----------------------------------------------------------------
// FSM
//----------------------------------------------------------------

always @(posedge clk) begin
  if(STATE == IDLE) begin
    if(first_chunk_flag == 1) begin          // input and w0 came
      count = 0;
      count_i = 0;
      data_in1 = 0;
      data_in2 = 0;
      data_in3 = 0;
      parse_done = 0;
      ready_flag = 0;                  
      temp_parse_w_first[0] = 0;
      NEXT_STATE = PARSE1;
    end
    else if(middle_chunk_flag == 1) begin
      layer_input = layer_output_reg;
      count = 0;
      count_i = 0;
      data_in2 = 0;
      parse_done = 0;               
      temp_parse_w_middle[0] = 0;
      ready_flag = 0;                  
      NEXT_STATE = PARSE2;
    end
    else if(last_chunk_flag == 1) begin
      layer_input = layer_output_reg;
      count = 0;
      count_i = 0;
      data_in3 = 0;
      parse_done = 0;               
      temp_parse_w_last[0] = 0;
      ready_flag = 0;  
      NEXT_STATE = PARSE3;
    end
    else begin
      ready_flag = 1;
      parse_done = 0;
      NEXT_STATE = IDLE;
    end
  end 

  //////////////////////////////////////////////////
  // PARSE 1 state
  //////////////////////////////////////////////////
  else if(STATE == PARSE1) begin
    if(count == `HIDDEN_NODE_NUM) begin
      NEXT_STATE = DONE1;
    end
    else if (check == 1) begin // step2
	count_i = count_i +1;
	check = 0;
      NEXT_STATE = PARSE1;
    end
    else if((parse_done == 0) && (count_i < `INPUT_NODE_NUM)) begin //step1
	temp = `DATA_BIT_NUM * (count+`HIDDEN_NODE_NUM * count_i);
	shift = (16* count_i);
        temp_parse_w_first[count] = (first_weight_block[temp+: 16]<<shift) + temp_parse_w_first[count];
	check = 1;
      NEXT_STATE = PARSE1;
    end 
    else if((parse_done == 0) && (count_i == `INPUT_NODE_NUM)) begin  // step2
      parse_done = 1;
      NEXT_STATE = PARSE1;
    end
    else if((parse_done == 1) &&( count < `HIDDEN_NODE_NUM) && (ready1 == 1)) begin //step3
      if(count< `HIDDEN_NODE_NUM - 1) temp_parse_w_first[count+1] = 0;
      parse_done = 0;    
      data_in1 = 1;
      count_i = 0;
      NEXT_STATE = MATRIX_MUL1;

    end
    else begin 
      NEXT_STATE = PARSE1;
    end
  end

  //////////////////////////////////////////////////
  // MATRIX_MUL 1 state
  //////////////////////////////////////////////////  
  else if(STATE == MATRIX_MUL1) begin
    if(ready1 == 1) begin
      data_in1 = 0;
      NEXT_STATE = HOLD1;
    end
    else begin
      data_in1 = 1;
      NEXT_STATE = MATRIX_MUL1;
    end
  end

  //////////////////////////////////////////////////
  // HOLD 1 state
  //////////////////////////////////////////////////
  else if(STATE == HOLD1) begin
    if(ready1 == 1) begin
      if(count == 0) layer_output_reg = layer_output1[15:0];
      else layer_output_reg = (layer_output1[15:0] << (16*count)) + layer_output_reg;
      NEXT_STATE = DONE1;
    end
    else begin
      NEXT_STATE = HOLD1;
    end
  end


  //////////////////////////////////////////////////
  // DONE 1 state
  //////////////////////////////////////////////////
  else if(STATE == DONE1) begin
    if( count < `HIDDEN_NODE_NUM ) begin   
      count = count+1;
      NEXT_STATE = PARSE1;
    end
    else begin
      data_in1 = 0;
      count = 0;
      ready_flag = 1;
      NEXT_STATE = IDLE;
    end
  end
//////////////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////
  // PARSE 2 state
  //////////////////////////////////////////////////
  else if(STATE == PARSE2) begin
    if(count == `HIDDEN_NODE_NUM) begin
      NEXT_STATE = DONE2;
    end
    else if (check == 1) begin // step2
      count_i = count_i +1;
      check = 0;
      NEXT_STATE = PARSE2;
    end
    else if((parse_done == 0) && (count_i < `HIDDEN_NODE_NUM)) begin //step1
      temp = `DATA_BIT_NUM * (count+`HIDDEN_NODE_NUM * count_i);
      shift = (16* count_i);
      temp_parse_w_middle[count] = (middle_weight_block[temp+: 16]<<shift) + temp_parse_w_middle[count];
      check = 1;
      NEXT_STATE = PARSE2;
    end 
    else if((parse_done == 0) && (count_i == `HIDDEN_NODE_NUM)) begin  // step2
      parse_done = 1;
      NEXT_STATE = PARSE2;
    end
    else if((parse_done == 1) &&( count < `HIDDEN_NODE_NUM) && (ready2 == 1)) begin //step3
      if(count< `HIDDEN_NODE_NUM - 1) temp_parse_w_middle[count+1] = 0;
      parse_done = 0;    
      data_in2 = 1;
      count_i = 0;
      NEXT_STATE = MATRIX_MUL2;

    end
    else begin 
      NEXT_STATE = PARSE2;
    end
  end

  //////////////////////////////////////////////////
  // MATRIX_MUL 2 state
  //////////////////////////////////////////////////  
  else if(STATE == MATRIX_MUL2) begin
    if(ready2 == 1) begin
      data_in2 = 0;
      if(count == 0) layer_output_reg = 0;
      NEXT_STATE = HOLD2;
    end
    else begin
      data_in2 = 1;
      NEXT_STATE = MATRIX_MUL2;
    end
  end

  //////////////////////////////////////////////////
  // HOLD 2 state
  //////////////////////////////////////////////////
  else if(STATE == HOLD2) begin
    if(ready2 == 1) begin
      if(count == 0) layer_output_reg = layer_output2[15:0];
      else layer_output_reg = (layer_output2[15:0]<<(16*count)) + layer_output_reg;
      NEXT_STATE = DONE2;
    end
    else begin
      NEXT_STATE = HOLD2;
    end
  end


  //////////////////////////////////////////////////
  // DONE 2 state
  //////////////////////////////////////////////////
  else if(STATE == DONE2) begin
    if( count < `HIDDEN_NODE_NUM ) begin   
      count = count+1;
      NEXT_STATE = PARSE2;
    end
    else begin
      data_in2 = 0;
      count = 0;
      ready_flag = 1;
      NEXT_STATE = IDLE;
    end
  end
  ///////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////
  // PARSE 3 state
  //////////////////////////////////////////////////
  else if(STATE == PARSE3) begin
    if(count == `OUTPUT_NODE_NUM) begin
      NEXT_STATE = DONE3;
    end
    else if (check == 1) begin // step2
      count_i = count_i +1;
      check = 0;
      NEXT_STATE = PARSE3;
    end
    else if((parse_done == 0) && (count_i < `HIDDEN_NODE_NUM)) begin //step1
      temp = `DATA_BIT_NUM * (count+`OUTPUT_NODE_NUM * count_i);
      shift = (16* count_i);
      temp_parse_w_last[count] = (last_weight_block[temp+: 16]<<shift) + temp_parse_w_last[count];
      check = 1;
      NEXT_STATE = PARSE3;
    end 
    else if((parse_done == 0) && (count_i == `HIDDEN_NODE_NUM)) begin  // step2
      parse_done = 1;
      NEXT_STATE = PARSE3;
    end
    else if((parse_done == 1) &&( count < `OUTPUT_NODE_NUM) && (ready3 == 1)) begin //step3
      if(count< `OUTPUT_NODE_NUM - 1) temp_parse_w_last[count+1] = 0;
      parse_done = 0;    
      data_in3 = 1;
      count_i = 0;
      NEXT_STATE = MATRIX_MUL3;

    end
    else begin 
      NEXT_STATE = PARSE3;
    end
  end

  //////////////////////////////////////////////////
  // MATRIX_MUL 3 state
  //////////////////////////////////////////////////  
  else if(STATE == MATRIX_MUL3) begin
    if(ready3 == 1) begin
      data_in3 = 0;
      NEXT_STATE = HOLD3;
    end
    else begin
      data_in3 = 1;
      NEXT_STATE = MATRIX_MUL3;
    end
  end

  //////////////////////////////////////////////////
  // HOLD 3 state
  //////////////////////////////////////////////////
  else if(STATE == HOLD3) begin
    if(ready3 == 1) begin
      if(count == 0) final_output_reg = layer_output3[15:0];
      else final_output_reg = (layer_output3[15:0]<<(16*count)) + final_output_reg;
      NEXT_STATE = DONE3;
    end
    else begin
      NEXT_STATE = HOLD3;
    end
  end


  //////////////////////////////////////////////////
  // DONE 3 state
  //////////////////////////////////////////////////
  else if(STATE == DONE3) begin
    if( count < `OUTPUT_NODE_NUM ) begin   
      count = count+1;
      NEXT_STATE = PARSE3;
    end
    else begin
      data_in3 = 0;
      count = 0;
      ready_flag = 1;
      NEXT_STATE = IDLE;
    end
  end

end

//----------------------------------------------------------------
// UPDATE NEXT STATE
//----------------------------------------------------------------
 
always @(posedge clk or negedge reset_n) begin             
  if ( reset_n  == 1'b0 ) begin          // In reset
      data_in1 = 0;
      data_in2 = 0;
      data_in3 = 0;
    STATE           <=  IDLE;           // Start in the IDLE STATE waiting for Start 
  end 
     
  else begin      // Not in reset
    STATE           <= NEXT_STATE;
  end             
end

mat_mul_first MAT_MUL1(.clk(clk), .reset_n(reset_n), .IN(input_block), .W(temp_parse_w_first[count]), .data_in1(data_in1), .ready1(ready1), .element1(layer_output1));
mat_mul_next MAT_MUL2(.clk(clk), .reset_n(reset_n), .IN(layer_input), .W(temp_parse_w_middle[count]), .data_in2(data_in2), .ready2(ready2), .element2(layer_output2));
mat_mul_next MAT_MUL3(.clk(clk), .reset_n(reset_n), .IN(layer_input), .W(temp_parse_w_last[count]), .data_in2(data_in3), .ready2(ready3), .element2(layer_output3));

endmodule
