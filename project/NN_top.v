//`define HIDDEN_LAYER_NUM 2
//`define OUTPUT_NODE_NUM 10
//`define INPUT_NODE_NUM 3
//`define HIDDEN_NODE_NUM 3
//`define DATA_BIT_NUM 16   
`define BRAM_ADDR_BIT 32

module NN_top (
	       
	       // AXI I/F Signals  
	           input   wire            nn_clk,            // NOTE: Same as AXI_CLK
	           input   wire            nn_rst_n,          // Active LOW
	           input   wire            axi_start_nn,      // Start signal from control reg


	           input   wire [31:0]     nn_layer_nums,     // # of 512-bit chunks to process
   	           input   wire [`BRAM_ADDR_BIT-1:0]     nn_bram_addr_start,// Starting BRAM address of chunk


   	           output  reg  [(`DATA_BIT_NUM * `OUTPUT_NODE_NUM)-1 : 0]    nn_final_output_reg,
               output  reg             nn_status,
               output  reg             nn_interrupt,
               output  wire            nn_final_output_valid,   


	       // BRAM I/F Signals   
	           output  reg             nn_start_read,     // Start read transaction 
	           output  reg  [`BRAM_ADDR_BIT-1:0]     nn_bram_addr,      // Address to the BRAM 


	           input   wire [`DATA_BIT_NUM-1:0]     nn_bram_read_data,  // BRAM read data to nn
               input   wire            bram_complete       // JIM: Should be with BRAM Signals
	           );
	            



// --------------------[  WIRES and REGISTERS  ]-----------------------------------          

wire            ready;                          // Ready signal from NN core
wire [(`DATA_BIT_NUM * `OUTPUT_NODE_NUM) -1 : 0]    nn_final_output;                     // nn256 output

reg             first_chunk_flag;                    // Flag to indicate first chunk

reg             middle_chunk_flag;                     // Flag to indicate next chunk
reg             middle_chunk_pending;             // 

reg             last_chunk_flag;                    // Flag to indicate first chunk
reg             last_chunk_pending;                    // Flag to indicate first chunk

reg             nn_data_valid;                 // Start flag to nn unit
reg             nn_core_rst_n;                 // 1/2 cycle delay

reg [31:0]      nn_chunk_ctr;                  // Chunk counter
reg [31:0]      nn_chunk_ctr_nxt;              // Chunk counter

reg [`BRAM_ADDR_BIT-1:0]      nn_bram_addr_nxt;              // Address counter
reg [3:0]       STATE;
reg [3:0]       NXT_STATE;   

reg             first_time;


reg [ (`DATA_BIT_NUM * `INPUT_NODE_NUM)-1 : 0]  input_block;
reg [ (`DATA_BIT_NUM * `INPUT_NODE_NUM * `HIDDEN_NODE_NUM)-1 : 0] first_weight_block;
reg [ (`DATA_BIT_NUM * `HIDDEN_NODE_NUM * `HIDDEN_NODE_NUM)-1 : 0] middle_weight_block;
reg [ (`DATA_BIT_NUM * `HIDDEN_NODE_NUM * `OUTPUT_NODE_NUM)-1 : 0] last_weight_block;


localparam  
        INIT        = 8,
        NN_READ1   = 1,
        NN_READ2   = 2,
        NN_READ3   = 3,        
        START_NN   = 4,
        WAIT1_NN    = 5,
        LOOP_NN    = 6,       
        HOLD        = 7,    // Not used
        WAIT2_NN    = 0;
            
            
// ------------------------------------------------------------------------
// This State Machine fetches chunks from the BRAM and sends it to 
// the nn core. It then starts the conversion and waits for the result.
//
    reg [31:0]       reg_num;
    reg [31:0]       reg_num_nxt;
    
    
    always @( posedge nn_clk or negedge nn_rst_n) begin : reg_reset
