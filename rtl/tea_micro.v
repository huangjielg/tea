/*
 * https://en.wikipedia.org/wiki/Tiny_Encryption_Algorithm
 */
module tea
    (
        input clk,
        input rst,
        input [31:0] vi0,
        input [31:0] vi1,
        input start,
        output idle,
        output [31:0] vo0,
        output [31:0] vo1
    );

    parameter   k0=32'ha74a492958;
    parameter   k1=32'h7b548d90c4;
    parameter   k2=32'h0aa80ade53;
    parameter   k3=32'h08f0e8b9c4;
    localparam  delta=32'h9E3779B9;
    localparam  N_ROUND=32;

    reg [31:0] sum;
    reg [31:0] v0;
    reg [31:0] v1;

    reg [5:0]   c;
    reg [3:0]   c12;
    reg idle_r;
    reg [31:0] q_sum_xor;
    reg [31:0] m1,m2,x2;

    reg [6:0] rom[0:15] /*synthesis  syn_romstyle="distributed_rom"*/ ;
    wire [6:0] rom_q;
    wire [2:0] m1_sel=rom_q[2:0];
    wire [2:0] m2_sel=rom_q[5:3];
    wire       x2_sel=rom_q[6];
    
    assign rom_q=rom[c12];


    always@(posedge clk)begin
        q_sum_xor<=(m1+m2) ^ x2;
    end


    always@(posedge clk)begin
        if(rst)begin
            c<=6'h0;
            c12<=2'h0;
            idle_r<=1'b1;
            v0<=32'h0;
            v1<=32'h0;
            sum<=32'h0;

        end else begin

            if(idle_r&&(start))begin
                c<=N_ROUND-1;
                c12<=2'h0;
                idle_r<=1'b0;
                sum<=32'h0;
                v0<=vi0;
                v1<=vi1;
            end
            if(!idle_r)begin
                c12<=c12+1'b1;
                if(c12==4'd12)begin
                    c12<=2'h0;
                    c<=c-1'b1;
                    if(c==6'h0)begin
                        idle_r<=1'b1;
                    end
                end

                if(c12==4'h6)begin
                    v0<=q_sum_xor;
                end
                if(c12==4'hc)begin
                    v1<=q_sum_xor;
                end
                if(c12==4'h0)begin
                    sum<=q_sum_xor;
                end
            end
        end
    end
// micro part

    always@(*)begin
        case(m1_sel)
            3'h0:                m1=sum;
            3'h1:                m1=q_sum_xor;
            3'h2:                m1={q_sum_xor[27:0], 4'b0};
            3'h3:                m1={5'b0, q_sum_xor[31:5]};
            3'h4:                m1={32{1'bz}};
            3'h5:                m1={32{1'bz}};
            3'h6:                m1=v0;
            3'h7:                m1=v1;
        endcase
    end
    always@(*)begin
        case(m2_sel)
            3'h0:                m2=0;
            3'h1:                m2=delta;
            3'h2:                m2=k0;
            3'h3:                m2=k1;
            3'h4:                m2=k2;
            3'h5:                m2=k3;
            3'h6:                m2=q_sum_xor ;
            3'h7:                m2={32{1'bz}};
        endcase
        m2=32'h0;
    end
    always@(*)begin
        case(x2_sel)
            1'h0:                x2=0;
            1'h1:                x2=q_sum_xor;
        endcase
    end
    initial begin
        // sum <= sum+delta
        rom[0]={3'h0,3'h1,1'b0};
        // qreg <= (v1<<4) + k0
        rom[1]={3'h1,3'h0,1'b0};
        
        rom[2]={3'h2,3'h2,1'b0};
        rom[3]={3'h0,3'h7,1'b1};
        rom[4]={3'h3,3'h3,1'b1};
        rom[5]={3'h1,3'h6,1'b0};
        rom[6]={3'h1,3'h0,1'b0};
        rom[7]={3'h1,3'h0,1'b0};
        rom[8]={3'h4,3'h4,1'b0};
        rom[9]={3'h0,3'h6,1'b1};
        rom[10]={3'h5,3'h5,1'b1};
        rom[11]={3'h1,3'h7,1'b0};
        rom[12]={3'h1,3'h0,1'b0};
    end

    assign vo0=v0;
    assign vo1=v1;
    assign idle=idle_r;
endmodule


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


