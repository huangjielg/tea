`timescale 1ns/1ps
`define SIM
//`define LOG_DETAIL
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
    tea_cpu #(.PC_WIDTH(9),.REGFILE_SIZE_WIDTH(5),.INCLUDE_CALL(1))
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
        #420_000;
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
        reg [31:0] t0;
        reg [31:0] t1;
        begin
            sum=sum+DELTA;
`ifdef LOG_DETAIL            
            t0=v1+sum;$write("%h ",t0);

            t1=v1<<4;$write("%h ",t1);

            t1=t1+K0;$write("%h ",t1);
            t0=t0^t1;$write("%h ",t0);

            t1=v1>>5;$write("%h ",t1);
            t1=t1+K1;$write("%h ",t1);
            t0=t0^t1;$write("%h ",t0);
            v0=v0+t0;$write("%h ",v0);
            $display("");
`else
            v0 = v0 + (((v1<<4) + K0) ^ (v1 + sum) ^ ((v1>>5) + K1));
`endif            
            v1 = v1 + (((v0<<4) + K2) ^ (v0 + sum) ^ ((v0>>5) + K3));
        end
    endtask
    reg debug_triggered=1'b0;
    always@(posedge clk)begin
        debug_triggered=1'b0;
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
                    if(io_wrdata==8'h0) begin
                        $display("RTL:%h%h%h%h %h%h%h%h %h%h%h%h %h",
                            uut.u_reg.mem[3],uut.u_reg.mem[2],uut.u_reg.mem[1],uut.u_reg.mem[0],    //v0
                            uut.u_reg.mem[3+4],uut.u_reg.mem[2+4],uut.u_reg.mem[1+4],uut.u_reg.mem[0+4], // v1
                            uut.u_reg.mem[3+8],uut.u_reg.mem[2+8],uut.u_reg.mem[1+8],uut.u_reg.mem[0+8], // sum
                            uut.u_reg.mem[20]
                        );
                        tea_loop;
                        $display("TB :%h %h %h ",v0,v1,sum);
                       // $finish();
                    end 
                    if(io_wrdata[7]==1'b1)begin
`ifdef                        LOG_DETAIL
                        $display("%h %h",io_wrdata[6:0],
                        {uut.u_reg.mem[io_wrdata[6:0]+3],uut.u_reg.mem[io_wrdata[6:0]+2],uut.u_reg.mem[io_wrdata[6:0]+1],uut.u_reg.mem[io_wrdata[6:0]+0]}
                        );
