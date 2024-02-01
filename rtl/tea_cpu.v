module regfile
    (
        input clk,
        input [4:0] addr,
        input we,
        input [7:0] din,
        output [7:0]     dout
    );
    reg [7:0] mem[31:0];
    always@(posedge clk)begin
        if(we)
            mem[addr]<=din;
    end
    assign dout=mem[addr];
endmodule

module call_stack_mem
    (
        input clk,
        input [3:0] addr,
        input we,
        input [9:0] din,
        output  [9:0]    dout
    );
    reg [9:0] mem[15:0];
    always@(posedge clk)begin
        if(we)
            mem[addr]<=din;
    end
    assign dout=mem[addr];
endmodule

module tea_cpu
    (
        input clk,
        input rst,
        output [4:0] io_addr,
        output       io_rd,
        output       io_wr,
        input [7:0]  io_rddata,
        output [7:0] io_wrdata,

        output [9:0] instr_addr,
        input [7:0] instr
    );


    wire [4:0] reg_addr;

    wire [7:0] reg_value;

    reg [9:0] pc;
    reg [9:0] pc_next;
    assign instr_addr=pc_next;
    reg [7:0] acc;
    reg       cy;
    reg phase;
    always@(posedge clk)begin
        if(rst)begin
            pc<=10'h0;
            phase<=1'b0;
        end else begin
            phase<=~phase;
            if(phase)begin
                pc<=pc_next;
            end
        end
    end

    wire instr_addc = (instr[7:5]==3'h0);
    wire instr_subc = (instr[7:5]==3'h1);
    wire instr_and = (instr[7:5]==3'h2);
    wire instr_or = (instr[7:5]==3'h3);
    wire instr_store = (instr[7:5]==3'h4);
    wire instr_load  = (instr[7:5]==3'h5);
    wire instr_xor  = (instr[7:5]==3'h6);

    wire instr_call = (instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h0);
    wire instr_callc = (instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h1);
    wire instr_jump = (instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h2);
    wire instr_jumpc = (instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h3);
    wire instr_return = (instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h4);
    wire instr_returnc = (instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h5);

    wire instr_sl0 =  (instr[7:5]==3'h7) && instr[4] && (instr[3:0]==4'h0);
    wire instr_sr0 =  (instr[7:5]==3'h7) && instr[4] && (instr[3:0]==4'h1);
    wire instr_imm =  (instr[7:5]==3'h7) && instr[4] && (instr[3:0]==4'h2);
    wire instr_io  =  (instr[7:5]==3'h7) && instr[4] && (instr[3:0]==4'h3);

    reg instr_call_r;
    reg instr_callc_r;
    reg instr_jump_r;
    reg instr_jumpc_r;
    reg instr_imm_r;
    reg two_byte_instr_act;
    reg ioop_r;

    always@(posedge clk)begin
        if(rst)begin
            instr_call_r<=1'b0;
            instr_callc_r<=1'b0;
            instr_jump_r<=1'b0;
            instr_jumpc_r<=1'b0;
            instr_imm_r<=1'b0;
            two_byte_instr_act<=1'b0;
            ioop_r<=1'b0;
        end else begin
            if(phase)begin
                instr_call_r<=instr_call;
                instr_callc_r<=instr_callc;
                instr_jump_r<=instr_jump;
                instr_jumpc_r<=instr_jumpc;
                instr_imm_r<=instr_imm;
                two_byte_instr_act <= instr_call|instr_callc|instr_jump|instr_jumpc|instr_imm;
                ioop_r<= instr_io;
            end
        end
    end
    wire reg_we = instr_store&&!ioop_r&&phase;
    /*
     *
     reg [7:0]  regfile [31:0];
     always@(posedge clk)begin
     if(reg_we)begin
     regfile[reg_addr]<=acc;
     end
     end
     assign      reg_value=regfile[reg_addr];
     */

    assign      reg_addr=instr[4:0];

    regfile u_reg
    (
        .clk(clk),
        .din(acc),
        .we(reg_we),
        .dout(reg_value),
        .addr(reg_addr)
    );

    always@(posedge clk)begin
        if(phase)begin
            if(two_byte_instr_act) begin
                if(instr_imm_r) begin
                    acc <= instr;
                end
            end else begin
                case(instr[7:5])
                    3'h0: {cy,acc}<={1'b0,acc}+reg_value+cy; // addcy
                    3'h1: {cy,acc}<={1'b0,acc}-reg_value-cy; // subcy
                    3'h2: {cy,acc}<={1'b0,acc&reg_value};    // and
                    3'h3: {cy,acc}<={1'b0,acc|reg_value};    // or
                    3'h5: {cy,acc}<={1'b0,ioop_r?io_rddata:reg_value};        // load
                    3'h6: {cy,acc}<={1'b0,acc^reg_value};    // xor
                    3'h7: begin
                        if(instr[4:0]==5'h1_0)begin
                            {cy,acc}<={acc,cy};            //sl1
                        end
                        if(instr[4:0]==5'h1_1)begin
                            {acc,cy}<={cy,acc};            // sr1
                        end
                    end
                    default:;
                endcase
            end
        end
    end
    assign io_addr   = instr[4:0];
    assign io_rd     = ioop_r&&instr_load&&(!two_byte_instr_act);
    assign io_wr     = ioop_r&&instr_store&&(!two_byte_instr_act);
    assign io_wrdata = acc;



    wire [9:0] call_stack_top;
    reg [3:0]  sp;
    wire[3:0]  call_stack_addr;
    always@(posedge clk)begin
        if(rst)begin
            sp<=4'h0;
        end else begin
            if(instr_call_r||(instr_callc_r&&cy))begin
                sp<=sp+1'b1;
            end
            if(instr_return||(instr_returnc&&cy))begin
                sp<=sp-1'b1;
            end
        end
    end


    assign call_stack_addr= (instr_call_r||(instr_callc_r&&cy))?sp:sp-1'b1;

    call_stack_mem u_callstack_mem
    (
        .clk(clk),
        .addr(call_stack_addr),
        .din(pc_next),
        .we(instr_call_r||(instr_callc_r&&cy)),
        .dout(call_stack_top)
    );

    always@(*)begin
        pc_next=pc+1'b1;
        if( instr_call_r||(instr_callc_r&&cy)
                ||  instr_jump_r||(instr_jumpc_r&&cy)
            )begin
            pc_next=pc+$signed(instr);
        end
        if(instr_return||(instr_returnc&&cy))begin
            pc_next=call_stack_top;
        end
    end
endmodule
// 指令编码
// 000x_xxxx : addc
// 001x_xxxx : subc
// 010x_xxxx : and
// 011x_xxxx : or
// 100x_xxxx : store
// 101x_xxxx : load
// 110x_xxxx : xor

// 1110_0000 : call
// 1110_0001 : callc
// 1110_0010 : jump
// 1110_0011 : jumpc
// 1110_0110 : return
// 1110_0111 : returnc

// 1111_0000 : sl0
// 1111_0001 : sr1
// 1111_0010 : imm
// 1111_0011 : io op

//call,callc,jump,jumpc,imm 为指令长度为2个字节
//操作码放在接下来的指令0
