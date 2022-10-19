module summator #(
    parameter summatorBaseAddr = 0,
    parameter addrWidth = 32,
    parameter dataWidth = 32
) (
    input aps_psel,
    input aps_penable,
    input reset_n,
    input clk,
    input aps_pwrite,
    input logic [addrWidth-1:0] aps_paddr,
    input logic [dataWidth-1:0] aps_pwdata,
    output logic [dataWidth-1:0] aps_prdata,
    output logic aps_pready,
    output logic aps_pslverr
);

  localparam STATE_IDLE = 0;
  localparam STATE_SETUP = 1;
  localparam STATE_WRITE = 2;
  localparam STATE_READ = 3;

  localparam SUM_ARG_LEN = dataWidth / 8;

  localparam SUM_ARG1_ADDR = summatorBaseAddr;
  localparam SUM_ARG2_ADDR = SUM_ARG1_ADDR + SUM_ARG_LEN;
  localparam SUM_RES_ADDR = SUM_ARG2_ADDR + SUM_ARG_LEN;
  localparam SUM_STATUS_ADDR = SUM_RES_ADDR + SUM_ARG_LEN;

  logic [1:0] apb_state;

  logic [dataWidth-1:0] arg1;
  logic [dataWidth-1:0] arg2;
  logic [dataWidth-1:0] result;
  logic executing_flag;
  logic execute_queried_flag;
  logic overflow_flag;

  bcdAdder #(
      .argWidth(dataWidth)
  ) adderInst (
      .clk(clk),
      .resetn(reset_n),
      .arg1(arg1),
      .arg2(arg2),
      .start(execute_queried_flag),
      .busy(executing_flag),
      .overflow(overflow_flag),
      .result(result)
  );

  always @(posedge clk) begin
    if (!reset_n) begin
      apb_state <= STATE_IDLE;
      arg1 <= 0;
      arg2 <= 0;
      execute_queried_flag <= 0;
      aps_pslverr <= 0;
    end else begin
      execute_queried_flag = execute_queried_flag & executing_flag;

      if (aps_paddr >= summatorBaseAddr && aps_paddr <= SUM_STATUS_ADDR) begin
        case (apb_state)
          STATE_IDLE: begin
            aps_prdata  <= 0;
            aps_pready  <= 0;
            aps_pslverr <= 0;
            if (aps_psel) apb_state <= STATE_SETUP;
          end
          STATE_SETUP: begin
            if (aps_psel && aps_penable) begin
              if (aps_pwrite) begin
                apb_state <= STATE_WRITE;
              end else begin
                apb_state <= STATE_READ;
              end
            end
          end
          STATE_WRITE: begin
            aps_pready <= 1;
            if (aps_psel && aps_penable) begin
              if (executing_flag & ~aps_pready) begin
                aps_pslverr <= 1;
              end else begin
                if (aps_paddr >= SUM_ARG1_ADDR && aps_paddr < SUM_ARG2_ADDR) begin
                  arg1 <= aps_pwdata;
                end else if (aps_paddr >= SUM_ARG2_ADDR && aps_paddr < SUM_RES_ADDR) begin
                  arg2 <= aps_pwdata;
                end else if (aps_paddr == SUM_STATUS_ADDR) begin
                  execute_queried_flag = aps_pwdata[0];
                end
              end
            end else apb_state <= STATE_IDLE;
          end
          // READ
          STATE_READ: begin
            aps_pready <= 1;
            if (aps_psel && aps_penable) begin
              if (executing_flag & ~aps_pready) begin
                aps_pslverr <= 1;
              end else begin
                if (aps_paddr >= SUM_RES_ADDR && aps_paddr < SUM_STATUS_ADDR) begin
                  aps_prdata <= result;
                end else if (aps_paddr == SUM_STATUS_ADDR) begin
                  aps_prdata <= overflow_flag;
                end
              end
            end else apb_state <= STATE_IDLE;
          end
          default: begin
            apb_state <= STATE_IDLE;
          end
        endcase
      end
    end
  end

endmodule
