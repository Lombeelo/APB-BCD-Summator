module bcdDigitAdder (
    input [3:0] a,
    input [3:0] b,
    input p_in,
    output p_out,
    output [3:0] sum
);
    logic [4:0] temp;
    assign sum = temp[3:0];
    assign p_out = temp[4];

    always @ ( * )
    begin
        temp = a + b + p_in;
        if (temp > 9)
        begin
            temp = temp + 6;
        end
    end
endmodule