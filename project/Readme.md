Testbenches for BRAM_IF and Neural Network  <br/><br/>

Run with vsc by:<br/>
1. module load synopsys/vcs<br/>
2. vcs -full64 -f master -debug<br/>
3. ./simv -gui & <br/><br/>

Each files here:<br/>
1.BRAM.v and bram.data : simple bram for just testing <br/>
2.BRAM_IF.v: bram interface for NN and BRAM <br/>
3. mat_mul_first.v,  mat_mul_next.v, NN_core and NN_top : for NN<br/>
4. tb_nn.v: testing all of these together<br/><br/>

The hierchy of the NN design:<br/>
mat_mul_first & mat_mul_next -> NN_core -> NN_top <br/>
1. mat_mul_first: matrix multiplication of matrix size [1 x INPUT_NODE_NUM ] x [ INPUT_NODE_NUM x HIDDEN_NODE_NUM]<br/>
2.mat_mul_next: matrix multiplication of matrix size [1 x HIDDEN_NODE_NUM ] x [ HIDDEN_NODE_NUM x HIDDEN_NODE_NUM] OR  [1 x HIDDEN_NODE_NUM ] x [ HIDDEN_NODE_NUM x OUTPUT_NODE_NUM] <br/>
-> mat_mul_first and mat_mul_next is the same thing inside...<br/>
3. NN_core: doing matrix multiplication for each layers<br/>
4. NN_top: getting data from BRAM_IF and controlling everything for NN<br/>
Compared to Lab3, you can think of NN_core.v as sha256_core.v and NN_top.v as sha256.v <br/><br/>


BEFORE GENERATING BITSTREAM, TODO: <br/>
1. discuss on what the length of each data (input, weight, output) is going to be <br/>
currently it's 16bit (MSB is for sign and the rest is for number) and it's from BRAM -> it's not a floating point cacluation.   <br/>
2. edit parts that are commented  " here" regarding the length of data we choose and BRAM size<br/>
3. change the defined variable numbers for our design<br/><br/>


I made tb to test the multiple layers of matrix multiplications<br/>
the testcase right now is (in decimal representation, but it's actually in hex in bram.data), <br/>
INPUT: [3 2]<br/>
W0: [1 2 7 3],[-8, -1, -2, 9], [6, 8, -1, -10], [7, 3, 2, 8]]<br/>
W1: [[-3, -1, 2, -9], [-2, -3, 8, 6], [5, 5, -2, 8],[-6, 4, 4, -4]]<br/>
W2:[3, 7, -4, 5, -3], [-2, 1, 2, -1, -3],[-1, 5, -3, 2, 3], [-5, 3, 1, -2, 6]]<br/>
and the output in hex will be [0, x3791, 0, x09ea, x3180]<br/>
output is the port "nn_final_output_reg" of NN_top.v, and this value is  valid when nn_interrupt== 1<br/><br/>

The input to NN_top.v from axi is: nn_clk, nn_rst_n, axi_start_nn, nn_layer_nums, nn_bram_address_start<br/>
The input to NN_top.v from bram is: nn_bram_data, bram_complete<br/>
Every port means the same thing as LAB3 except that the name changed from sha to nn for all of them.<br/>
Except nn_layer_nums. THis should be the number of total layer we are going to have.<br/><br/>

For this verilog code, make sure we have more than 3 layers total!!!!!!!!! <br/>
One for input, one for final output, and at least one for the hidden layer <br/>
