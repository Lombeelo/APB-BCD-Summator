`timescale 1ns / 1ns
module bcdSumTB #(
    parameter reglength = 32
) (
    output vrfFail,
    output testDone
);
  logic clk;
  logic resetn;

  logic [reglength-1:0] reg1;
  logic [reglength-1:0] reg2;

  wire [reglength-1:0] sum;
  logic start;
  wire busy;
  wire overflow;

  logic failBit;
  assign vrfFail = failBit;
  logic doneFlag;
  assign testDone = doneFlag;

  bcdAdder #(
      .argWidth(reglength)
  ) bcdInst (
      .clk(clk),
      .resetn(resetn),
      .arg1(reg1),
      .arg2(reg2),
      .result(sum),
      .start(start),
      .busy(busy),
      .overflow(overflow)
  );
  always #1 clk = ~clk;

  initial begin
    clk <= 0;
    start <= 0;
    reg1 <= 0;
    reg2 <= 0;

    resetn <= 0;
    @(posedge clk);
    resetn <= 1;
    @(posedge clk);
    reg1 = 32'h35;
    reg2 = 32'h78;
    $display("%h + %h =", reg1, reg2);
    start <= 1;
    @(posedge clk);
    start <= 0;
    @(negedge busy);
    $display("%h", sum);
    $display("\n");
    if (sum != 32'h113 || overflow != 0) failBit = 1;

    reg1 = 32'h99999999;
    reg2 = 32'h1;
    $display("%h + %h =", reg1, reg2);
    start <= 1;
    @(posedge clk);
    start <= 0;
    @(negedge busy);
    $display("%h", sum);
    $display("\n");
    if (sum != 32'h0 || overflow != 1) failBit = 1;

    reg1 = 32'h23406568;
    reg2 = 32'h79000000;
    $display("%h + %h =", reg1, reg2);
    start <= 1;
    @(posedge clk);
    start <= 0;
    @(negedge busy);
    $display("%h", sum);
    $display("\n");
    @(posedge clk);
    if (sum != 32'h02406568 || overflow != 1) failBit = 1;

    $finish;
  end
  initial begin
    #200 $finish;
  end

  initial begin
    $dumpfile("test.vcd");
    $dumpvars;
  end
endmodule
