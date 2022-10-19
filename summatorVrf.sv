module timerVrf (
    output vrfFail
);
  localparam addrWidth = 32;
  localparam dataWidth = 32;

  localparam summatorBaseAddr = 0;
  localparam SUM_ARG_LEN = dataWidth / 8;

  localparam SUM_ARG1_ADDR = summatorBaseAddr;
  localparam SUM_ARG2_ADDR = SUM_ARG1_ADDR + SUM_ARG_LEN;
  localparam SUM_RES_ADDR = SUM_ARG2_ADDR + SUM_ARG_LEN;
  localparam SUM_STATUS_ADDR = SUM_RES_ADDR + SUM_ARG_LEN;

  logic clk = 0;
  always #1 clk = ~clk;

  logic [addrWidth-1:0] paddr;
  logic pwrite;
  logic psel;
  logic penable;
  logic [dataWidth-1:0] pwdata;
  logic [dataWidth-1:0] prdata;
  logic pready;
  logic pslverr;
  logic presetn;

  logic [dataWidth-1:0] dataBuf;
  logic errBuf;

  logic failBit;
  assign vrfFail = failBit;

  summator #(
      .summatorBaseAddr(summatorBaseAddr),
      .addrWidth(addrWidth),
      .dataWidth(dataWidth)
  ) sumInst (
      .aps_psel(psel),
      .aps_penable(penable),
      .reset_n(presetn),
      .clk(clk),
      .aps_pwrite(pwrite),
      .aps_paddr(paddr),
      .aps_pwdata(pwdata),
      .aps_prdata(prdata),
      .aps_pready(pready),
      .aps_pslverr(pslverr)
  );

  // Enum to achieve more verbosity in task call
  typedef enum {
    READ,
    WRITE
  } e_rw;
  // Basic funciton for exchanging data using APB
  task exchangeData(input e_rw exchMode, input logic [addrWidth-1:0] deviceAddr,
                    inout logic [dataWidth-1:0] data, output logic err);
    begin
      // IDLE -> SETUP
      paddr  <= deviceAddr;
      psel   <= 1;
      pwrite <= exchMode;
      if (exchMode == WRITE) pwdata <= data;
      @(posedge clk);
      // SETUP -> ACCESS
      penable <= 1;
      @(posedge clk);

      while (!pready) @(posedge clk);
      // ACCESS -> IDLE
      if (exchMode == READ) data <= prdata;
      err <= pslverr;
      penable <= 0;
      psel <= 0;
      @(posedge clk);
    end
  endtask

  // Modified exchangeData to properly test a wrong address IO
  task exchangeDataNoWait(input e_rw exchMode, input logic [addrWidth-1:0] deviceAddr,
                          inout logic [dataWidth-1:0] data, output logic err);
    begin
      // IDLE -> SETUP
      paddr  <= deviceAddr;
      psel   <= 1;
      pwrite <= exchMode;
      if (exchMode == WRITE) pwdata <= data;
      @(posedge clk);
      // SETUP -> ACCESS
      penable <= 1;
      @(posedge clk);

      repeat (2) @(posedge clk);
      // ACCESS -> IDLE
      if (exchMode == READ) data <= prdata;
      err <= pslverr;
      penable <= 0;
      psel <= 0;
      repeat (2) @(posedge clk);
    end
  endtask

  // Modified exchangeData to test wrong usage of APB
  task exchangeDataNoPSEL(input e_rw exchMode, input logic [addrWidth-1:0] deviceAddr,
                          inout logic [dataWidth-1:0] data, output logic err);
    begin
      // IDLE -> SETUP
      paddr  <= deviceAddr;
      psel   <= 0;
      pwrite <= exchMode;
      if (exchMode == WRITE) pwdata <= data;
      @(posedge clk);
      // SETUP -> ACCESS
      penable <= 1;
      @(posedge clk);

      repeat (2) @(posedge clk);
      // ACCESS -> IDLE
      if (exchMode == READ) data <= prdata;
      err <= pslverr;
      penable <= 0;
      psel <= 0;
      repeat (2) @(posedge clk);
    end
  endtask

  // Resetting the module and setting up initial conditions
  initial begin
    presetn <= 0;
    pwdata <= 0;
    pwrite <= 0;
    dataBuf <= 0;
    errBuf <= 0;
    penable <= 0;
    psel <= 0;
    paddr <= 0;
    failBit <= 0;
    #10;
    presetn <= 1;
    @(posedge clk);

    // TEST 1: write + read on wrong addr
    // There should be no reaction
    exchangeDataNoWait(WRITE, 32'hff00_0000, dataBuf, errBuf);
    // There should be no reaction
    exchangeDataNoWait(READ, 32'hff00_0000, dataBuf, errBuf);
    $display("1. Wrong address write + read. No reaction? %d", dataBuf == 0);
    if (dataBuf != 0) failBit = 1;


    // TEST 2: write + read without psel
    // There should be no reaction
    exchangeDataNoPSEL(WRITE, SUM_STATUS_ADDR, dataBuf, errBuf);
    // There should be no reaction
    exchangeDataNoPSEL(READ, SUM_STATUS_ADDR, dataBuf, errBuf);
    $display("2. Operations without psel. No reaction? %d", dataBuf == 0);
    if (dataBuf != 0) failBit = 1;

    // TEST 3: test summator on a simple sum
    dataBuf <= 32'h25;
    @(posedge clk);
    exchangeData(WRITE, SUM_ARG1_ADDR, dataBuf, errBuf);

    dataBuf <= 32'h30;
    @(posedge clk);
    exchangeData(WRITE, SUM_ARG2_ADDR, dataBuf, errBuf);

    dataBuf <= 32'h1;
    @(posedge clk);
    exchangeData(WRITE, SUM_STATUS_ADDR, dataBuf, errBuf);

    //wait until summator completes
    repeat (5) @(posedge clk);

    exchangeData(READ, SUM_RES_ADDR, dataBuf, errBuf);
    $display("3. Getting simple sum result. sum == 32'h55? %d", dataBuf == 32'h55);
    if (dataBuf != 32'h55) failBit = 1;

    exchangeData(READ, SUM_STATUS_ADDR, dataBuf, errBuf);
    $display("4. Getting simple sum overflow flag. overflow == 0? %d", dataBuf == 0);
    if (dataBuf != 0) failBit = 1;

    // TEST 4: trying to read before summation completes
    dataBuf <= 32'h1;
    @(posedge clk);
    exchangeData(WRITE, SUM_STATUS_ADDR, dataBuf, errBuf);

    exchangeData(READ, SUM_RES_ADDR, dataBuf, errBuf);
    $display("5. Reading values too early, errBuf == %d", errBuf);
    if (errBuf != 1) failBit = 1;

    // TEST 5: test summator when overflow occurs
    dataBuf <= 32'h60_308_002;
    @(posedge clk);
    exchangeData(WRITE, SUM_ARG1_ADDR, dataBuf, errBuf);

    dataBuf <= 32'h51_406_555;
    @(posedge clk);
    exchangeData(WRITE, SUM_ARG2_ADDR, dataBuf, errBuf);

    dataBuf <= 32'h1;
    @(posedge clk);
    exchangeData(WRITE, SUM_STATUS_ADDR, dataBuf, errBuf);

    //wait until summator completes
    repeat (5) @(posedge clk);

    //32'h60_308_002 + 32'h51_406_555 = 32'h1_11_714_557 (overflow)
    exchangeData(READ, SUM_RES_ADDR, dataBuf, errBuf);
    $display("6. Getting overflow sum result. sum == 32'h11_714_557? %d",
             dataBuf == 32'h11_714_557);
    if (dataBuf != 32'h11_714_557) failBit = 1;

    exchangeData(READ, SUM_STATUS_ADDR, dataBuf, errBuf);
    $display("7. Getting overflow sum overflow flag. overflow == 1? %d", dataBuf == 1);
    if (dataBuf != 1) failBit = 1;

    $finish();
  end

  initial begin
    $dumpfile("test.vcd");
    $dumpvars(0, timerVrf);
  end
endmodule
