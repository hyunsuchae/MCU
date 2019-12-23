`timescale 1 ns / 1 ps

//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    07/24/2018
// Design Name: 
// Module Name:    sha256.v
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is top level of the SHA256 HW accelerator for the Zedboard
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// 
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SHA256 (
	       // DEBUG
	       //    output       [31:0]     sha_status,         
	       
	       // AXI I/F Signals  
	           input   wire            sha_clk,            // NOTE: Same as AXI_CLK
	           input   wire            sha_rst_n,          // Active LOW
	           input   wire            axi_start_sha,      // Start signal from control reg
	           input   wire [31:0]     sha_num_chunks,     // # of 512-bit chunks to process
   	           input   wire [31:0]     sha_bram_addr_start,// Starting BRAM address of chunk
   	           output  reg  [255:0]    sha_digest_reg,
               output  reg             sha_complete,
               output  wire            sha_digest_valid,   // Send to status register - Jim: Not connect ROLF      
	        
	       // BRAM I/F Signals   
	           output  reg             sha_start_read,     // Start read transaction 
	           output  reg  [31:0]     sha_bram_addr,      // Address to the BRAM         
	           input   wire [31:0]     sha_bram_read_data  // BRAM read data to SHA
               
               input   wire            bram_complete,       // JIM: Should be with BRAM Signals
	           );
	            



// --------------------[  WIRES and REGISTERS  ]-----------------------------------
//              

wire            sha_mode = 1'b1;                // Hardcode 256-bit mode
wire            sha_idle;                       // Ready signal from the SHA core
wire [255:0]    sha_digest;                     // SHA256 output
reg             first_chunk;                    // Flag to indicate first chunk
reg             next_chunk;                     // Flag to indicate next chunk
reg             next_chunk_pending;             // 
reg             sha_data_valid;                 // Start flag to SHA unit
reg             sha_core_rst_n;                 // 1/2 cycle delay

reg [31:0]      sha_chunk_ctr;                  // Chunk counter
reg [31:0]      sha_chunk_ctr_nxt;              // Chunk counter

reg [31:0]      sha_bram_addr_nxt;              // Address counter
reg [3:0]       STATE;
reg [3:0]       NXT_STATE;   

reg [31:0]      block_reg [0:15];               // Sixteen 32 bit registers



// ------------------------------------------------------------------------
//    Storage for 512-bit data from the BRAM
//
wire [511:0]    sha_data_512; 

assign sha_data_512 = {block_reg[00], block_reg[01], block_reg[02], block_reg[03],
                       block_reg[04], block_reg[05], block_reg[06], block_reg[07],
                       block_reg[08], block_reg[09], block_reg[10], block_reg[11],
                       block_reg[12], block_reg[13], block_reg[14], block_reg[15]};

// Use this chunk for debug:
/*
assign sha_data_512 = {32'h6162630a, 32'h80000000, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 
                       32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0020};
*/



// --------------------------------------------------------------------
//  SHA Conversion Control State Machine Parameters
//

localparam  
        INIT        = 8,
        SHA_READ1   = 1,
        SHA_READ2   = 2,
        SHA_READ3   = 3,        
        START_SHA   = 4,
        WAIT_SHA    = 5,
        LOOP_SHA    = 6,       
        HOLD        = 7;    // Not used
            
            
// ------------------------------------------------------------------------
// This State Machine fetches the 512 bit chunks from the BRAM and sends it to 
// the SHA256 core. It then starts the conversion and waits for the result.
//
    reg [3:0]       reg_num;
    reg [3:0]       reg_num_nxt;
    reg [7:0]       debug_1;
    
    
    always @( posedge sha_clk or negedge sha_rst_n)   
    begin : reg_reset
    integer i;  
        if ( sha_rst_n == 1'b0 )                // In RESET
        begin
            
            block_reg[0]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[1]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[2]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[3]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[4]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[5]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[6]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[7]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[8]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[9]        <= 32'h0;       // Clear out the 512-bit memory
            block_reg[10]       <= 32'h0;       // Clear out the 512-bit memory
            block_reg[11]       <= 32'h0;       // Clear out the 512-bit memory
            block_reg[12]       <= 32'h0;       // Clear out the 512-bit memory
            block_reg[13]       <= 32'h0;       // Clear out the 512-bit memory
            block_reg[14]       <= 32'h0;       // Clear out the 512-bit memory
            block_reg[15]       <= 32'h0;       // Clear out the 512-bit memory
            first_chunk         <=  1'b1;       // Start with the first chunk 
            next_chunk          <=  1'b0;       // Followed by the next one, etc.
            next_chunk_pending  <=  1'b0;       
            sha_chunk_ctr       <= 32'h0;
            sha_bram_addr       <= 32'h0;      
            sha_data_valid      <=  1'b0;       // Start signal to SHA unit
            reg_num_nxt         <=  4'b0;       // 16 byte counter for each chunk
            sha_start_read      <=  1'b0;       // Control 
            sha_complete        <=  1'b0;
            
            sha_digest_reg      <= 256'hFEEDBEEFDEADBEEF0123456789ABCDEF0123456789ABCDEF;   // Debug
            NXT_STATE           <= INIT;
        end
            
        else if ( sha_rst_n == 1'b1 )           // Out of RESET start State Machine
        begin        
        
        // ------------------[    INIT STATE  ]--------------------------------------   
        //
            if ((STATE == INIT) && 
                (axi_start_sha == 1'b1)) 
            begin
                sha_bram_addr       <= sha_bram_addr_start;     // Get the starting address.
                sha_chunk_ctr       <= sha_num_chunks;          // Get total number of chunks
                sha_complete        <= 1'b0;

                NXT_STATE           <= SHA_READ1;               // Next State = SHA READ
            end            
            
            else if ((STATE == INIT) && 
                     (axi_start_sha == 1'b0)) 
            begin
                NXT_STATE           <= INIT;                    // Stay in INIT state
            end
            
        // ------------------[  SHA_READ1 STATE  ]------------------------------------
        //            
            else if(STATE == SHA_READ1) 
            begin
                //debug_1             <= debug_1 | 8'b00000010;
                sha_start_read      <= 1'b1;                    // Assert start to BRAM BIU        
                NXT_STATE           <= SHA_READ2;
            end
                                      
        // ------------------[  SHA_READ2 STATE  ]------------------------------------
        //                 
            else if ((STATE == SHA_READ2) && 
                     (~bram_complete))
            begin
                NXT_STATE           <= SHA_READ2;               // Loop 
            end       
            
            else if ((STATE == SHA_READ2) && 
                     (bram_complete))
            begin
                //debug_1             <= debug_1 | 8'b00000100;
                sha_start_read      <= 1'b0;                    // Negate start to BRAM BIU        
                block_reg[reg_num]  <= sha_bram_read_data;      // Write the read data to the buffer
                NXT_STATE           <= SHA_READ3;               // 
            end         

        // ------------------[  SHA_READ3 STATE  ]------------------------------------
        //    
            else if ((STATE == SHA_READ3) && 
                     (reg_num[3:0] == 4'b1111))                 // 16 bytes read
            begin
               // debug_1             <= debug_1 | 8'b00001000;
                reg_num_nxt         <= 4'b0000;                 // Setup for next 512-bit fetch
                NXT_STATE           <= START_SHA;               // Start the SHA unit
            end
                
            else if ((STATE == SHA_READ3) && 
                     (reg_num[3:0] != 4'b1111))                 // Loop back for next word
            begin
                //debug_1             <= debug_1 | 8'b10000000;
                reg_num_nxt         <= reg_num + 4'b0001;       // Point at next block_reg
                sha_bram_addr       <= sha_bram_addr_nxt + 32'h4;  // Add 4 bytes to address
                sha_start_read      <= 1'b1;                    // Assert start to BRAM BIU
                NXT_STATE           <= SHA_READ1;
            end                                                       
        
        // ------------------[  START_SHA STATE  ]------------------------------------
        //
            else if((STATE == START_SHA) &&
                    (sha_idle == 1'b1))          
            begin
                //debug_1             <= debug_1 | 8'b00010000;
                
                if(next_chunk_pending == 1'b0)                  // Check if another chunk
                begin 
                     first_chunk    <= 1'b1;                    // Set first chunk
                end                                             
                else if(next_chunk_pending == 1'b1)
                     first_chunk    <= 1'b0;
                     next_chunk     <= 1'b1;
                
                NXT_STATE           <= WAIT_SHA;
            end        

            else if((STATE == START_SHA) &&
                    (sha_idle == 1'b0))          
            begin
                NXT_STATE           <= START_SHA;
            end        
                
        
        // ------------------[  WAIT_SHA STATE  ]------------------------------------
        //
            else if((STATE == WAIT_SHA) &&
                    (sha_idle == 1'b0))            
            begin
                NXT_STATE           <= WAIT_SHA;                // Loop until SHA is complete
            end        
                    
            else if((STATE == WAIT_SHA) &&
                    (sha_idle == 1'b1))            
            begin
                //debug_1             <= debug_1 | 8'b00100000;
                first_chunk         <= 1'b0;                    // Finished first chunk
                next_chunk          <= 1'b0;
                
                sha_digest_reg      <= sha_digest[255:0];      
                
                                       
                NXT_STATE           <= LOOP_SHA;              
            end        
           
        // ------------------[  LOOP_SHA STATE  ]------------------------------------
        //
            else if((STATE == LOOP_SHA) &&
                    (sha_chunk_ctr > 32'b1))                        // Check if more than 1 chunk    
            begin
                
                first_chunk         <= 1'b0;
                next_chunk_pending  <= 1'b1;
                sha_chunk_ctr       <= sha_chunk_ctr_nxt - 32'h1;   // Decrement # of chunks
                sha_bram_addr       <= sha_bram_addr_nxt + 32'h4;   // Add 4 bytes
                //debug_1             <= 8'b0;                        // Reset Debug counter  <<<<<<<<<<<<<<<
                NXT_STATE           <= SHA_READ1;                   // Loop until complete
            end        
             
            else if((STATE == LOOP_SHA) &&
                      (sha_chunk_ctr == 32'b1))                     // We are done     
            begin
                //debug_1             <= debug_1 | 8'b01000000;       // <<<<<<<<<<<<<<<<<<<<
                first_chunk         <= 1'b0;
                next_chunk          <= 1'b0;
                next_chunk_pending  <= 1'b0;
                sha_complete        <= 1'b1;
                
                //sha_digest_reg      <= {block_reg[00], block_reg[01], block_reg[02], block_reg[03],
                //                        block_reg[04], block_reg[05], block_reg[06], block_reg[15]};
               
                NXT_STATE           <= INIT ;                       // Wait for next conversion
            end        
           
        end    
    end   
    

//------------    UPDATE NEXT STATE   -------------------------------------
//       
    always @(negedge sha_clk or negedge sha_rst_n) 
    begin            
        if ( sha_rst_n  == 1'b0 )      
        begin          
            reg_num             <= 4'b0;
            sha_bram_addr_nxt   <= sha_bram_addr;     
            sha_chunk_ctr_nxt   <= sha_chunk_ctr;   // Chunk counter
            STATE               <= INIT;            // Start in the IDLE STATE waiting for start signal
        end 
             
        else if ( sha_rst_n == 1'b1 ) 
        begin      
            reg_num             <= reg_num_nxt;
            sha_chunk_ctr_nxt   <= sha_chunk_ctr;   // Chunk counter
            sha_bram_addr_nxt   <= sha_bram_addr;
            STATE               <= NXT_STATE;
        end             
     end

// Delay reset 1/2 cycle
//
    always @(posedge sha_clk) 
    begin
        sha_core_rst_n      <= sha_rst_n;
    end

//************************************** 
//INSTANTIATE THE SHA256 CORE MODULE OBTAINED FROM THE GITHUB LINK WITH CORRECT PORT MAPPINGS
sha256_core sha256_core_inst(
                sha_clk, //clk
                sha_rst_n, //reset_n

                first_chunk, //init,
                next_chunk, //next,
                sha_mode, //done

                sha_data_512, //block

                sha_idle, //ready,
                sha_digest, //digest,
                sha_digest_valid //digest_valid
                );
	            
// --------------------[  DEBUG PORTS  ]-----------------------------------
// NOT NEEDED FOR NOW!
endmodule

