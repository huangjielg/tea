module regfile
    #(parameter REGFILE_SIZE_WIDTH=5)
    (
        input clk,
        input [REGFILE_SIZE_WIDTH-1:0] addr,
        input we,
        input [7:0] din,
        output [7:0]     dout
    );
    reg [7:0] mem[2**REGFILE_SIZE_WIDTH-1:0];
    always@(posedge clk)begin
        if(we)
            mem[addr]<=din;
    end
    assign dout=mem[addr];
endmodule

module call_stack_mem
    #(parameter PC_WIDTH=8)
    (
        input clk,
        input [3:0] addr,
        input we,
        input [PC_WIDTH-1:0] din,
        output  [PC_WIDTH-1:0]    dout
    );
    reg [PC_WIDTH-1:0] mem[15:0];
    always@(posedge clk)begin
        if(we)
            mem[addr]<=din;
    end
    assign dout=mem[addr];
endmodule

module     tea_cpu
    #(parameter PC_WIDTH=8,
        parameter REGFILE_SIZE_WIDTH=5)
    (
        input clk,
        input rst,
        output [4:0] io_addr,
        output       io_rd,
        output       io_wr,
        input [7:0]  io_rddata,
        output [7:0] io_wrdata,

        output [PC_WIDTH-1:0] instr_addr,
        input [8:0] instr
    );


    wire [REGFILE_SIZE_WIDTH-1:0] reg_addr;
    wire [REGFILE_SIZE_WIDTH-1:0] reg_addr_last=-1;

    wire [7:0] reg_value;

    reg [PC_WIDTH-1:0] pc;
    reg [PC_WIDTH-1:0] pc_next;
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

    wire instr_addc  = (!instr[8])&&(instr[7:5]==3'h0);
    wire instr_subc  = (!instr[8])&&(instr[7:5]==3'h1);
    wire instr_and   = (!instr[8])&&(instr[7:5]==3'h2);
    wire instr_or    = (!instr[8])&&(instr[7:5]==3'h3);
    wire instr_store = (!instr[8])&&(instr[7:5]==3'h4);
    wire instr_load  = (!instr[8])&&(instr[7:5]==3'h5);
    wire instr_xor   = (!instr[8])&&(instr[7:5]==3'h6);
    wire instr_sl1   =  (!instr[8])&&(instr[7:5]==3'h7) && !instr[4] &&(instr[3:0==4'h0]);
    wire instr_sr1   =  (!instr[8])&&(instr[7:5]==3'h7) && instr[4] &&(instr[3:0==4'h0]);


    wire instr_call    = (!instr[8])&&(instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h1);
    wire instr_callc   = (!instr[8])&&(instr[7:5]==3'h7) && instr[4] && (instr[3:0]==4'h1);
    wire instr_jump    = (!instr[8])&&(instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h2);
    wire instr_jumpc   = (!instr[8])&&(instr[7:5]==3'h7) && instr[4] && (instr[3:0]==4'h2);
    wire instr_return  = (!instr[8])&&(instr[7:5]==3'h7) && !instr[4] && (instr[3:0]==4'h3);
    wire instr_returnc = (!instr[8])&&(instr[7:5]==3'h7) && instr[4] && (instr[3:0]==4'h3);

    wire instr_imm     =  (instr[8]==1'b1);
    wire instr_io      =  (instr==9'h1_e4);


    reg ioop_r;

    always@(posedge clk)begin
        if(rst)begin
            ioop_r<=1'b0;
        end else begin
            if(phase)begin
                ioop_r<= instr_io;
            end
        end
    end

    wire reg_we = instr_store&&!ioop_r&&phase;

    reg [7:0] reg_off;
    assign      reg_addr=reg_off+instr[REGFILE_SIZE_WIDTH-1:0];

    regfile u_reg
    (
        .clk(clk),
        .din(acc),
        .we(reg_we),
        .dout(reg_value),
        .addr(reg_addr)
    );
    always@(posedge clk)begin
        if(reg_we&&reg_addr==reg_addr_last)begin
            reg_off<=reg_value;
        end
    end


    always@(posedge clk)begin
        if(phase)begin
            if(instr[8]==1'b0) begin
                case(instr[7:5])
                    3'h0: {cy,acc}<={1'b0,acc}+reg_value+cy; // addcy
                    3'h1: {cy,acc}<={1'b0,acc}-reg_value-cy; // subcy
                    3'h2: {cy,acc}<={1'b0,acc&reg_value};    // and
                    3'h3: {cy,acc}<={1'b0,acc|reg_value};    // or
                    3'h5: {cy,acc}<={1'b0,ioop_r?io_rddata:reg_value};        // load
                    3'h6: {cy,acc}<={1'b0,acc^reg_value};    // xor
                    3'h7: begin
                        if(instr[4:0]==5'h0_0)begin
                            {cy,acc}<={acc,cy};            //sl1
                        end
                        if(instr[4:0]==5'h1_0)begin
                            {acc,cy}<={cy,acc};            // sr1
                        end
                    end
                    default:;
                endcase
            end else begin
                acc<=instr[7:0];
            end
        end
    end
    assign io_addr   = instr[4:0];
    assign io_rd     = ioop_r&&instr_load;
    assign io_wr     = ioop_r&&instr_store;
    assign io_wrdata = acc;



    wire [9:0] call_stack_top;
    reg [3:0]  sp;
    wire[3:0]  call_stack_addr;
    always@(posedge clk)begin
        if(rst)begin
            sp<=4'h0;
        end else begin
            if(instr_call||(instr_callc&&cy))begin
                sp<=sp+1'b1;
            end
            if(instr_return||(instr_returnc&&cy))begin
                sp<=sp-1'b1;
            end
        end
    end


    assign call_stack_addr= (instr_call||(instr_callc&&cy))?sp:sp-1'b1;

    call_stack_mem u_callstack_mem
    (
        .clk(clk),
        .addr(call_stack_addr),
        .din(pc_next),
        .we(instr_call||(instr_callc&&cy)),
        .dout(call_stack_top)
    );

    always@(*)begin
        pc_next=pc+1'b1;
        if( instr_call||(instr_callc&&cy)
                ||  instr_jump||(instr_jumpc&&cy)
            )begin
            pc_next=pc+$signed(acc);
        end
        if(instr_return||(instr_returnc&&cy))begin
            pc_next=call_stack_top;
        end
    end
endmodule

// 指令编码
// 0_000x_xxxx : addc
// 0_001x_xxxx : subc
// 0_010x_xxxx : and
// 0_011x_xxxx : or
// 0_1000_xxxx : store
// 0_1010_xxxx : load
// 0_110x_xxxx : xor

// 0_1110_0000 : sl0
// 0_1111_0000 : sr1

// 0_1110_0001 : call
// 0_1111_0001 : callc
// 0_1110_0010 : jmp
// 0_1111_0010 : jumpc

// 0_1110_0011 : return
// 0_1111_0011 : returnc

// 0_1110_0100 : ioop

// 1_xxxx_xxxx : imm


//call,callc,jump,jumpc,imm 为指令长度为2个字节
//操作码放在接下来的指令0




`ifdef _C_DODE_
* #include <stdint.h>

void encrypt (uint32_t v[2], const uint32_t k[4]) {
    uint32_t v0=v[0], v1=v[1], sum=0, i;           /* set up */
    uint32_t delta=0x9E3779B9;                     /* a key schedule constant */
    uint32_t k0=k[0], k1=k[1], k2=k[2], k3=k[3];   /* cache key */
    for (i=0; i<32; i++) {                         /* basic cycle start */
            sum += delta;
            v0 += ((v1<<4) + k0) ^ (v1 + sum) ^ ((v1>>5) + k1);
            v1 += ((v0<<4) + k2) ^ (v0 + sum) ^ ((v0>>5) + k3);
        }                                              /* end cycle */
        v[0]=v0; v[1]=v1;
}

void decrypt (uint32_t v[2], const uint32_t k[4]) {
    uint32_t v0=v[0], v1=v[1], sum=0xC6EF3720, i;  /* set up; sum is (delta << 5) & 0xFFFFFFFF */
    uint32_t delta=0x9E3779B9;                     /* a key schedule constant */
    uint32_t k0=k[0], k1=k[1], k2=k[2], k3=k[3];   /* cache key */
    for (i=0; i<32; i++) {                         /* basic cycle start */
            v1 -= ((v0<<4) + k2) ^ (v0 + sum) ^ ((v0>>5) + k3);
            v0 -= ((v1<<4) + k0) ^ (v1 + sum) ^ ((v1>>5) + k1);
            sum -= delta;
        }                                              /* end cycle */
        v[0]=v0; v[1]=v1;
}
`endif
