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

// 除法模块
// 试商法实现32位整数除法
// 每次除法运算至少需要33个时钟周期才能完成
module send_jump_flag(

    input wire clk,
    input wire rst,

    // from ex
    input wire start_i,                  // 开始信号，运算期间这个信号需要一直保持有效

    // to ex
    output reg[7:0] result_o,        // 除法结果，高32位是余数，低32位是商
    output reg busy_o,                  // 正在运算信号
    );

    // 状态定义


    // 状态机实现
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin

        end
        else begin
          
        end
    end

endmodule