`endif                        
                        debug_triggered=1'b1;
                    end
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
    task instr_return;
        begin
            rom[i] = {1'b0,3'h7,5'h3};i=i+1; // return
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



    task  sl1;
        input [4:0] offset_in;
        input [4:0] offset_out;
        begin
            clr_c;
            clr_c;
            rom[i] = {1'b0,3'h5,offset_in};i=i+1;
            rom[i] = {1'b0,3'h7,1'b0,4'h0};i=i+1;
            rom[i] = {1'b0,3'h4,offset_out};i=i+1;

            rom[i] = {1'b0,3'h5,offset_in+5'h1};i=i+1;
            rom[i] = {1'b0,3'h7,1'b0,4'h0};i=i+1;
            rom[i] = {1'b0,3'h4,offset_out+5'h1};i=i+1;

            rom[i] = {1'b0,3'h5,offset_in+5'h2};i=i+1;
            rom[i] = {1'b0,3'h7,1'b0,4'h0};i=i+1;
            rom[i] = {1'b0,3'h4,offset_out+5'h2};i=i+1;

            rom[i] = {1'b0,3'h5,offset_in+5'h3};i=i+1;
            rom[i] = {1'b0,3'h7,1'b0,4'h0};i=i+1;
            rom[i] = {1'b0,3'h4,offset_out+5'h3};i=i+1;
            instr_return;

        end
    endtask

    task  sr1;
        input [4:0] offset_in;
        input [4:0] offset_out;
        begin
            clr_c;
            clr_c;

            rom[i] = {1'b0,3'h5,offset_in+5'h3};i=i+1;
            rom[i] = {1'b0,3'h7,1'b1,4'h0};i=i+1;
            rom[i] = {1'b0,3'h4,offset_out+5'h3};i=i+1;

            rom[i] = {1'b0,3'h5,offset_in+5'h2};i=i+1;
            rom[i] = {1'b0,3'h7,1'b1,4'h0};i=i+1;
            rom[i] = {1'b0,3'h4,offset_out+5'h2};i=i+1;

            rom[i] = {1'b0,3'h5,offset_in+5'h1};i=i+1;
            rom[i] = {1'b0,3'h7,1'b1,4'h0};i=i+1;
            rom[i] = {1'b0,3'h4,offset_out+5'h1};i=i+1;

            rom[i] = {1'b0,3'h5,offset_in+5'h0};i=i+1;
            rom[i] = {1'b0,3'h7,1'b1,4'h0};i=i+1;
            rom[i] = {1'b0,3'h4,offset_out+5'h0};i=i+1;

            instr_return;

        end
    endtask


    task  xor_reg;
        input [4:0] offset_in;
        input [4:0] offset_2;
        input [4:0] offset_out;
        begin

            for(j=0;j<4;j=j+1) begin
                rom[i] = {1'b0,3'h5,5'h0}+offset_in+j;i=i+1;    // acc = @offset_in
                rom[i] = {1'b0,3'h6,5'h0}+offset_2+j;i=i+1;   // acc <= acc ^ offset_2
                rom[i] = {1'b0,3'h4,5'h0}+offset_out+j;i=i+1;  // reg08 <= acc
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
        input [7:0] value;
        begin
            rom[i]={1'b1,value};i=i+1;
            rom[i]=9'he4; i=i+1; // io req
            rom[i]={1'b0,3'h4,5'h1e};i=i+1;// write 1e
        end
    endtask
    integer reloop_label;
    integer start_label=0;
    integer function_sl1_16;
    integer function_sr1_16;

    integer label_sum_plus_delta;
    integer label_sum_plus_v1;
    integer label_sl4;
    wire pc_eq_start_label=(uut.pc==start_label);
    wire pc_eq_function_sl1_16=(uut.pc==function_sl1_16);
    wire pc_eq_function_sr1_16=(uut.pc==function_sr1_16);
    wire pc_eq_label_sum_plus_delta=(uut.pc==label_sum_plus_delta);
    wire pc_eq_label_sum_plus_v1=(uut.pc==label_sum_plus_v1);
    wire pc_eq_label_sl4=(uut.pc==label_sl4);


    task sl4;
        input [4:0] offset_in;
        input [4:0] offset_out;
        integer call_offset;
        begin
            copy_reg(offset_in,offset_out);
            for(j=0;j<4;j=j+1) begin
                if((offset_out==5'd16)) begin
                    call_offset=function_sl1_16-i;
                end else begin
                    $display("error;");$finish();
                end
                rom[i]={1'b1,call_offset[8:1]};i=i+1;
                rom[i]={1'b0,3'h7,1'b0,4'h1};i=i+1;
            end
        end
    endtask

    task copy_reg;
        input [4:0] offset_in;
        input [4:0] offset_out;

        begin
            for(j=0;j<4;j=j+1) begin
                rom[i]={1'b0,3'h5,offset_in[4:0]+j[4:0]};i++;
                rom[i]={1'b0,3'h4,offset_out[4:0]+j[4:0]};i++;
            end
        end
    endtask

    task sr5;
        input [4:0] offset_in;
        input [4:0] offset_out;
        integer call_offset;
        begin
            copy_reg(offset_in,offset_out);
            for(j=0;j<5;j=j+1) begin
                if(offset_out==5'd16) begin
                    call_offset=function_sr1_16-i;
                end else begin
                    $display("error;");$finish();
                end
                rom[i]={1'b1,call_offset[8:1]};i=i+1;
                rom[i]={1'b0,3'h7,1'b0,4'h1};i=i+1;
            end
        end
    endtask

    task gen_instr;
        begin
            i=0;
            rom[i]={1'b1,start_label[8:1]};i=i+1;
            rom[i]={1'b0,3'h7,5'h2};i=i+1;

            function_sl1_16=i;
            sl1(16,16);

            function_sr1_16=i;
            sr1(16,16);

            rom[i]={1'b1,8'h0};i=i+1;
            start_label=i;

            // 反复读取状态，等待有一个请求
            rom[i]=9'he4; i=i+1; // io req
            rom[i]=9'ha0+9'h1f;i=i+1;// read from io
            rom[i]=9'hf0;i=i+1;// sr1
            rom[i]={1'b1,8'hfe};i=i+1;// acc<=-2
            rom[i]={1'b0,3'h7,1'b1,4'h2};i=i+1; //jump c
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

            rom[i] = 9'h1_1f; i=i+1;   // acc<=0x1f
            rom[i] = 9'h80+20;i=i+1;   // mem20=acc
            reloop_label=i;
            $display("reloop_label %h",reloop_label);

            add_const(8,DELTA,8);          // sum +=delta
            //trig_debug(8'h88);
            label_sum_plus_delta=i;
            add_reg(4,8,12);              // mem12 = v1+sum
            trig_debug(8'h8c);
            label_sum_plus_v1=i;
            sl4(4,16);                    // mem16= v1<<4
            trig_debug(8'h90);
            label_sl4=i;
            add_const(16,K0,16);          // mem16=mem16+k0
            trig_debug(8'h90);
            xor_reg(12,16,12);            // mem12=mem16^mem12
            trig_debug(8'h8c);
            sr5(4,16);                    // mem16= v1>>5;
            trig_debug(8'h90);
            add_const(16,K1,16);          // mem16=mem16+k1
            trig_debug(8'h90);
            xor_reg(12,16,12);            // mem12=mem16^mem12
            trig_debug(8'h8c);
            add_reg(0,12,0);              // v0 = v0 +mem12
            trig_debug(8'h80);


            add_reg(0,8,12);              // mem12 = v0 +sum
            sl4(0,16);                    // mem16 = v0 <<4
            add_const(16,K2,16);         //  mem16 = mem16+k2
            xor_reg(12,16,12);           //  mem12 = mem12 ^ mem16
            sr5(0,16);                   //  mem16 = v0>>5
            add_const(16,K3,16);         //  mem16 = mem16+k3
            xor_reg(12,16,12);           // mem12 = mem12 ^ mem16
            add_reg(4,12,4);             // v1 = v1 +mem12
            trig_debug(8'h00);
            clr_c;
            rom[i]=9'h1_01;i=i+1; // acc=1
            rom[i]=9'h0_20+20;i=i+1; // acc=reg20-acc
            rom[i]=9'h0_80+20;i=i+1; // reg20=acc
            reloop_label=reloop_label-i;
            rom[i]={1'b1,reloop_label[8:1]};i=i+1;
            $display("jumpnc at %h,%h",i,reloop_label);
            rom[i]=9'h0_fa;i=i+1;        // jumpnc

            rom[i]=9'h1_01;i=i+1;//imm 1
            rom[i]=9'he4; i=i+1; // io req
            rom[i]={1'b0,3'h4,5'h1f};i=i+1;// write 1e
        end
    endtask
    integer fd;
    initial begin
        gen_instr();
        gen_instr();
        fd=$fopen("instr_rom.mem");
        for(j=0;j<i;j=j+1)begin
            $fdisplay(fd,"%h",rom[j]);
        end
        $display("total instructions %d",i);
        @(posedge tea_done);
        #1_00;
        $finish();
    end


endmodule
