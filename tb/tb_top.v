`timescale 1ns/1ps
`include "../rtl/tea_cpu.v"
module tb_top;
    reg clk=1'b1;
    reg rst=1'b1;
    wire [4:0] io_addr;
    wire        io_rd;
    wire        io_wr;
    reg [7:0]   io_rddata;
    wire [7:0]  io_wrdata;
    wire [9:0]  instr_addr;
    reg [8:0]  instr;
    reg [8:0]   instr_rom[1023:0];

    always@(posedge clk)begin
        instr<=instr_rom[instr_addr];
    end
    initial forever begin
        clk<= 1'b1;#5;
        clk<= 1'b0;#5;
    end
    initial begin
        rst<=1'b1;
        repeat(10) @(posedge clk);
        #2;
        rst<=1'b0;
    end
    tea_cpu #(.PC_WIDTH(10),.REGFILE_SIZE_WIDTH(5))
    uut(
        .clk(clk),
        .rst(rst),
        .io_addr(io_addr),
        .io_rd(io_rd),
        .io_wr(io_wr),
        .io_rddata(io_rddata),
        .io_wrdata(io_wrdata),
        .instr_addr(instr_addr),
        .instr(instr)
    );
    initial begin
        #10_000;
        $finish();
    end
endmodule
