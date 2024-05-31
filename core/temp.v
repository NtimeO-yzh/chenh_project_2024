

`include "defines.v"

module temp(

    input wire clk,
    input wire rst,

    // from ex
    input wire temp_start_i,                  // �?始信号，运算期间这个信号�?要一直保持有�?
    input wire ex_mem_req_i,                  // 请求访问内存标志
    input wire ex_mem_we_i,                   // 是否要写内存
    input wire[`MemAddrBus] ex_mem_raddr_i,   // 读内存地�?
    input wire[`MemBus] ex_mem_rdata_i,       //读取的内存的数据     //写往的内存的数据
    input wire[`RegAddrBus] ex_reg_waddr_i,

    // to ex  
    output reg[`RegAddrBus] temp_reg_waddr_o,
    output reg busy_o,                      
    output ready_o                          
    );

    reg temp_ready_o,count;
    reg [`RegAddrBus] reg_for_reg_waddr;
    assign ready_o = temp_ready_o;
    // 状�?�机实现
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            count <= 0;
            busy_o <= 0;
            temp_ready_o <= 0;
            temp_reg_waddr_o <= 32'b0;
        end
        else begin
            if ((temp_start_i)==1) begin
                busy_o <= 1;
                if (count!=1) begin
                    if ((ex_mem_we_i==0)&&(ex_mem_raddr_i==32'h7004_0000)&&(ex_mem_rdata_i[0]==0)&&(ex_mem_req_i==1)) begin
                        temp_ready_o <= 1;
                        temp_reg_waddr_o <= reg_for_reg_waddr;
                        count <= 1;
                    end  
                end else begin
                    busy_o <= 0;
                end
            end else begin
                busy_o <= 0;
            end
        end
    end
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            reg_for_reg_waddr <= 32'b0;
        end
        else begin
            if ((temp_start_i)==1&&(ex_mem_we_i==1)&&(ex_mem_req_i==1)) begin
                reg_for_reg_waddr <= ex_reg_waddr_i;
            end 
        end
    end

endmodule
