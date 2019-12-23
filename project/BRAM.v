// bram.v


`define memsize 81920

`define BRAMFILE 	"bram.data"

// total # cycles to run


module BRAM(clk_BRAM, en_BRAM, rst_BRAM, we_BRAM, addr_BRAM, data_out, data_in);
  
  input clk_BRAM, en_BRAM, rst_BRAM;
  input [3:0]  we_BRAM;
  input [31:0] 	addr_BRAM; 	
  input [`DATA_BIT_NUM-1:0] 	data_in;
  output [`DATA_BIT_NUM-1:0] data_out;


  reg	[`DATA_BIT_NUM-1:0]	value;

  reg	[`DATA_BIT_NUM-1:0]	mem[0:`memsize];

  initial begin
	$readmemh(`BRAMFILE, mem, 0, `memsize - 1);
  end

  assign data_out = (we_BRAM == 4'b0000) ? value : 16'bz;

// read
  always @(posedge clk_BRAM) begin
  	if((we_BRAM==4'b0000) && en_BRAM && ~rst_BRAM) begin
		value = mem[addr_BRAM];
	end
  end

  always @(posedge clk_BRAM) begin
	if (we_BRAM == 4'b1111)	begin
	  mem[addr_BRAM] = data_in;
	end
  end

endmodule
