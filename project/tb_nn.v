
module tb;


// BRAM_IF <-> BRAM
    wire [31:0] addr_BRAM;
    wire clk_BRAM;
    wire [`DATA_BIT_NUM-1:0] dout_BRAM;
    wire [`DATA_BIT_NUM-1:0] din_BRAM;
    wire en_BRAM;
    wire rst_BRAM;
    wire [3:0] we_BRAM; 

    // BRAM_IF <-> NN
    wire nn_start_read;
    wire [31:0] nn_bram_addr;
    wire [`DATA_BIT_NUM-1:0] nn_bram_read_data;
    wire bram_complete;

    // signals for testbench
    reg tb_clk;
    reg tb_rst_n;

    // NN
    reg axi_start_nn;
    reg [31:0] nn_layer_nums;
    reg [31:0] nn_bram_addr_start;
 
    wire [`DATA_BIT_NUM * `OUTPUT_NODE_NUM-1 : 0] nn_final_output_reg;;
    wire ready;
    wire nn_digest_valid;
  
    // BRAM_IF
    reg axi_start_read;
    reg axi_start_write;
    reg [31:0] axi_bram_addr;
    reg [`DATA_BIT_NUM-1:0] axi_bram_write_data;
    wire [`DATA_BIT_NUM-1:0] axi_bram_read_data;

//////////////////////////////////////////////////////////////

 	reg tb_ready;

/////////////////////////////////////////////////////////////////
BRAM DUT_BRAM(
      .clk_BRAM(clk_BRAM), 
      .en_BRAM(en_BRAM), 
      .rst_BRAM(rst_BRAM), 
      .we_BRAM(we_BRAM), 
      .addr_BRAM(addr_BRAM), 
      .data_out(din_BRAM), 
      .data_in(dout_BRAM)
);

BRAM_IF DUT_BRAM_IF(

    .axi_start_read(axi_start_read),         
    .axi_start_write(axi_start_write),        
    .axi_clk(tb_clk),
    .axi_rst(tb_rst_n),
    
    .axi_bram_addr(axi_bram_addr),           
    .axi_bram_write_data(axi_bram_write_data),    
    .axi_bram_read_data(axi_bram_read_data),      

    .nn_bram_addr(nn_bram_addr), 
    .nn_bram_read_data(nn_bram_read_data),     
    .nn_start_read(nn_start_read),         
    .bram_complete(bram_complete),         

    .addr_BRAM(addr_BRAM),
    .clk_BRAM(clk_BRAM),           
    .dout_BRAM(dout_BRAM),           
    .din_BRAM(din_BRAM),
    .en_BRAM(en_BRAM),                
    .rst_BRAM(rst_BRAM),            
    .we_BRAM(we_BRAM)                
    );

NN_top DUT_NN_TOP( 
   .nn_clk(tb_clk),           
   .nn_rst_n(tb_rst_n),       
   .axi_start_nn(axi_start_nn),     

   .nn_layer_nums(nn_layer_nums),    
   .nn_bram_addr_start(nn_bram_addr_start),

   .nn_final_output_reg(nn_final_output_reg),
   .nn_status(nn_status),
   .nn_interrupt(nn_interrupt),
   .nn_final_output_valid(nn_final_output_valid),   

   .nn_start_read(nn_start_read),     
   .nn_bram_addr(nn_bram_addr),      

   .nn_bram_read_data(nn_bram_read_data), 
   .bram_complete(bram_complete)       
);
	            

	initial begin
        tb_clk = 0;
        forever #5 tb_clk = ~tb_clk;
    end


    task reset;
    begin

      tb_rst_n = 0; //  rst_BRAM == 1 and sha_rst_n = 0
      #4; 
      tb_rst_n = 1; // reset disabled

    end
    endtask 


//----------------------------------------------------------------
////  wait_ready()
////----------------------------------------------------------------
    task wait_ready;
    begin
       tb_ready = 0;

   while (tb_ready == 0) begin
	#10
	tb_ready = ready;
     end
         end
        endtask


  initial begin
	#10 tb_rst_n = 0;
	#10 tb_rst_n = 1;

	nn_bram_addr_start = 0;
	nn_layer_nums = 32'd4;
	axi_start_nn = 1'b1; 
	axi_start_read = 1'b0;
	axi_start_write = 1'b0;

	wait_ready();



  end
	
endmodule
