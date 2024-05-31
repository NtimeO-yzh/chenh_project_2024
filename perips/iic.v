module iic(
    input clk,
    input rst,
    input wire                    we_i,
    input wire[31:0]            addr_i,
    input wire[31:0]            data_i,
    output [31:0]              data_o,
    inout sda,
    output reg scl

    // output [7:0]pointer_tb,
    // output [15:0]data_tb,
    // output [7:0]address_tb
);
parameter   [3:0] idle =4'd0,
                 start=4'd1,
                 address=4'd2,
                 addack=4'd3,
                 pointer=4'd4,
                 pointerack=4'd5,
                 read15to8=4'd6,
                 readack=4'd7,
                 read7to0=4'd8,
                 nack=4'd9,
                 stop=4'd10,
                 write15to8=4'd11,
                 write7to0=4'd12,
                 writeack=4'd13,
                 writeack2=4'd14;

reg [3:0]state;
reg [7:0]address_reg; 
reg [7:0]pointer_reg;
reg sda_reg;
reg sda_link;
reg [15:0]data_reg;
reg [8:0]count1;
reg [3:0]data_count;
reg [24:0]count2;
reg ptr_write; 
wire rd;//控制是对从寄存器读还是写
wire [1:0] pointer_bit;
assign sda= sda_link ?sda_reg:1'bz;
// assign data_tb=data_reg;
// assign address_tb=address_reg;
// assign pointer_tb=pointer_reg;
//////设置iic内部寄存器
    localparam Islave_addr = 8'h1;
    localparam Idata_o = 8'h2;
    localparam Idata_i = 8'h3;
    localparam Iic_status = 8'h4;
    reg [31:0] iic_status; 
    reg[31:0] islave_addr,idata_o,idata_i;
    reg[2:0]                      cnt;  
    reg[7:0]                      cnt_delay;    
    reg                           scl_r;  
    // 主设备写寄存器
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            idata_i <= 32'h0;
            islave_addr<= 32'h0;
        end else begin
            if (we_i == 1'b1) begin
                case (addr_i[23:16])
                    Idata_i: begin
                        idata_i <= data_i;
                        islave_addr[6:0] <= data_i[7:1];
                    end
                    Islave_addr: begin
                        islave_addr <= data_i;
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
                    idata_o[15:0] = data_reg;
                end
                Iic_status: begin
                    idata_o = iic_status;
                end
                default: begin
                    idata_o = 32'h0;
                end
            endcase
        end
    end  
//count1 : 跟随clk，500最多
always @(posedge clk) begin
    if(rst) begin
        count1<=9'd0;
    end
    else if(count1==9'd199) begin
        count1<=9'd0;
    end
    else 
       count1<=count1+1'b1;
end

//scl :周期500clk
always @(posedge clk ) begin
    if(rst) begin
        scl<=1'b0;
    end
    else if (count1==9'd99) begin
        scl<=1'b0;
    end
    else if (count1==9'd199) begin
        scl<=1'b1;
    end
    else 
      scl<=scl;
end

//
assign rd = idata_i[29];
assign pointer_bit = idata_i[31:30];
always @(posedge clk ) begin
    
if(rst) begin
        data_count<=4'd0;
        address_reg <= 8'b00000000;
        pointer_reg <= 8'd0;
        state<= idle;
        sda_link<=1'b1;    
        sda_reg<=1'b1;
        ptr_write<=idata_i[8];   
        count2<=25'd0;
        iic_status <= 32'b1;
    end

else begin
    if(rd) begin //开始read
        case (state)
        idle: 
        begin
            iic_status[0] <= 1;
            sda_link<=1;    
            sda_reg<=1;     
            if (count2==25'd4_999) begin
                count2<=25'd0;
                state<=start;
            end

            else begin
                count2<=count2+1'b1;
                state<=idle;
            end
        end
    //-----------------------------------------------------------------------------------------------------------
        start: begin
                if(count1==9'd49) begin     
                sda_reg<=1'b0;
                sda_link=1'b1;
                state<=address;
                data_count<=4'd0;
                if(ptr_write)
                    address_reg<={islave_addr[7:1],1'b0};
                else
                    address_reg<={islave_addr[7:1],1'b1};
            end
            else begin
                state<=start;
            end
        end
    //-----------------------------------------------------------------------------------------------------------
            address: begin
                if (count1==9'd149) begin
                    if (data_count==4'd8) begin
                        state<=addack;
                        data_count<=4'd0;
                        sda_reg<=1'b1;
                        sda_link<=1'b0;   
                    end
                    else begin  
                        state<=address;  
                        case(data_count)
                            4'd0: sda_reg <= address_reg[7];
                            4'd1: sda_reg <= address_reg[6];
                            4'd2: sda_reg <= address_reg[5];
                            4'd3: sda_reg <= address_reg[4];
                            4'd4: sda_reg <= address_reg[3];
                            4'd5: sda_reg <= address_reg[2];
                            4'd6: sda_reg <= address_reg[1];
                            4'd7: sda_reg <= address_reg[0];
                            default: ;
                        endcase
                        data_count<=data_count+1'b1;     
                    end
                    
                end
                else 
                state<=address;
            end
    //-----------------------------------------------------------------------------------------------------------
            addack: begin
                if (!sda && count1==9'd49) begin
                    if (ptr_write==1) begin //***********read TOS,TEMP,THY with pointer*************//
                        state<=pointer;
                        pointer_reg<={6'b000000,pointer_bit}; //setting to reading tos register
                        sda_link<=1'b1;
                        sda_reg<=1'b0;
                        data_count<=4'd0;
                    end
                    else if((pointer_bit == 2'b01) && (address_reg[7:4]==4'b1001)) begin//read 1 byte data
                        state<=read7to0;
                    end else begin
                        state<=read15to8;//***********read without pointer*************//
                    end
                end

                else if(count1 ==9'd99) begin
                    if (ptr_write==1) begin
                        state<=pointer;
                        pointer_reg<={6'b000000,pointer_bit}; //setting to reading tos register
                        sda_link<=1'b1;
                        sda_reg<=1'b0;
                        data_count<=4'd0;
                    end
                    else if((pointer_bit == 2'b01) & &(address_reg[7:4]==4'b1001)) begin
                        state<=read7to0;
                    end else begin
                        state<=read15to8;//***********read without pointer*************//read 1 byte data
                    end
                end
            end 
    //-----------------------------------------------------------------------------------------------------------    
            pointer: begin//把8位数据给pointer_reg
                if(count1==9'd149) begin
                    if(data_count==4'd8) begin
                    state<=pointerack;
                    sda_link<=1'b0;
                    sda_reg<=1'b1;
                    data_count<=4'd0;
                    end
                
                    else begin
                        state<=pointer;
                        data_count<=data_count+1'b1;
                        case(data_count)
                                4'd0: sda_reg <= pointer_reg[7];
                                4'd1: sda_reg <= pointer_reg[6];
                                4'd2: sda_reg <= pointer_reg[5];
                                4'd3: sda_reg <= pointer_reg[4];
                                4'd4: sda_reg <= pointer_reg[3];
                                4'd5: sda_reg <= pointer_reg[2];
                                4'd6: sda_reg <= pointer_reg[1];
                                4'd7: sda_reg <= pointer_reg[0];
                                default: ;
                            endcase
                    end
                end
            else
            state<=pointer;

            end
    //-------------------------------------------------------------------------------------------------------------- 
        pointerack: begin //pointer之后的rs，但是不虚写了，真的读了
            if(!sda && count1==9'd49) begin
                ptr_write<=1'b0; 
                state<=start;
            end
            else if( count1==9'd99) begin
                ptr_write<=1'b0;
                state<=start;
            end
            else 
            state<=pointerack;
        end
    //-----------------------------------------------------------------------------------------------------------------
        read15to8: begin
            if(count1==9'd149 && data_count==4'd8) begin
                state<=readack;
                data_count<=0;
                sda_link<=1'b1;
                sda_reg<=1'b1;
            end

            else if (count1==29'd49) begin   
                state<=read15to8;
                data_count<=data_count+1;
                case(data_count)
                4'd0: data_reg[15] <= sda;
                4'd1: data_reg[14] <= sda;
                4'd2: data_reg[13] <= sda;
                4'd3: data_reg[12] <= sda;
                4'd4: data_reg[11] <= sda;
                4'd5: data_reg[10] <= sda;
                4'd6: data_reg[9] <= sda;
                4'd7: data_reg[8] <= sda;
                default: ;
                endcase
            end
            else 
            state<=read15to8;
        end
    //-----------------------------------------------------------------------------------------------------------------
        readack: begin
            if(count1==9'd149) begin
                sda_reg<=1'b0;
            end
            else if( count1==9'd99) begin   
                state<=read7to0;
                sda_reg<=1'b1;
                sda_link<=1'b0;
                data_count<=4'd0;
            end
            else 
            state<=readack;
        end
    //-----------------------------------------------------------------------------------------------------------------
        read7to0: begin
            if(count1==9'd149 && data_count==4'd8) begin
                state<=nack;
                data_count<=1'b0;
                sda_link<=1'b1;
                sda_reg<=1'b1;
            end

            else if (count1==9'd49) begin
                state<=read7to0;
                data_count<=data_count+1;
                case(data_count)
                4'd0: data_reg[7] <= sda;
                4'd1: data_reg[6] <= sda;
                4'd2: data_reg[5] <= sda;
                4'd3: data_reg[4] <= sda;
                4'd4: data_reg[3] <= sda;
                4'd5: data_reg[2] <= sda;
                4'd6: data_reg[1] <= sda;
                4'd7: data_reg[0] <= sda;
                default: ;
                endcase
            end
            else 
            state<=read7to0;
        end
    //-----------------------------------------------------------------------------------------------------------------
        nack: begin
            if (count1==9'd149) begin
                sda_reg<=1'b0;
                state<=stop;
            end

            else
            state<=nack;
        end
    //-----------------------------------------------------------------------------------------------------------------
        stop: begin
            iic_status[0] <= 0;
            if(count1==9'd49) begin    
                sda_reg<=1'b1;
                state<=idle;
            end
            else
            state<=stop;
        end
    //-----------------------------------------------------------------------------------------------------------------
    endcase
    end
else begin
    case (state)

       idle: 
       begin
         sda_link<=1;    
         sda_reg<=1;     
         if (count2==25'd4_999) begin
            count2<=25'd0;
            state<=start;
         end

         else begin
            count2<=count2+1'b1;
            state<=idle;
         end
       end
//-----------------------------------------------------------------------------------------------------------
       start: begin

        if(count1==9'd49)  
            begin    
                sda_reg<=1'b0;
                sda_link=1'b1;
                state<=address;
                data_count<=4'd0;
                address_reg<={islave_addr[7:1],1'b0};
            end

        else begin
            state<=start;
        end
       end
//-----------------------------------------------------------------------------------------------------------
        address: begin
            if (count1==9'd149) begin
                if (data_count==4'd8) begin
                    state<=addack;
                    data_count<=4'd0;
                    sda_reg<=1'b1;
                    sda_link<=1'b0;   
                end
                else begin  
                    state<=address;   
                    case(data_count)
                        4'd0: sda_reg <= address_reg[7];
                        4'd1: sda_reg <= address_reg[6];
                        4'd2: sda_reg <= address_reg[5];
                        4'd3: sda_reg <= address_reg[4];
                        4'd4: sda_reg <= address_reg[3];
                        4'd5: sda_reg <= address_reg[2];
                        4'd6: sda_reg <= address_reg[1];
                        4'd7: sda_reg <= address_reg[0];
                        default: ;
                    endcase
                    data_count<=data_count+1'b1;     
                end
                
            end
            else 
              state<=address;
        end
//-----------------------------------------------------------------------------------------------------------
        addack: begin

            if (!sda && count1==9'd49) begin
                    state<=pointer;
                    pointer_reg<={6'b000000,pointer_bit};  
                    sda_link<=1'b1;
                    sda_reg<=1'b0;
                    data_count<=4'd0;
             end

            else if(  count1 ==9'd99) begin
                    state<=pointer;
                    pointer_reg<={6'b000000,pointer_bit};  
                    sda_link<=1'b1;
                    sda_reg<=1'b0;
                    data_count<=4'd0;
                end
                
            
             else 
                state<=addack;
        end
//-----------------------------------------------------------------------------------------------------------    
        pointer: begin
            if(count1==9'd149) begin
                if(data_count==4'd8) begin
                 state<=pointerack;
                 sda_link<=1'b0;
                 sda_reg<=1'b1;
                 data_count<=4'd0;
                end
            
            else begin
                state<=pointer;
                data_count<=data_count+1'b1;
                 case(data_count)
                        4'd0: sda_reg <= pointer_reg[7];
                        4'd1: sda_reg <= pointer_reg[6];
                        4'd2: sda_reg <= pointer_reg[5];
                        4'd3: sda_reg <= pointer_reg[4];
                        4'd4: sda_reg <= pointer_reg[3];
                        4'd5: sda_reg <= pointer_reg[2];
                        4'd6: sda_reg <= pointer_reg[1];
                        4'd7: sda_reg <= pointer_reg[0];
                        default: ;
                    endcase
            end
        end
            else
               state<=pointer;

        end
//-------------------------------------------------------------------------------------------------------------- 
     pointerack: begin
        if(!sda && count1==9'd49) begin
            data_reg<=idata_i[15:0];
           state<=write15to8;
           sda_link<=1'b1;
        end
         else if(  count1==9'd99) begin
            data_reg<=idata_i[15:0];
            state<=write15to8;
            sda_link<=1'b1;
        end
        else 
           state<=pointerack;
     end
//-----------------------------------------------------------------------------------------------------------------
     write15to8: begin
        if(count1==9'd149 && data_count==4'd8) begin
            state<=writeack;
            data_count<=4'b0;
            sda_link<=1'b0;
            sda_reg<=1'b1;
         end

         else if (count1==9'd149) begin    
            state<=write15to8;
            data_count<=data_count+1;
            case(data_count)
            4'd0: sda_reg <= data_reg[15];
            4'd1: sda_reg <= data_reg[14];
            4'd2: sda_reg <= data_reg[13];
            4'd3: sda_reg <= data_reg[12];
            4'd4: sda_reg <= data_reg[11];
            4'd5: sda_reg <= data_reg[10];
            4'd6: sda_reg <= data_reg[9];
            4'd7: sda_reg <= data_reg[8];
            default: ;
            endcase
         end
        else 
         state<=write15to8;
     end
//-----------------------------------------------------------------------------------------------------------------
     writeack: begin
        if(count1==9'd49 && !sda) begin
            state<=write7to0;
            sda_link<=1'b1;
        end
        else if( count1==9'd99) begin   
            state<=write7to0;
            sda_link<=1'b1;
        end
         else 
         state<=writeack;
     end
//-----------------------------------------------------------------------------------------------------------------
      write7to0: begin
        if(count1==9'd149 && data_count==4'd8) begin
            state<=writeack2;
            data_count<=4'b0;
            sda_link<=1'b0;
            sda_reg<=1'b1;
         end

         else if (count1==9'd149) begin    
            state<=write7to0;
            data_count<=data_count+1;
            case(data_count)
            4'd0: sda_reg <= data_reg[7];
            4'd1: sda_reg <= data_reg[6];
            4'd2: sda_reg <= data_reg[5];
            4'd3: sda_reg <= data_reg[4];
            4'd4: sda_reg <= data_reg[3];
            4'd5: sda_reg <= data_reg[2];
            4'd6: sda_reg <= data_reg[1];
            4'd7: sda_reg <= data_reg[0];
            default: ;
            endcase
         end
        else 
         state<=write7to0;
     end
//-----------------------------------------------------------------------------------------------------------------
      writeack2: begin
        if(count1==9'd49 && !sda) begin
            state<=stop;
            sda_link<=1'b1;
        end
        else if( count1==9'd99 ) begin   
            state<=stop;
            sda_link<=1'b1;
        end
         else 
         state<=writeack2;
     end
//-----------------------------------------------------------------------------------------------------------------
       stop: begin
        if(count1==9'd49) begin     
            sda_reg<=1'b1;
            state<=idle;
        end
        else
          state<=stop;
       end
//-----------------------------------------------------------------------------------------------------------------
   endcase
end
    end
end


endmodule