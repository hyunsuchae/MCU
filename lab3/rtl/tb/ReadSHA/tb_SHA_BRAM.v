`timescale 10ps/1ps

module tb_SHA_BRAM;

    // BRAM_IF <-> BRAM
    wire [31:0] addr_BRAM;
    wire clk_BRAM;
    wire [31:0] dout_BRAM;
    wire [31:0] din_BRAM;
    wire en_BRAM;
    wire rst_BRAM;
    wire [3:0] we_BRAM; 

    // BRAM_IF <-> SHA256
    wire sha_start_read;
    wire [31:0] sha_bram_addr;
    wire [31:0] sha_bram_read_data;
    wire bram_complete;

    // signals for testbench
    reg tb_clk;
    reg tb_rst_n;

    // SHA256 
    reg axi_start_sha;
    reg [31:0] sha_num_chunks;
    reg [31:0] sha_bram_addr_start;
 
    wire [255:0] sha_digest_reg;
    wire sha_complete;
    wire sha_digest_valid;
  
    // BRAM_IF
    reg axi_start_read;
    reg axi_start_write;
    reg [31:0] axi_bram_addr;
    reg [31:0] axi_bram_write_data;
    wire [31:0] axi_bram_read_data;
 
//////////////////////////////////////////////////////// 
    wire interrupt_out;
    reg tb_sha_complete;

  // starting address of BRAM is TB_ADDR_BRAM
  parameter TB_ADDR_BRAM = 32'h00000000; 

  parameter SHA_SINGLE_TEST_START_ADDR = 32'h00000000; // will read 512 bits from here
  parameter SHA_DOUBLE_TEST_START_ADDR = 32'h00000040; // will read 1024 bits from here

  parameter SHA_SINGLE_EXPECTED_RESULT = 256'hBA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD;
  parameter SHA_DOUBLE_EXPECTED_RESULT_1 = 256'h85E655D6417A17953363376A624CDE5C76E09589CAC5F811CC4B32C1F20E533A;
  parameter SHA_DOUBLE_EXPECTED_RESULT_2 = 256'h248D6A61D20638B8E5C026930C3E6039A33CE45964FF2167F6ECEDD419DB06C1;

////////////////////////////////////////////////////////

    initial begin
        tb_clk = 0;
        forever #1 tb_clk = ~tb_clk;
    end


  //----------------------------------------------------------------
  // reset()
  //----------------------------------------------------------------
    task reset;
    begin

      tb_rst_n = 0; //  rst_BRAM == 1 and sha_rst_n = 0
      #4; 
      tb_rst_n = 1; // reset disabled

    end
    endtask 
 
//----------------------------------------------------------------
//  wait_ready()
//----------------------------------------------------------------
    task wait_ready;
    begin
      tb_sha_complete = 0;

      while (tb_sha_complete == 0) begin
	#2
	tb_sha_complete = sha_complete;
      end
   end
   endtask





  //----------------------------------------------------------------
  // single_block_test()
  //----------------------------------------------------------------
  task single_block_test();
    begin
      $display("*** Single block test started");

      sha_bram_addr_start = SHA_SINGLE_TEST_START_ADDR;
      sha_num_chunks = 32'h1;
      axi_start_sha = 1'b1;

      wait_ready();
  
      if (sha_digest_reg == SHA_SINGLE_EXPECTED_RESULT)
        begin
          $display("SHA256 SINGLE: SUCCESSFUL");
        end
      else
        begin
          $display("SHA256 SINGLE: ERROR");
        end
      $display("***  Single block test done");
    end
  endtask // single_block_test


  //----------------------------------------------------------------
  // double_block_test()
  //----------------------------------------------------------------
  task double_block_test();
    begin
      $display("*** Double block test started");

      sha_bram_addr_start = SHA_DOUBLE_TEST_START_ADDR;
      sha_num_chunks = 32'h2;
      axi_start_sha = 1'b1;

	wait_ready();
 
      if (sha_digest_reg == SHA_DOUBLE_EXPECTED_RESULT_1) begin
          $display("SHA256 DOUBLE first chunk: SUCCESSFUL");
      end
      else begin
          $display("SHA256 DOUBLE first chunk: ERROR");
      end




	wait_ready();

      if (sha_digest_reg == SHA_DOUBLE_EXPECTED_RESULT_2) begin
          $display("SHA256 DOUBLE second chunk: SUCCESSFUL");
      end
      else begin
          $display("SHA256 DOUBLE second chunk: ERROR");
      end


      $display("*** Double block test done");
    end
  endtask // single_block_test

  //----------------------------------------------------------------
  // check_SHA256_BRAM()
  //----------------------------------------------------------------
  task check_SHA256_BRAM;
    begin : sha256_tests_block


      $display("*** Testcases for sha256 functionality started.");
      
      single_block_test();

	#10;
      double_block_test();
	#10


      $display("*** Testcases for sha256 functionality completed.");
    end
  endtask // check_SHA256_BRAM



 initial begin : top_test
      $display("   -- Testbench start --");

      reset();

      $display("*** Test for sha and BRAM transaction");
      
      check_SHA256_BRAM();
  
      $display("   -- Testbench done. --");
      $finish;
  end 


////////////////////////////////////////////////////////////

    SHA256 dut_SHA(
	    .sha_clk(tb_clk),            // NOTE: Same as AXI_CLK
	    .sha_rst_n(tb_rst_n),    // Active LOW
	    .axi_start_sha(axi_start_sha),      // Start signal from control reg
	    .sha_num_chunks(sha_num_chunks),     // # of 512-bit chunks to process
   	    .sha_bram_addr_start(sha_bram_addr_start),// Starting BRAM address of chunk
   	    .sha_digest_reg(sha_digest_reg),
      	    .sha_complete(sha_complete),
            .sha_digest_valid(sha_digest_valid),   // Send to status register           
	        
	    // BRAM_IF <-> SHA 
	    .sha_start_read(sha_start_read),     // Start read transaction 
	    .sha_bram_addr(sha_bram_addr),      // Address to the BRAM         
	    .sha_bram_read_data(sha_bram_read_data),  // BRAM read data to SHA   
            .bram_complete(bram_complete)       

    );

//	assign interrupt_out = sha_complete;

    BRAM dut_BRAM(
      .clk_BRAM(clk_BRAM), 
      .en_BRAM(en_BRAM), 
      .rst_BRAM(rst_BRAM), 
      .we_BRAM(we_BRAM), 
      .addr_BRAM(addr_BRAM), 
      .data_out(din_BRAM), 
      .data_in(dout_BRAM)
    );
                    
	BRAM_IF  dut_BRAM_IF(
		 // BRAM_IF <-> AXI I/F
		.axi_start_read(axi_start_read),         // Start AXI read tansaction
		.axi_start_write(axi_start_write),        // Start AXI write transaction
		.axi_clk(tb_clk),
		.axi_rst(tb_rst_n),

		.axi_bram_addr(axi_bram_addr),          // BRAM Address from the AXI unit
		.axi_bram_write_data(axi_bram_write_data),    // AXI write data to the BRAM
		.axi_bram_read_data(axi_bram_read_data),     // BRAM read data to the AXI unit

		// BRAM_IF <-> SHA
		.sha_bram_addr(sha_bram_addr),          // BRAM Address from the SHA unit
		.sha_bram_read_data(sha_bram_read_data),     // BRAM read data to the SHA unit   
		.sha_start_read(sha_start_read),         // Start SHA read transaction

		.bram_complete(bram_complete),          // BRAM transaction completed

		// BRAM I/F <-> BRAM 
		.addr_BRAM(addr_BRAM),              // Address to the BRAM
		.clk_BRAM(clk_BRAM),               // CLOCK to the BRAM
		.dout_BRAM(dout_BRAM),              // NOTE: This connects to DIN on the BRAM
		.din_BRAM(din_BRAM),               // NOTE: This connects to DOUT on the BRAM
		.en_BRAM(en_BRAM),                // Enable BRAM
		.rst_BRAM(rst_BRAM),               // Reset to the BRAM
		.we_BRAM(we_BRAM)                 // Write Enable to BRAM
    );
  
 
endmodule
