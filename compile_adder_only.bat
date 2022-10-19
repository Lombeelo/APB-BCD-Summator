c:/iverilog/bin/iverilog.exe -o result -g2005-sv bcdDigitAdder.sv bcdAdder.sv bcdSumTB.sv
c:/iverilog/bin/vvp.exe result -lxt2
C:\iverilog\gtkwave\bin\gtkwave.exe test.vcd
del result test.vcd