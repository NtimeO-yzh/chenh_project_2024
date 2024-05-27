 /*                                                                      
 Copyright 2019 Blue Liang, liangkangnan@163.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "defines.v"

// 执行模块
// 纯组合逻辑电路
module ex(

    input wire rst,

    // from id
    input wire[`InstBus] inst_i,            // 指令内容
    input wire[`InstAddrBus] inst_addr_i,   // 指令地址
    input wire reg_we_i,                    // 是否写通用寄存器
    input wire[`RegAddrBus] reg_waddr_i,    // 写通用寄存器地址
    input wire[`RegBus] reg1_rdata_i,       // 通用寄存器1输入数据
    input wire[`RegBus] reg2_rdata_i,       // 通用寄存器2输入数据
    input wire csr_we_i,                    // 是否写CSR寄存器
    input wire[`MemAddrBus] csr_waddr_i,    // 写CSR寄存器地址
    input wire[`RegBus] csr_rdata_i,        // CSR寄存器输入数据
    input wire int_assert_i,                // 中断发生标志
    input wire[`InstAddrBus] int_addr_i,    // 中断跳转地址
    input wire[`MemAddrBus] op1_i,
    input wire[`MemAddrBus] op2_i,
    input wire[`MemAddrBus] op1_jump_i,
    input wire[`MemAddrBus] op2_jump_i,

    // from mem
    input wire[`MemBus] mem_rdata_i,        // 内存输入数据

    // from div
    input wire div_ready_i,                 // 除法运算完成标志
    input wire[`RegBus] div_result_i,       // 除法运算结果
    input wire div_busy_i,                  // 除法运算忙标志
    input wire[`RegAddrBus] div_reg_waddr_i,// 除法运算结束后要写的寄存器地址

    // from send
    input wire[31:0] send_ID_i,        //send发送的数据
    input wire send_busy_i,               //send运算忙标志
    input wire send_ready_i,             //send改变的we信号，控制是写还是读

    // to mem
    output reg[`MemBus] mem_wdata_o,        // 写内存数据
    output reg[`MemAddrBus] mem_raddr_o,    // 读内存地址
    output reg[`MemAddrBus] mem_waddr_o,    // 写内存地址
    output wire mem_we_o,                   // 是否要写内存
    output wire mem_req_o,                  // 请求访问内存标志

    // to regs
    output wire[`RegBus] reg_wdata_o,       // 写寄存器数据
    output wire reg_we_o,                   // 是否要写通用寄存器
    output wire[`RegAddrBus] reg_waddr_o,   // 写通用寄存器地址

    // to csr reg
    output reg[`RegBus] csr_wdata_o,        // 写CSR寄存器数据
    output wire csr_we_o,                   // 是否要写CSR寄存器
    output wire[`MemAddrBus] csr_waddr_o,   // 写CSR寄存器地址

    // to div
    output wire div_start_o,                // 开始除法运算标志
    output reg[`RegBus] div_dividend_o,     // 被除数
    output reg[`RegBus] div_divisor_o,      // 除数
    output reg[2:0] div_op_o,               // 具体是哪一条除法指令
    output reg[`RegAddrBus] div_reg_waddr_o,// 除法运算结束后要写的寄存器地址

    // to send
    output wire send_start_o,                // 开始send标志
    output wire send_mem_req_o,                   // 标志位，访存的
    output wire send_mem_we_o,                // 内存读写状态
    output wire[`MemAddrBus] send_mem_raddr_o,     // 地址，读内存的
    output wire[`MemBus] send_mem_rdata_o,      //数据，读取内存的

    // to ctrl
    output wire hold_flag_o,                // 是否暂停标志
    output wire jump_flag_o,                // 是否跳转标志
    output wire[`InstAddrBus] jump_addr_o   // 跳转目的地址

    );

    wire[1:0] mem_raddr_index;
    wire[1:0] mem_waddr_index;
    wire[`DoubleRegBus] mul_temp;
    wire[`DoubleRegBus] mul_temp_invert;
    wire[31:0] sr_shift;
    wire[31:0] sri_shift;
    wire[31:0] sr_shift_mask;
    wire[31:0] sri_shift_mask;
    wire[31:0] op1_add_op2_res;
    wire[31:0] op1_jump_add_op2_jump_res;
    wire[31:0] reg1_data_invert;
    wire[31:0] reg2_data_invert;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire op1_eq_op2;
    reg[`RegBus] mul_op1;
    reg[`RegBus] mul_op2;
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire[6:0] funct7;
    wire[4:0] rd;
    wire[4:0] uimm;
    
    //div相关中间reg
    reg[`RegBus] div_wdata;
    reg div_we;
    reg[`RegAddrBus] div_waddr;
    reg div_hold_flag;
    reg div_jump_flag;
    reg[`InstAddrBus] div_jump_addr;
    reg div_start;
    //send相关中间reg
    reg send_start;
    reg send_we;
    reg send_req;
    reg send_hold_flag;
    reg send_jump_flag;
    reg[`InstAddrBus] send_jump_addr;
    reg[`MemAddrBus] send_mem_waddr;
    reg[`MemAddrBus] send_mem_raddr;
    reg[`MemBus] send_mem_wdata;

    //ex defult模块//
    reg hold_flag;
    reg jump_flag;
    reg[`InstAddrBus] jump_addr;
    reg mem_we;
    reg mem_req;
    reg[`RegBus] reg_wdata;
    reg reg_we;
    reg[`RegAddrBus] reg_waddr;
    reg[`MemAddrBus] mem_waddr;
    reg[`MemAddrBus] mem_raddr;
    reg[`MemBus] mem_wdata;
    

    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign funct7 = inst_i[31:25];
    assign rd = inst_i[11:7];
    assign uimm = inst_i[19:15];

    assign sr_shift = reg1_rdata_i >> reg2_rdata_i[4:0];
    assign sri_shift = reg1_rdata_i >> inst_i[24:20];
    assign sr_shift_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    assign sri_shift_mask = 32'hffffffff >> inst_i[24:20];

    assign op1_add_op2_res = op1_i + op2_i;
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

    assign reg1_data_invert = ~reg1_rdata_i + 1;
    assign reg2_data_invert = ~reg2_rdata_i + 1;

    // 有符号数比较
    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    // 无符号数比较
    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);

    assign mul_temp = mul_op1 * mul_op2;
    assign mul_temp_invert = ~mul_temp + 1;

    assign mem_raddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]}) & 2'b11;
    assign mem_waddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}) & 2'b11;

    assign div_start_o = (int_assert_i == `INT_ASSERT)? `DivStop: div_start;
    

    assign reg_wdata_o = reg_wdata | div_wdata |fire_reg_wdata;
    // 响应中断时不写通用寄存器
    assign reg_we_o = (int_assert_i == `INT_ASSERT)? `WriteDisable: (reg_we || div_we || fire_reg_we);
    assign reg_waddr_o = reg_waddr | div_waddr |fire_reg_waddr;

    // 响应中断时不写内存
    assign mem_we_o = (int_assert_i == `INT_ASSERT)? `WriteDisable: (mem_we || send_we);

    // 响应中断时不向总线请求访问内存
    assign mem_req_o = (int_assert_i == `INT_ASSERT)? `RIB_NREQ: (mem_req || send_req);

    //写往内存的地址
    assign mem_waddr_o = mem_waddr|send_mem_waddr
    //从内存读的地址
    assign mem_raddr_o = mem_raddr|send_mem_raddr
    //写往内存的数据
    assign mem_wdata_o = mem_wdata|send_mem_wdata
    //hold方法以及jump，并且处理和中断的关系
    assign hold_flag_o = hold_flag || div_hold_flag || send_hold_flag;/////////或者send中断
    assign jump_flag_o = jump_flag || div_jump_flag || send_jump_flag ||((int_assert_i == `INT_ASSERT)? `JumpEnable: `JumpDisable);/////////或者send跳转
    assign jump_addr_o = (int_assert_i == `INT_ASSERT)? int_addr_i: (jump_addr | div_jump_addr | send_jump_addr);////或者跳转到一个地址，send

    // 响应中断时不写CSR寄存器
    assign csr_we_o = (int_assert_i == `INT_ASSERT)? `WriteDisable: csr_we_i;
    assign csr_waddr_o = csr_waddr_i;


    // 处理乘法指令
    always @ (*) begin
        if ((opcode == `INST_TYPE_R_M) && (funct7 == 7'b0000001)) begin
            case (funct3)
                `INST_MUL, `INST_MULHU: begin
                    mul_op1 = reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
                `INST_MULHSU: begin
                    mul_op1 = (reg1_rdata_i[31] == 1'b1)? (reg1_data_invert): reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
                `INST_MULH: begin
                    mul_op1 = (reg1_rdata_i[31] == 1'b1)? (reg1_data_invert): reg1_rdata_i;
                    mul_op2 = (reg2_rdata_i[31] == 1'b1)? (reg2_data_invert): reg2_rdata_i;
                end
                default: begin
                    mul_op1 = reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
            endcase
        end else begin
            mul_op1 = reg1_rdata_i;
            mul_op2 = reg2_rdata_i;
        end
    end

    // 处理除法指令
    always @ (*) begin
        div_dividend_o = reg1_rdata_i;
        div_divisor_o = reg2_rdata_i;
        div_op_o = funct3;
        div_reg_waddr_o = reg_waddr_i;
        if ((opcode == `INST_TYPE_R_M) && (funct7 == 7'b0000001)) begin
            div_we = `WriteDisable;
            div_wdata = `ZeroWord;
            div_waddr = `ZeroWord;
            case (funct3)
                `INST_DIV, `INST_DIVU, `INST_REM, `INST_REMU: begin
                    div_start = `DivStart;
                    div_jump_flag = `JumpEnable;
                    div_hold_flag = `HoldEnable;
                    div_jump_addr = op1_jump_add_op2_jump_res;
                end
                default: begin
                    div_start = `DivStop;
                    div_jump_flag = `JumpDisable;
                    div_hold_flag = `HoldDisable;
                    div_jump_addr = `ZeroWord;
                end
            endcase
        end else begin
            div_jump_flag = `JumpDisable;
            div_jump_addr = `ZeroWord;
            if (div_busy_i == `True) begin
                div_start = `DivStart;
                div_we = `WriteDisable;
                div_wdata = `ZeroWord;
                div_waddr = `ZeroWord;
                div_hold_flag = `HoldEnable;
            end else begin
                div_start = `DivStop;
                div_hold_flag = `HoldDisable;
                if (div_ready_i == `DivResultReady) begin ///这个信号在控制write
                    div_wdata = div_result_i;
                    div_waddr = div_reg_waddr_i;
                    div_we = `WriteEnable;
                end else begin
                    div_we = `WriteDisable;
                    div_wdata = `ZeroWord;
                    div_waddr = `ZeroWord;
                end
            end
        end
    end

    // 处理fire_1/
    assign fire_mem_req_o = mem_req_o;
    assign fire_mem_we_o = mem_we_o;
    assign fire_mem_raddr_o = mem_raddr_o;
    assign fire_mem_rdata_o = mem_rdata_o;
    assign fire_start_o = (int_assert_i == `INT_ASSERT)? 0: fire_start;/////////fire+中断
    always @ (*) begin
        if ((opcode == 7'b0101111) && (funct3 == 3'b010) && (inst_i[31:20]==11'b0) && reg1_rdata >= reg2_rdata) begin //组合逻辑，这个周期内负责传给fire模块start信号，并且产生+1的pc地址；下一个周期就进入下面的else
            fire_start = 1;
            fire_jump_flag = `JumpEnable;
            fire_hold_flag = `HoldEnable;
            fire_jump_addr = op1_jump_add_op2_jump_res;
            fire_mem_wdata = `ZeroWord;//没有和regdata一样使用 || 的形式， 有可能会一个周期内满足多个memdata就出错了， 只能做逻辑上的保证，否则就会赋值两次， 而不是值的错误
            fire_mem_raddr = 32'h3000_0000;
            fire_mem_wdata = `ZeroWord;
            fire_mem_we = `WriteDisable;
            fire_req = 1;
            fire_reg_wdata = 32'b0;
            fire_reg_we = `WriteEnable;
            fire_reg_waddr = reg_waddr_i;
        end else begin
            fire_jump_flag = `JumpDisable;
            fire_jump_addr = `ZeroWord; //?????????这个不应该是保持之前的PC吗，还是说下面有别的操作会给一个赋值，使得所以下面会有一个是否hold（√）
            fire_reg_wdata = `ZeroWord;
            fire_reg_we = `WriteDisable;
            fire_reg_waddr = reg_waddr_i;
            if (fire_busy_i == `True) begin
                fire_start = 1; //一直保持fire_start的激活状态，关死需要busy不为0
                fire_hold_flag = `HoldEnable;
                fire_req = 1;
                fire_mem_wdata = reg1_rdata;
                fire_mem_waddr = 32'h3000_000c;
                fire_mem_raddr = 32'h3000_0000;
                if (fire_ID_ready_i == 1 ) begin                  
                    fire_mem_we = `WriteEnable;
                end 
                else begin
                    fire_mem_we = `WriteDisable;
                end
            end else begin
                fire_start = 0;
                fire_hold_flag = `HoldDisable;
                fire_mem_wdata = `ZeroWord;
                fire_mem_waddr = `ZeroWord;
                fire_mem_we = `WriteDisable;
                fire_req = 0;
                fire_mem_raddr = `ZeroWord;
            end
        end
    end
    // 处理Send_ID/
    assign send_mem_req_o = mem_req_o;
    assign send_mem_we_o = mem_we_o;
    assign send_mem_raddr_o = mem_raddr_o;
    assign send_mem_rdata_o = mem_rdata_o;
    assign send_start_o = (int_assert_i == `INT_ASSERT)? 0: send_start;/////////send+中断
    always @ (*) begin
        if ((opcode == 7'b0101111) && (funct3 == 3'b000)) begin //组合逻辑，这个周期内负责传给send模块start信号，并且产生+1的pc地址；下一个周期就进入下面的else
            send_start = 1;
            send_jump_flag = `JumpEnable;
            send_hold_flag = `HoldEnable;
            send_jump_addr = op1_jump_add_op2_jump_res;
            send_mem_wdata = `ZeroWord;//没有和regdata一样使用 || 的形式， 有可能会一个周期内满足多个memdata就出错了， 只能做逻辑上的保证，否则就会赋值两次， 而不是值的错误
            send_mem_raddr = 32'h3000_0000;
            send_mem_wdata = `ZeroWord;
            send_we = `WriteDisable;
            send_req = 1;
        end else begin
            send_jump_flag = `JumpDisable;
            send_jump_addr = `ZeroWord; //?????????这个不应该是保持之前的PC吗，还是说下面有别的操作会给一个赋值，使得所以下面会有一个是否hold（√）
            if (send_busy_i == `True) begin
                send_start = 1; //一直保持send_start的激活状态，关死需要busy不为0
                send_hold_flag = `HoldEnable;
                send_req = 1;
                send_mem_wdata = send_ID_i;
                send_mem_waddr = 32'h3000_000c;
                send_mem_raddr = 32'h3000_0000;
                if (send_ID_ready_i == 1 ) begin                  
                    send_we = `WriteEnable;
                end 
                else begin
                    send_we = `WriteDisable;
                end
            end else begin
                send_start = 0;
                send_hold_flag = `HoldDisable;
                send_mem_wdata = `ZeroWord;
                send_mem_waddr = `ZeroWord;
                send_we = `WriteDisable;
                send_req = 0;
                send_mem_raddr = `ZeroWord;
            end
        end
    end   
    // 执行
    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        mem_req = `RIB_NREQ;
        csr_wdata_o = `ZeroWord;

        case (opcode)
            7'b0101111:
                case (funct3)
                    010: begin
                        if(inst_i[31:20]==11'b0) begin
                            if (reg1_rdata < reg2_rdata) begin
                                reg_wdata = reg1_rdata;
                                reg_we = `WriteEnable;
                                reg_waddr = reg_waddr_i;
                                jump_flag = `JumpDisable;
                                hold_flag = `HoldDisable;
                                jump_addr = `ZeroWord;
                                mem_wdata = `ZeroWord;
                                mem_raddr = `ZeroWord;
                                mem_waddr = `ZeroWord;
                                mem_we = `WriteDisable;
                            end else begin
                                reg_wdata = `ZeroWord;
                                reg_we = `WriteDisable;
                                reg_waddr = `ZeroWord;
                                jump_flag = `JumpDisable;
                                hold_flag = `HoldDisable;
                                jump_addr = `ZeroWord;
                                mem_wdata = `ZeroWord;
                                mem_raddr = `ZeroWord;
                                mem_waddr = `ZeroWord;
                                mem_we = `WriteDisable;
                            end
                        end else begin
                            reg_wdata = reg1_rdata+{{20{inst_i[31]}}, inst_i[31:20]};;
                            reg_we = `WriteEnable;
                            reg_waddr = reg_waddr_i;
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;

                        end
                    end
                    default: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                    end
                endcase
            `INST_TYPE_I: begin
                case (funct3)
                    `INST_ADDI: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = op1_add_op2_res;
                    end
                    `INST_SLTI: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                    end
                    `INST_SLTIU: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                    end
                    `INST_XORI: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = op1_i ^ op2_i;
                    end
                    `INST_ORI: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = op1_i | op2_i;
                    end
                    `INST_ANDI: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = op1_i & op2_i;
                    end
                    `INST_SLLI: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = reg1_rdata_i << inst_i[24:20];
                    end
                    `INST_SRI: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        if (inst_i[30] == 1'b1) begin
                            reg_wdata = (sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask));
                        end else begin
                            reg_wdata = reg1_rdata_i >> inst_i[24:20];
                        end
                    end
                    default: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                    end
                endcase
            end
            `INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `INST_ADD_SUB: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            if (inst_i[30] == 1'b0) begin
                                reg_wdata = op1_add_op2_res;
                            end else begin
                                reg_wdata = op1_i - op2_i;
                            end
                        end
                        `INST_SLL: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = op1_i << op2_i[4:0];
                        end
                        `INST_SLT: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                        end
                        `INST_SLTU: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                        end
                        `INST_XOR: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = op1_i ^ op2_i;
                        end
                        `INST_SR: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            if (inst_i[30] == 1'b1) begin
                                reg_wdata = (sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask));
                            end else begin
                                reg_wdata = reg1_rdata_i >> reg2_rdata_i[4:0];
                            end
                        end
                        `INST_OR: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = op1_i | op2_i;
                        end
                        `INST_AND: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = op1_i & op2_i;
                        end
                        default: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = `ZeroWord;
                        end
                    endcase
                end else if (funct7 == 7'b0000001) begin
                    case (funct3)
                        `INST_MUL: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = mul_temp[31:0];
                        end
                        `INST_MULHU: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = mul_temp[63:32];
                        end
                        `INST_MULH: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            case ({reg1_rdata_i[31], reg2_rdata_i[31]})
                                2'b00: begin
                                    reg_wdata = mul_temp[63:32];
                                end
                                2'b11: begin
                                    reg_wdata = mul_temp[63:32];
                                end
                                2'b10: begin
                                    reg_wdata = mul_temp_invert[63:32];
                                end
                                default: begin
                                    reg_wdata = mul_temp_invert[63:32];
                                end
                            endcase
                        end
                        `INST_MULHSU: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            if (reg1_rdata_i[31] == 1'b1) begin
                                reg_wdata = mul_temp_invert[63:32];
                            end else begin
                                reg_wdata = mul_temp[63:32];
                            end
                        end
                        default: begin
                            jump_flag = `JumpDisable;
                            hold_flag = `HoldDisable;
                            jump_addr = `ZeroWord;
                            mem_wdata = `ZeroWord;
                            mem_raddr = `ZeroWord;
                            mem_waddr = `ZeroWord;
                            mem_we = `WriteDisable;
                            reg_wdata = `ZeroWord;
                        end
                    endcase
                end else begin
                    jump_flag = `JumpDisable;
                    hold_flag = `HoldDisable;
                    jump_addr = `ZeroWord;
                    mem_wdata = `ZeroWord;
                    mem_raddr = `ZeroWord;
                    mem_waddr = `ZeroWord;
                    mem_we = `WriteDisable;
                    reg_wdata = `ZeroWord;
                end
            end
            `INST_TYPE_L: begin
                case (funct3)
                    `INST_LB: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        mem_req = `RIB_REQ;
                        mem_raddr = op1_add_op2_res;
                        case (mem_raddr_index)
                            2'b00: begin
                                reg_wdata = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
                            end
                            2'b01: begin
                                reg_wdata = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
                            end
                            2'b10: begin
                                reg_wdata = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
                            end
                            default: begin
                                reg_wdata = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
                            end
                        endcase
                    end
                    `INST_LH: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        mem_req = `RIB_REQ;
                        mem_raddr = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                        end
                    end
                    `INST_LW: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        mem_req = `RIB_REQ;
                        mem_raddr = op1_add_op2_res;
                        reg_wdata = mem_rdata_i;
                    end
                    `INST_LBU: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        mem_req = `RIB_REQ;
                        mem_raddr = op1_add_op2_res;
                        case (mem_raddr_index)
                            2'b00: begin
                                reg_wdata = {24'h0, mem_rdata_i[7:0]};
                            end
                            2'b01: begin
                                reg_wdata = {24'h0, mem_rdata_i[15:8]};
                            end
                            2'b10: begin
                                reg_wdata = {24'h0, mem_rdata_i[23:16]};
                            end
                            default: begin
                                reg_wdata = {24'h0, mem_rdata_i[31:24]};
                            end
                        endcase
                    end
                    `INST_LHU: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        mem_req = `RIB_REQ;
                        mem_raddr = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {16'h0, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {16'h0, mem_rdata_i[31:16]};
                        end
                    end
                    default: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                    end
                endcase
            end
            `INST_TYPE_S: begin
                case (funct3)
                    `INST_SB: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        reg_wdata = `ZeroWord;
                        mem_we = `WriteEnable;
                        mem_req = `RIB_REQ;
                        mem_waddr = op1_add_op2_res;
                        mem_raddr = op1_add_op2_res;
                        case (mem_waddr_index)
                            2'b00: begin
                                mem_wdata = {mem_rdata_i[31:8], reg2_rdata_i[7:0]};
                            end
                            2'b01: begin
                                mem_wdata = {mem_rdata_i[31:16], reg2_rdata_i[7:0], mem_rdata_i[7:0]};
                            end
                            2'b10: begin
                                mem_wdata = {mem_rdata_i[31:24], reg2_rdata_i[7:0], mem_rdata_i[15:0]};
                            end
                            default: begin
                                mem_wdata = {reg2_rdata_i[7:0], mem_rdata_i[23:0]};
                            end
                        endcase
                    end
                    `INST_SH: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        reg_wdata = `ZeroWord;
                        mem_we = `WriteEnable;
                        mem_req = `RIB_REQ;
                        mem_waddr = op1_add_op2_res;
                        mem_raddr = op1_add_op2_res;
                        if (mem_waddr_index == 2'b00) begin
                            mem_wdata = {mem_rdata_i[31:16], reg2_rdata_i[15:0]};
                        end else begin
                            mem_wdata = {reg2_rdata_i[15:0], mem_rdata_i[15:0]};
                        end
                    end
                    `INST_SW: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        reg_wdata = `ZeroWord;
                        mem_we = `WriteEnable;
                        mem_req = `RIB_REQ;
                        mem_waddr = op1_add_op2_res;
                        mem_raddr = op1_add_op2_res;
                        mem_wdata = reg2_rdata_i;
                    end
                    default: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                    end
                endcase
            end
            `INST_TYPE_B: begin
                case (funct3)
                    `INST_BEQ: begin
                        hold_flag = `HoldDisable;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                        jump_flag = op1_eq_op2 & `JumpEnable;
                        jump_addr = {32{op1_eq_op2}} & op1_jump_add_op2_jump_res;
                    end
                    `INST_BNE: begin
                        hold_flag = `HoldDisable;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                        jump_flag = (~op1_eq_op2) & `JumpEnable;
                        jump_addr = {32{(~op1_eq_op2)}} & op1_jump_add_op2_jump_res;
                    end
                    `INST_BLT: begin
                        hold_flag = `HoldDisable;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                        jump_flag = (~op1_ge_op2_signed) & `JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `INST_BGE: begin
                        hold_flag = `HoldDisable;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                        jump_flag = (op1_ge_op2_signed) & `JumpEnable;
                        jump_addr = {32{(op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `INST_BLTU: begin
                        hold_flag = `HoldDisable;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                        jump_flag = (~op1_ge_op2_unsigned) & `JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    `INST_BGEU: begin
                        hold_flag = `HoldDisable;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                        jump_flag = (op1_ge_op2_unsigned) & `JumpEnable;
                        jump_addr = {32{(op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    default: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                    end
                endcase
            end
            `INST_JAL, `INST_JALR: begin
                hold_flag = `HoldDisable;
                mem_wdata = `ZeroWord;
                mem_raddr = `ZeroWord;
                mem_waddr = `ZeroWord;
                mem_we = `WriteDisable;
                jump_flag = `JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
                reg_wdata = op1_add_op2_res;
            end
            `INST_LUI, `INST_AUIPC: begin
                hold_flag = `HoldDisable;
                mem_wdata = `ZeroWord;
                mem_raddr = `ZeroWord;
                mem_waddr = `ZeroWord;
                mem_we = `WriteDisable;
                jump_addr = `ZeroWord;
                jump_flag = `JumpDisable;
                reg_wdata = op1_add_op2_res;
            end
            `INST_NOP_OP: begin
                jump_flag = `JumpDisable;
                hold_flag = `HoldDisable;
                jump_addr = `ZeroWord;
                mem_wdata = `ZeroWord;
                mem_raddr = `ZeroWord;
                mem_waddr = `ZeroWord;
                mem_we = `WriteDisable;
                reg_wdata = `ZeroWord;
            end
            `INST_FENCE: begin
                hold_flag = `HoldDisable;
                mem_wdata = `ZeroWord;
                mem_raddr = `ZeroWord;
                mem_waddr = `ZeroWord;
                mem_we = `WriteDisable;
                reg_wdata = `ZeroWord;
                jump_flag = `JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
            end
            `INST_CSR: begin
                jump_flag = `JumpDisable;
                hold_flag = `HoldDisable;
                jump_addr = `ZeroWord;
                mem_wdata = `ZeroWord;
                mem_raddr = `ZeroWord;
                mem_waddr = `ZeroWord;
                mem_we = `WriteDisable;
                case (funct3)
                    `INST_CSRRW: begin
                        csr_wdata_o = reg1_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRS: begin
                        csr_wdata_o = reg1_rdata_i | csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRC: begin
                        csr_wdata_o = csr_rdata_i & (~reg1_rdata_i);
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRWI: begin
                        csr_wdata_o = {27'h0, uimm};
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRSI: begin
                        csr_wdata_o = {27'h0, uimm} | csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRCI: begin
                        csr_wdata_o = (~{27'h0, uimm}) & csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    default: begin
                        jump_flag = `JumpDisable;
                        hold_flag = `HoldDisable;
                        jump_addr = `ZeroWord;
                        mem_wdata = `ZeroWord;
                        mem_raddr = `ZeroWord;
                        mem_waddr = `ZeroWord;
                        mem_we = `WriteDisable;
                        reg_wdata = `ZeroWord;
                    end
                endcase
            end
            default: begin
                jump_flag = `JumpDisable;
                hold_flag = `HoldDisable;
                jump_addr = `ZeroWord;
                mem_wdata = `ZeroWord;
                mem_raddr = `ZeroWord;
                mem_waddr = `ZeroWord;
                mem_we = `WriteDisable;
                reg_wdata = `ZeroWord;
            end
        endcase
    end

endmodule
