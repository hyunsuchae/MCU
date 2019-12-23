`timescale 10ps/1ps

module tb_WriteBRAM;

    // bram i/f module
    reg axi_start_read;
    reg axi_start_write;
    reg [31:0] axi_bram_addr;
    reg [31:0] axi_bram_write_data;
    wire [31:0] axi_bram_read_data;

    wire [31:0] addr_BRAM;
    wire clk_BRAM;
    wire [31:0] dout_BRAM;
    wire [31:0] din_BRAM;
    wire en_BRAM;
    wire rst_BRAM;
    wire [3:0] we_BRAM; 

    wire sha_start_read;
    wire [31:0] sha_bram_addr;
    wire [31:0] sha_bram_read_data;
    wire bram_complete;

    wire interrupt_out;

// signals for testbench
    reg tb_clk;
    reg tb_rst_n;

  parameter TB_ADDR_BRAM = 32'h0004;
  parameter TB_WRITE_VALUE = 32'h99999999;

//////////////////////////////////////////////////// clock generation
    initial begin
        tb_clk = 0;
        forever #1 tb_clk = ~tb_clk;
    end


    task reset;
    begin
      tb_rst_n = 0; //  rst_BRAM == 1

      #4; 
      tb_rst_n = 1; // no more reset
      axi_bram_addr[31:0] = 0;
    end
    endtask 

////////////////////////////////////////////////////////////////////////////////


  task check_axi_write_to_BRAM;
    begin 

      axi_start_read = 0;
      axi_start_write = 1;


      axi_bram_addr[31:0] = TB_ADDR_BRAM; 

      axi_bram_write_data[31:0] = TB_WRITE_VALUE;

	#20;
	// have to check din_BRAM because it starts to read immediately after write

    end
  endtask // check_axi_write_to_BRAM




  initial begin : top_test
    $display("   -- Testbench start --");

      reset();
    $display("*** Test for axi write to BRAM");
    check_axi_write_to_BRAM();
//	#20;
    $display("   -- Testbench done. --");
    $finish;
  end 

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

		 // AXI I/F
		.axi_start_read(axi_start_read),         // Start AXI read tansaction
		.axi_start_write(axi_start_write),        // Start AXI write transaction
		.axi_clk(tb_clk),
		.axi_rst(tb_rst_n),

		.axi_bram_addr(axi_bram_addr),          // BRAM Address from the AXI unit
		.axi_bram_write_data(axi_bram_write_data),    // AXI write data to the BRAM
		.axi_bram_read_data(axi_bram_read_data),     // BRAM read data to the AXI unit

		// SHA I/F
		.sha_bram_addr(sha_bram_addr),          // BRAM Address from the SHA unit
		.sha_bram_read_data(sha_bram_read_data),     // BRAM read data to the SHA unit   
		.sha_start_read(sha_start_read),         // Start SHA read transaction

		.bram_complete(bram_complete),          // BRAM transaction completed

		// BRAM I/F 
		.addr_BRAM(addr_BRAM),              // Address to the BRAM
		.clk_BRAM(clk_BRAM),               // CLOCK to the BRAM
		.dout_BRAM(dout_BRAM),              // NOTE: This connects to DIN on the BRAM
		.din_BRAM(din_BRAM),               // NOTE: This connects to DOUT on the BRAM
		.en_BRAM(en_BRAM),                // Enable BRAM
		.rst_BRAM(rst_BRAM),               // Reset to the BRAM
		.we_BRAM(we_BRAM)                 // Write Enable to BRAM
    );
  
 
endmodule
