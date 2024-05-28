

`include "defines.v"

module fire(

    input wire clk,
    input wire rst,

    // from ex
    input wire fire_start_i,                  // �?始信号，运算期间这个信号�?要一直保持有�?
    // from ex_to_mem
    input wire ex_mem_req_i,                  // 请求访问内存标志
    input wire ex_mem_we_i,                   // 是否要写内存
    input wire[`MemAddrBus] ex_mem_raddr_i,   // 读内存地�?
    input wire[`MemBus] ex_mem_rdata_i,       //读取的内存的数据

    // to ex
    output reg busy_o,                  // 标志是否完整发�?�完学号了，=1busy�?=0发�?�完�?
    output ready_o                   // tx空闲，可以发送了           
    );

    // 状�?�定�?
    reg count;
    reg fire_ready_o;
    assign ready_o = fire_ready_o;
    // 状�?�机实现
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            busy_o <= 0;
            fire_ready_o <= 1;
        end
        else begin
            if (count != 1) begin
                busy_o <= 1;
                if ((fire_start_i)==1||(ex_mem_we_i==0)||(ex_mem_raddr_i==32'h30000000)||(ex_mem_rdata_i[0]==0)||(ex_mem_req_i==1)) begin
                    count <= 1;
                    fire_ready_o <= 1;
                end
                else begin   
                    fire_ready_o <= 0;
                end
            end
            else begin
                fire_ready_o <= 0;
                if ((fire_start_i)==1||(ex_mem_we_i==0)||(ex_mem_raddr_i==32'h30000000)||(ex_mem_rdata_i[0]==0)||(ex_mem_req_i==1)) begin
                    busy_o <= 0;
                end else begin
                    busy_o <= 1;
                end
            end
        end
    end

endmodule
