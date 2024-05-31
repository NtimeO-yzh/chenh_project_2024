`include "../core/defines.v"
module iic
(
    input                          clk,
    input                          rst,
    input wire                    we_i,
    input wire[31:0]            addr_i,
    input wire[31:0]            data_i,
    output [31:0]              data_o,
    //to LP75
    output                         scl, 
    inout                          sda
); 

    localparam Islave_addr = 8'h1;
    localparam Idata_o = 8'h2;
    localparam Idata_i = 8'h3;
    reg[31:0] islave_addr,idata_o,idata_i;
    reg[2:0]                      cnt;  
    reg[7:0]                      cnt_delay;    
    reg                           scl_r;  
    
    // wire reg[16:0]              data;
    // 主设备写寄存器
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            idata_i <= 32'h0;
        end else begin
            if (we_i == 1'b1) begin
                case (addr_i[23:16])
                    Idata_i: begin
                        idata_i <= data_i;
                    end
                    Idata_i: begin
                        idata_i <= data_i;
                    end
                    default : begin
                        idata_i <= 32'h0;
                    end
                endcase
            end 
        end
    end

    // 主设备读寄存器
    always @ (*) begin
        if (rst == 1'b0) begin
            idata_o = 32'h0;
        end else begin
            case (addr_i[23:16])
                Idata_o: begin
                    idata_o = idata_o;
                end
                default: begin
                    idata_o = 32'h0;
                end
            endcase
        end
    end  
    //从设备写“读寄存器”//
    //时钟计数
    always @ (posedge clk or negedge rst)
    begin
        if(!rst) 
            cnt_delay <= 8'd0;
        else if(cnt_delay == 8'd199) 
            cnt_delay <= 8'd0;   
        else 
            cnt_delay <= cnt_delay+1'b1;
    end
    //分频后的计数器，0，1，2，3循环
    always @ (posedge clk or negedge rst) 
    begin
        if(!rst) cnt <= 3'd5;
        else begin
            case (cnt_delay)
                9'd49:     cnt <= 3'd1;
                9'd99:     cnt <= 3'd2; 
                9'd149:    cnt <= 3'd3;  
                9'd199:    cnt <= 3'd0; 
                default:   cnt <= 3'd5;
                endcase
            end
    end
    //再分频后的时钟，分频计数器0，1为1；2，3为0
    always @ (posedge clk or negedge rst)
    begin
        if(!rst) 
            scl_r <= 1'b0;
        else if(cnt==3'd0) 
            scl_r <= 1'b1;
        else if(cnt==3'd2) 
            scl_r <= 1'b0;
    end
    assign scl = scl_r;   
    //状态机部分            
    reg[7:0]                 db_r;    
    reg[15:0]                read_data;  
    parameter     IDLE      = 4'd0;
    parameter     START     = 4'd1;
    parameter     ADDR      = 4'd2;
    parameter     ACK1      = 4'd3;
    parameter     DATA1     = 4'd4;
    parameter     ACK2      = 4'd5;
    parameter     DATA2     = 4'd6;
    parameter     NACK      = 4'd7;
    parameter     STOP      = 4'd8;

    reg[3:0]                 cstate;    
    reg                      sda_r; 
    reg                      sda_link;         
    reg[3:0]                 num;  
    reg[25:0]                tim;           //count
    always @ (posedge clk or negedge rst) 
    begin
        if(!rst) 
            tim<=26'd0;
        else 
            tim<=tim+1'b1;
    end

    always @ (posedge clk or negedge rst) 
    begin
    if(!rst) begin
            cstate <= IDLE;
            sda_r <= 1'b1;
            sda_link <= 1'b0;
            num <= 4'd0;
            read_data <= 16'd0;
        end
    else       
        case (cstate)
            IDLE:    begin
                    sda_link <= 1'b1;    
                    sda_r <= 1'b1;
                    if(tim[25]) begin 
                        db_r <= islave_addr; 
                        cstate <= START;        
                        end
                    else cstate <= IDLE;  
                end
            START: 
            begin  
            if(`SCL_HIG)
                begin
                        sda_link <= 1'b1;  
                        sda_r <= 1'b0;        
                        cstate <= ADDR;
                        num <= 4'd0;
                        end
                    else cstate<=START;
                end
            ADDR:    begin
                    if(`SCL_LOW) begin
                            if(num == 4'd8) begin    
                                    num <= 4'd0; 
                                    sda_r <= 1'b1;
                                    sda_link <= 1'b0;  
                                    cstate <= ACK1;
                                end
                            else begin
                                    cstate <= ADDR;
                                    num <= num+1'b1;
                                    case (num)
                                        4'd0: sda_r <= db_r[7];
                                        4'd1: sda_r <= db_r[6];
                                        4'd2: sda_r <= db_r[5];
                                        4'd3: sda_r <= db_r[4];
                                        4'd4: sda_r <= db_r[3];
                                        4'd5: sda_r <= db_r[2];
                                        4'd6: sda_r <= db_r[1];
                                        4'd7: sda_r <= db_r[0];
                                        default: ;
                                        endcase
                                end
                        end
                    else cstate <= ADDR;
                end
            ACK1: begin 
                    if(!sda_r &&(`SCL_HIG))
                    begin
                    cstate<=DATA1;
                    end
                    else if(`SCL_NEG)
                    begin
                    cstate<=DATA1;
                    end
                    else cstate <= ACK1;
                    end
            DATA1:  begin
                            if(`SCL_HIG) begin
                                    num <= num+1'b1;    
                                    case (num)
                                        4'd0: read_data[15] <= sda;
                                        4'd1: read_data[14] <= sda;  
                                        4'd2: read_data[13] <= sda; 
                                        4'd3: read_data[12] <= sda; 
                                        4'd4: read_data[11] <= sda; 
                                        4'd5: read_data[10] <= sda; 
                                        4'd6: read_data[9]  <= sda; 
                                        4'd7: read_data[8]  <= sda; 
                                        default: ;
                                        endcase                                                          
                                    end
                            else if((`SCL_NEG) && (num==4'd8)) begin
                                num <= 4'd0;
                                sda_link <= 1'b1;    
                                sda_r<=1'b1;
                                cstate <= ACK2;
                                end
                            else cstate <= DATA1;
                    end    
            ACK2: begin
                    if(`SCL_LOW) begin
                    sda_r <= 1'b0; 
                        end
                    else if(`SCL_NEG)begin 
                        cstate <= DATA2;
                        sda_link <= 1'b0; 
                        sda_r<=1'b1;    
                end    
                    else cstate <= ACK2;
                end
            DATA2:    begin
                                        
                        if(`SCL_HIG) begin    
                                num <= num+1'b1;    
                                case (num)
                                    4'd0: read_data[7] <= sda;
                                    4'd1: read_data[6] <= sda;  
                                    4'd2: read_data[5] <= sda; 
                                    4'd3: read_data[4] <= sda; 
                                    4'd4: read_data[3] <= sda; 
                                    4'd5: read_data[2] <= sda; 
                                    4'd6: read_data[1] <= sda; 
                                    4'd7: read_data[0] <= sda; 
                                    default: ;
                                    endcase                                                                     
                            end
                        else if((`SCL_LOW) && (num==4'd8)) begin
                            num <= 4'd0; 
                            sda_link <= 1'b1;       
                            sda_r<=1'b1;        
                            cstate <= NACK;
                            end
                        else cstate <= DATA2;
            end    
            
            NACK: begin
                    if(`SCL_LOW) begin
                    sda_r <= 1'b0; 
                    cstate <= STOP;                    
                        end
                    else cstate <= NACK;
                end                
            STOP:  begin if(`SCL_HIG) begin
                    sda_r <= 1'b1;
                    cstate <= IDLE;
                    end
                    else cstate <= STOP;end
            default: cstate <= IDLE;
            endcase
    end

    assign sda = sda_link ? sda_r:1'bz;
    assign data_o[15:0] = read_data;//只要求读取数据，没要求显示在管子上，而且只需要读八位

    // wire [15:0]             data_conv;
    // wire[31:0]              data_conv1;
    // wire[31:0]              data_conv2;
    // assign data_conv = read_data[15] ? ~read_data[15:0]+1'b1 : read_data[15:0];
    // assign data_conv1=data_conv*125;
    // assign data_conv2=data_conv1/3200;//(1/8)32
    // //sign+转换后的数据
    // always @ (posedge clk or negedge rst)
    // begin 
    //     if(!rst) 
    //         data<=17'd0;
    //     else 
    //         data <={read_data[15],data_conv2[15:0]};
    // end
    endmodule