//        integer i;  
        if ( nn_rst_n == 1'b0 ) begin
            input_block <= 0;
            first_weight_block <= 0;
            middle_weight_block <= 0;
            last_weight_block <=0;
            
            first_chunk_flag         <=  1'b0;       // Start with the first chunk 
            middle_chunk_flag         <=  1'b0;       // Followed by the next one, etc.
            middle_chunk_pending  <=  1'b0;  
            last_chunk_flag         <=  1'b0;       // Followed by the next one, etc.
            last_chunk_pending  <=  1'b0;       
            nn_chunk_ctr       <= 32'h0;
            nn_bram_addr       <= 32'h0;      
            nn_data_valid      <=  1'b0;       // Start signal to nn unit
            reg_num_nxt         <=  4'b0;       // 16 byte counter for each chunk
            nn_start_read      <=  1'b0;       // Control 
            first_time          <=  1'b1;
            nn_status          <=  1'b0;
            nn_interrupt       <=  1'b0;

            NXT_STATE           <= INIT;
        end
            
        else if ( nn_rst_n == 1'b1 ) begin        
        
        // ------------------[    INIT STATE  ]--------------------------------------   
        //
            if (STATE == INIT) begin
                    if((axi_start_nn == 1'b1) && (first_time == 1'b1)) begin
                            nn_bram_addr       <= nn_bram_addr_start;     // Get the starting address.
                            nn_chunk_ctr       <= nn_layer_nums;          // Get total number of chunks -> has to be more than 3
                            nn_interrupt       <= 1'b0;
                            nn_status          <= 1'b0;

                            NXT_STATE           <= NN_READ1;               
                    end
                    else begin
                            nn_interrupt        <= 1'b0;
                            NXT_STATE           <= INIT;                    // Stay in INIT state
                     end 
            end
            
        // ------------------[  NN_READ1 STATE  ]------------------------------------
        //            
            else if(STATE == NN_READ1) begin
                //debug_1             <= debug_1 | 8'b00000010;
   		 nn_start_read      <= 1'b1;                    // Assert start to BRAM BIU        
                NXT_STATE           <= NN_READ2;
            end
                                      
        // ------------------[  NN_READ2 STATE  ]------------------------------------
        //  waiting for BRAM to read all the data requested

            else if ((STATE == NN_READ2) && (~bram_complete)) begin
                NXT_STATE           <= NN_READ2;               // Loop 
            end       
            
            else if ((STATE == NN_READ2) && (bram_complete)) begin
                //debug_1             <= debug_1 | 8'b00000100;
                nn_start_read      <= 1'b0;                    // Negate start to BRAM BIU    

                if(nn_chunk_ctr == nn_layer_nums) begin //first chunk
                    if(reg_num < `INPUT_NODE_NUM) input_block <= (nn_bram_read_data[15:0] << (`DATA_BIT_NUM*reg_num)) + input_block;
                    else first_weight_block <= (nn_bram_read_data[15:0] << (`DATA_BIT_NUM*(reg_num-`INPUT_NODE_NUM))) + first_weight_block;
                end
                else if(nn_chunk_ctr == 1) begin    //last chunk
                    last_weight_block <= (nn_bram_read_data[15:0] << (`DATA_BIT_NUM*reg_num)) + last_weight_block;
                end
                else begin  // middle chunk
		    if(reg_num == 0) middle_weight_block = nn_bram_read_data[15:0];
                    else  middle_weight_block <= (nn_bram_read_data[15:0] << (`DATA_BIT_NUM*reg_num)) + middle_weight_block;
                end

                NXT_STATE           <= HOLD;               // 
            end         
	    else if(STATE == HOLD) begin
		NXT_STATE <= NN_READ3;

	    end

        // ------------------[  nn_READ3 STATE  ]------------------------------------
        //    
            else if ((STATE == NN_READ3) && (nn_chunk_ctr == nn_layer_nums)) begin
                if(reg_num != (`INPUT_NODE_NUM + (`INPUT_NODE_NUM * `HIDDEN_NODE_NUM))-1) begin
                    reg_num_nxt        <= reg_num + 4'b0001;       // Point at next block_reg
                    nn_bram_addr       <= nn_bram_addr_nxt + 32'h1;  // here
                    nn_start_read      <= 1'b1;                    // Assert start to BRAM BIU
                    NXT_STATE          <= NN_READ1;
		end
		else begin
                    reg_num_nxt         <= 4'b0000;                 // Setup for next fetch
                    NXT_STATE           <= START_NN;               // Start the nn unit
		end
	    end
            else if ((STATE == NN_READ3) && (nn_chunk_ctr == 1)) begin
                if (reg_num != (`OUTPUT_NODE_NUM * `HIDDEN_NODE_NUM-1)) begin
                    reg_num_nxt        <= reg_num + 4'b0001;       // Point at next block_reg
                    nn_bram_addr       <= nn_bram_addr_nxt + 32'h1;  // here
                    nn_start_read      <= 1'b1;                    // Assert start to BRAM BIU
                    NXT_STATE          <= NN_READ1;
		end
		else begin
                    reg_num_nxt         <= 4'b0000;                 // Setup for next fetch
                    NXT_STATE           <= START_NN;               // Start the nn unit
		end

            end
	    else if ((STATE == NN_READ3) && (nn_chunk_ctr < nn_layer_nums) && (nn_chunk_ctr > 1))begin
                if (reg_num != (`HIDDEN_NODE_NUM * `HIDDEN_NODE_NUM-1)) begin
                    reg_num_nxt        <= reg_num + 4'b0001;       // Point at next block_reg
                    nn_bram_addr       <= nn_bram_addr_nxt + 32'h1;  // here
                    nn_start_read      <= 1'b1;                    // Assert start to BRAM BIU
                    NXT_STATE          <= NN_READ1;
		end
		else begin
                    reg_num_nxt         <= 4'b0000;                 // Setup for next fetch
                    NXT_STATE           <= START_NN;               // Start the nn unit
		end
		
	    end
        
        // ------------------[  START_NN STATE  (4) ]------------------------------------

            else if((STATE == START_NN) && (ready == 1'b1))  begin          
                if((middle_chunk_pending == 1'b0) && (last_chunk_pending == 1'b0)) begin // it's the first chunk
                     first_chunk_flag    <= 1'b1;                    
                     middle_chunk_flag  <= 1'b0;
                     last_chunk_flag <= 1'b0;
                end                                             
                else if((middle_chunk_pending == 1'b1) && (last_chunk_pending == 1'b0)) begin // it's the middle chunk
                     first_chunk_flag    <= 1'b0;
                     middle_chunk_flag  <= 1'b1;
                     last_chunk_flag    <= 1'b0;
                end
                else if((middle_chunk_pending == 1'b0) && (last_chunk_pending == 1'b1)) begin // it's the last chunk
                     first_chunk_flag    <= 1'b0;                    
                     middle_chunk_flag  <= 1'b0;
                     last_chunk_flag <= 1'b1;
                end                                                             

                NXT_STATE           <= WAIT1_NN;
            end        

            else if((STATE == START_NN) && (ready == 1'b0)) begin
                NXT_STATE           <= START_NN;
            end        
                
        
        // ------------------[  WAIT1_NN STATE  (5) ]------------------------------------
        //
            else if((STATE == WAIT1_NN) &&(ready == 1'b0)) begin
                NXT_STATE           <= WAIT1_NN;                // Loop until nn is complete
            end        
                    
            else if((STATE == WAIT1_NN) &&(ready == 1'b1)) begin
                first_chunk_flag            <= 1'b0;                    // Finished first chunk
                middle_chunk_flag           <= 1'b0;
                last_chunk_flag            <= 1'b0;
                
                nn_final_output_reg     <= nn_final_output;      
                
                                       
                NXT_STATE           <= WAIT2_NN;              
            end        
           
            else if((STATE == WAIT2_NN) &&(ready == 1'b0)) begin
                NXT_STATE           <= WAIT2_NN;                // Loop until nn is complete
            end        
                    
            else if((STATE == WAIT2_NN) &&(ready == 1'b1)) begin
                first_chunk_flag            <= 1'b0;                    // Finished first chunk
                middle_chunk_flag           <= 1'b0;
                last_chunk_flag            <= 1'b0;
                
                nn_final_output_reg     <= nn_final_output;      
                
                                       
                NXT_STATE           <= LOOP_NN;              
            end        
        // ------------------[  LOOP_NN STATE  ]------------------------------------
        //
            else if((STATE == LOOP_NN) && (nn_chunk_ctr > 32'b10)) begin    // Check if middle chunk left     
                first_chunk_flag         <= 1'b0;
                middle_chunk_pending  <= 1'b1;
                last_chunk_pending  <= 1'b0;
                nn_chunk_ctr       <= nn_chunk_ctr_nxt - 32'h1;   // Decrement # of chunks
                nn_bram_addr       <= nn_bram_addr_nxt + 32'h1;   // here

                NXT_STATE           <= NN_READ1;                   // Loop until complete
            end
            else if((STATE == LOOP_NN) && (nn_chunk_ctr == 32'b10)) begin    // This next chunk is the last chunk    
                first_chunk_flag      <= 1'b0;
                middle_chunk_pending  <= 1'b0;
                last_chunk_pending  <= 1'b1;
                nn_chunk_ctr       <= nn_chunk_ctr_nxt - 32'h1;   // Decrement # of chunks
                nn_bram_addr       <= nn_bram_addr_nxt + 32'h1;   // here

                NXT_STATE           <= NN_READ1;                   // Loop until complete
            end         
             
            else if((STATE == LOOP_NN) && (nn_chunk_ctr == 32'b1)) begin// We are done     
            
                first_chunk_flag         <= 1'b0;
                middle_chunk_pending       <= 1'b0;
                last_chunk_pending  <= 1'b0;
                nn_status          <= 1'b1;
                nn_interrupt       <= 1'b1;
                first_time          <= 1'b0;
                NXT_STATE           <= INIT ;                       // Wait for next conversion
            end        
           
    	end   
    
    end //end for always loop
//------------    UPDATE NEXT STATE   -------------------------------------
//       
    always @(negedge nn_clk or negedge nn_rst_n) 
    begin            
        if ( nn_rst_n  == 1'b0 )      
        begin          
            reg_num             <= 4'b0;
            nn_bram_addr_nxt   <= nn_bram_addr;     
            nn_chunk_ctr_nxt   <= nn_chunk_ctr;   // Chunk counter
            STATE               <= INIT;            // Start in the IDLE STATE waiting for start signal
        end 
             
        else if ( nn_rst_n == 1'b1 ) 
        begin      
            reg_num             <= reg_num_nxt;
            nn_chunk_ctr_nxt    <= nn_chunk_ctr;   // Chunk counter
            nn_bram_addr_nxt    <= nn_bram_addr;
            STATE               <= NXT_STATE;
        end             
     end

// Delay reset 1/2 cycle
//
    always @(posedge nn_clk) 
    begin
        nn_core_rst_n      <= nn_rst_n;
    end

//************************************** 
NN_core NN_CORE (

  .clk(nn_clk),
  .reset_n(nn_rst_n),

  .first_chunk_flag(first_chunk_flag),
  .middle_chunk_flag(middle_chunk_flag),
  .last_chunk_flag(last_chunk_flag),

  .input_block(input_block), //[ (`DATA_BIT_NUM * `INPUT_NODE_NUM)-1 : 0]
  .first_weight_block(first_weight_block), // [ (`DATA_BIT_NUM * `INPUT_NODE_NUM * `HIDDEN_NODE_NUM)-1 : 0]
  .middle_weight_block(middle_weight_block), // [ (`DATA_BIT_NUM * `HIDDEN_NODE_NUM * `HIDDEN_NODE_NUM)-1 : 0]
  .last_weight_block(last_weight_block), // [ (`DATA_BIT_NUM * `HIDDEN_NODE_NUM * `OUTPUT_NODE_NUM)-1 : 0]

  .ready(ready),
  .final_output(nn_final_output)

);
endmodule

