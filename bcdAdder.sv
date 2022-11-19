module bcdAdder #(
    parameter argWidth = 16
) (
    input clk,
    input resetn,
    input [argWidth-1:0] arg1,
    input [argWidth-1:0] arg2,
    input start,
    output wire busy,
    output reg overflow,
    output logic [argWidth-1:0] result
);
  localparam sumCount = argWidth / 4 + 1;
  localparam counterWidth = $clog2(sumCount) + 1;

  bcdDigitAdder bcdDigitAdderInst (
      .a(digit1),
      .b(digit2),
      .p_in(p_in),
      .p_out(p_out),
      .sum(digitRes)
  );

  logic [argWidth-1:0] a;
  logic [argWidth-1:0] b;
  logic p;
  logic busyReg;
  assign busy = busyReg;

  logic [3:0] digit1;
  logic [3:0] digit2;
  wire [3:0] digitRes;
  logic p_in;
  wire p_out;
  logic [counterWidth-1:0] counter;

  always @(posedge clk, negedge resetn) begin
    if (!resetn) begin
      digit1 = 0;
      digit2 = 0;
      p_in = 0;
      result = 0;
      overflow = 0;
      counter = 0;
      busyReg = 0;
    end else begin
      if (start && !busyReg) begin
        busyReg = 1;
        counter = 0;
        p_in = 0;
        p = 0;
        a = arg1;
        b = arg2;
      end
      if (busyReg) begin
        digit1 = a[3:0];
        digit2 = b[3:0];
        result = result >> 4;
        result[argWidth-1:argWidth-4] = digitRes;
        p = p_out;
        overflow = p;
        p_in = p;
        a = a >> 4;
        b = b >> 4;
        counter = counter + 1;
        if (counter == sumCount) busyReg <= 0;
      end
    end
  end
endmodule
