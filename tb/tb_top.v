`timescale 1ns/1ps
`define SIM
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
    reg [8:0]   rom[1023:0];
    reg tea_req=1'b1;
    reg       tea_done=1'b0;
    reg [7:0] tea_r0;
    reg [7:0] tea_r1;
    reg [7:0] tea_r2;
    reg [7:0] tea_r3;
    reg [7:0] tea_r4;
    reg [7:0] tea_r5;
    reg [7:0] tea_r6;
    reg [7:0] tea_r7;
    always@(posedge clk)begin
        instr<=rom[instr_addr];
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

    always@(*)begin
        io_rddata<=8'h0;
        case(io_addr)
            5'h0:io_rddata<= 8'h12;
            5'h1:io_rddata<= 8'h34;
            5'h2:io_rddata<= 8'h56;
            5'h3:io_rddata<= 8'h78;
            5'h4:io_rddata<= 8'h11;
            5'h5:io_rddata<= 8'h22;
            5'h6:io_rddata<= 8'h33;
            5'h7:io_rddata<= 8'h44;
            5'h1F:io_rddata<= tea_req;
        endcase
    end

    initial begin
        @(negedge rst);
        repeat(50)  @(posedge clk);
        tea_req=1'b0;
        @(posedge tea_done);
        repeat(10)  @(posedge clk);
        $finish();
    end
    initial begin
        $fsdbDumpvars();
        #120_000;
        $finish();
    end
    integer i=0;
    integer j=0;
    localparam K0=32'h11_12_13_14;
    localparam K1=32'h21_22_23_24;
    localparam K2=32'h31_32_33_34;
    localparam K3=32'h41_42_43_44;
    localparam DELTA=32'h9E3779B9;

    reg [31:0] v0=32'h78563412;
    reg [31:0] v1=32'h44332211;
    reg [31:0] sum=32'h0;
    task tea_loop;
        begin
            sum=sum+DELTA;
            v0 = v0 + (((v1<<4) + K0) ^ (v1 + sum) ^ ((v1>>5) + K1));
            v1 = v1 + (((v0<<4) + K2) ^ (v0 + sum) ^ ((v0>>5) + K3));
        end
    endtask

    always@(posedge clk)begin
        if(io_wr)begin
            case(io_addr)
                5'h0:tea_r0 <= io_wrdata;
                5'h1:tea_r1 <= io_wrdata;
                5'h2:tea_r2 <= io_wrdata;
                5'h3:tea_r3 <= io_wrdata;
                5'h4:tea_r4 <= io_wrdata;
                5'h5:tea_r5 <= io_wrdata;
                5'h6:tea_r6 <= io_wrdata;
                5'h7:tea_r7 <= io_wrdata;
                5'h1F: tea_done<= io_wrdata[0];
                5'h1e:begin
                    $display("RTL:%h%h%h%h %h%h%h%h %h%h%h%h %h",
                        uut.u_reg.mem[3],uut.u_reg.mem[2],uut.u_reg.mem[1],uut.u_reg.mem[0],    //v0
                        uut.u_reg.mem[3+4],uut.u_reg.mem[2+4],uut.u_reg.mem[1+4],uut.u_reg.mem[0+4], // v1
                        uut.u_reg.mem[3+8],uut.u_reg.mem[2+8],uut.u_reg.mem[1+8],uut.u_reg.mem[0+8], // sum
                        uut.u_reg.mem[20]
                    );
                    tea_loop;
                    $display("TB :%h %h %h ",v0,v1,sum);
                end
            endcase
        end
    end

    function [31:0] sel_k;
        input [1:0]k_sel;
        begin
            case(k_sel)
                2'h0:sel_k=K0;
                2'h1:sel_k=K1;
                2'h2:sel_k=K2;
                2'h3:sel_k=K3;
            endcase
        end
    endfunction

    task clr_c;
        begin
            rom[i] = 9'hf4; i=i+1;   // clr_c
        end
    endtask

    task  v_add_sum;
        input [4:0] offset_in;
        input [4:0] offset_out;
        begin
            clr_c;
            for(j=0;j<4;j=j+1) begin
                rom[i] = 9'ha0+offset_in+j;i=i+1; // acc = @offset_in
                rom[i] = 9'h0_08+j;i=i+1;  // acc <= acc+ sum08
                rom[i] = 9'h0_80+offset_out+j;i=i+1;  // reg08 <= acc
            end
        end
    endtask

    task  sr5;
        input [4:0] offset_in;
        input [4:0] offset_out;
        begin
        end
    endtask

    task  sl4;
        input [4:0] offset_in;
        input [4:0] offset_out;
        begin
            clr_c;
            
        end
    endtask

    task  xor_reg;
        input [4:0] offset_in;
        input [4:0] offset_2;
        input [4:0] offset_out;
        begin
            
            for(j=0;j<4;j=j+1) begin
                rom[i] = 9'ha0+offset_in+j;i=i+1; // acc = @offset_in
                rom[i] = 9'h0_C0+offset_2+j;i=i+1;  // acc <= acc+ sum08
                rom[i] = 9'h0_80+offset_out+j;i=i+1;  // reg08 <= acc
            end
        end
    endtask
    task  add_reg;
        input [4:0] offset_in;
        input [4:0] offset_2;
        input [4:0] offset_out;
        begin
            clr_c;
            for(j=0;j<4;j=j+1) begin
                rom[i] = 9'ha0+offset_in+j;i=i+1; // acc = @offset_in
                rom[i] = 9'h0_00+offset_2+j;i=i+1;  // acc <= acc+ sum08
                rom[i] = 9'h0_80+offset_out+j;i=i+1;  // reg08 <= acc
            end
        end
    endtask

    task  add_const;
        input [4:0] offset_in;
        input [31:0] v;
        input [4:0] offset_out;
        begin
            clr_c;
            for(j=0;j<4;j=j+1) begin
                rom[i] = {1'b1,v[j*8+:8]};i=i+1;  // acc <= imm
                rom[i] = 9'h0_0+offset_in+j;i=i+1;  // acc <= acc+ reg
                rom[i] = 9'h0_80+offset_out+j;i=i+1;  // reg <= acc
            end
        end
    endtask
    task  trig_debug;
        begin
            rom[i]=9'he4; i=i+1; // io req
            rom[i]={1'b0,3'h4,5'h1e};i=i+1;// write 1e
        end
    endtask
    integer reloop_label;

    initial begin
        i=0;
        // 反复读取状态，等待有一个请求
        rom[i]=9'he4; i=i+1; // io req
        rom[i]=9'ha0+9'h1f;i=i+1;// read from io
        rom[i]=9'hf0;i=i+1;// sr1
        rom[i]={1'b1,8'hfc};i=i+1;// acc<=-4
        rom[i]=9'hf2;i=i+1; //jump c
        //把输入值读入内部寄存器
        for(j=0;j<8;j=j+1) begin
            rom[i]=9'he4;i=i+1;
            rom[i]=9'ha0+9'h0+j;i=i+1;// read from io
            rom[i]=9'h80+0+j;i=i+1;   // store to 0
        end
        rom[i] = 9'h1_00; i=i+1; // acc<=0;
        rom[i] = 9'h80+8;i=i+1;  // sum 0
        rom[i] = 9'h80+9;i=i+1;  // sum 0
        rom[i] = 9'h80+10;i=i+1;  // sum 0
        rom[i] = 9'h80+11;i=i+1;  // sum 0

        rom[i] = 9'h1_20; i=i+1;
        rom[i] = 9'h80+20;i=i+1;
        reloop_label=i;
        add_const(8,DELTA,8);
        add_reg(4,8,12);
        sl4(4,16);
        add_const(16,K0,16);
        xor_reg(12,16,12);
        sr5(4,16);
        add_const(16,K1,16);
        xor_reg(12,16,12);
        add_reg(0,12,0);

        add_reg(0,8,12);
        sl4(0,16);
        add_const(16,K2,16);
        xor_reg(12,16,12);
        sr5(0,16);
        add_const(16,K3,16);
        xor_reg(12,16,12);
        add_reg(0,12,0);
        trig_debug;
        clr_c;
        rom[i]=9'h1_01;i=i+1; // acc=1
        rom[i]=9'h0_20+20;i=i+1; // acc=reg20-acc
        rom[i]=9'h0_80+20;i=i+1; // reg20=acc
        reloop_label=reloop_label-i;
        rom[i]={1'b1,reloop_label[7:0]};i=i+1; //
        //rom[i]=9'h0_fa;i=i+1;        // jumpnc

        rom[i]=9'h1_01;i=i+1;//imm 1
        rom[i]=9'he4; i=i+1; // io req
        rom[i]={1'b0,3'h4,5'h1f};i=i+1;// write 1e
        $display("total instructions %d",i);
        @(posedge tea_done);
        #1_00;
        $finish();
    end

endmodule
