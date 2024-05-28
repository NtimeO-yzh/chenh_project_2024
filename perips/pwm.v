
module pwm(

	input wire clk,
	input wire rst,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,

    output reg[31:0] data_o,
	output wire pw_pin0,pw_pin1,pw_pin2,pw_pin3

    );


    reg pw_reg0,pw_reg1,pw_reg2,pw_reg3;

    localparam A_0 = 8'h0;
    localparam A_1 = 8'h1;
    localparam A_2 = 8'h2;
    localparam A_3 = 8'h3;
    localparam B_0 = 8'h10;
    localparam B_1 = 8'h11;
    localparam B_2 = 8'h12;
    localparam B_3 = 8'h13;
    localparam C = 8'h4;


    reg[31:0] a_0,a_1,a_2,a_3,b_0,b_1,b_2,b_3,c;
    reg[31:0] count_0,count_1,count_2,count_3;
    wire [31:0] m;
    assign m = 100000;

    assign pw_pin0 = pw_reg0;
    assign pw_pin1 = pw_reg1;
    assign pw_pin2 = pw_reg2;
    assign pw_pin3 = pw_reg3;

    // 写寄存器
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            a_0 <= 32'h0;
            a_1 <= 32'h0;
            a_2 <= 32'h0;
            a_3 <= 32'h0;
            b_0 <= 32'h0;
            b_1 <= 32'h0;
            b_2 <= 32'h0;
            b_3 <= 32'h0;
            c <= 32'h0;
        end else begin
            if (we_i == 1'b1) begin
                case (addr_i[23:16])
                    A_0: begin
                        a_0 <= data_i;
                    end
                    A_1: begin
                        a_1 <= data_i;
                    end
                    A_2: begin
                        a_2 <= data_i;
                    end
                    A_3: begin
                        a_3 <= data_i;
                    end
                    B_0: begin
                        b_0 <= data_i;
                    end
                    B_1: begin
                        b_1 <= data_i;
                    end
                    B_2: begin
                        b_2 <= data_i;
                    end
                    B_3: begin
                        b_3 <= data_i;
                    end
                    C: begin
                        c <= data_i;
                    end
                endcase
            end 
        end
    end

    // 读寄存器
    always @ (*) begin
        if (rst == 1'b0) begin
            data_o = 32'h0;
        end else begin
            case (addr_i[23:16])
                A_0: begin
                    data_o = a_0;
                end
                A_1: begin
                    data_o = a_1;
                end
                A_2: begin
                    data_o = a_2;
                end
                A_3: begin
                    data_o = a_3;
                end
                B_0: begin
                    data_o = b_0;
                end
                B_1: begin
                    data_o = b_1;
                end
                B_2: begin
                    data_o = b_2;
                end
                B_3: begin
                    data_o = b_3;
                end
                C: begin
                    data_o = c;
                end
            endcase
        end
    end

    // 发�?�脉�??

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            pw_reg0 <= 0;
            count_0 <= 0;
        end else begin
            if (c[0] == 0) begin
                pw_reg0 <= 0;
            end else begin
                if (we_i == 1'b1) begin
                    if (count_0 < b_0) begin
                        if (addr_i[23:16]!=B_0)begin
                            pw_reg0 <= 1; 
                            count_0 <= count_0 + 1;
                        end
                        else begin
                            if (count_0 < data_i) begin
                                pw_reg0 <= 1;
                                count_0 <= count_0 + 1;
                            end else begin
                                pw_reg0 <= 0;
                                count_0 <= data_i;
                            end
                        end
                    end else if(count_0 < a_0) begin
                        if (addr_i[23:16]!=a_0)begin
                            pw_reg0 <= 0; 
                            count_0 <= count_0 + 1;
                        end
                        else begin
                            if (count_0 < data_i) begin
                                pw_reg0 <= 0;
                                count_0 <= count_0 + 1;
                            end else begin
                                pw_reg0 <= 1;
                                count_0 <= 0;
                            end
                        end
                    end else begin
                            pw_reg0 <= 1; 
                            count_0 <= 0;
                    end
                end else begin
                    if (count_0 < b_0/m) begin
                        pw_reg0 <= 1;
                        count_0 <= count_0 + 1;
                    end else begin
                        if (count_0 < a_0/m) begin
                            pw_reg0 <= 0;
                            count_0 <= count_0 + 1;
                        end else begin
                            pw_reg0 <= 1;
                            count_0 <= 0;
                        end
                    end
                end
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            pw_reg1 <= 0;
            count_1 <= 0;
        end else begin
            if (c[0] == 0) begin
                pw_reg1 <= 0;
            end else begin
                if (we_i == 1'b1) begin
                    if (count_1 < b_1) begin
                        if (addr_i[23:16]!=B_1)begin
                            pw_reg1 <= 1; 
                            count_1 <= count_1 + 1;
                        end
                        else begin
                            if (count_1 < data_i) begin
                                pw_reg1 <= 1;
                                count_1 <= count_1 + 1;
                            end else begin
                                pw_reg1 <= 0;
                                count_1 <= data_i;
                            end
                        end
                    end else if(count_1 < a_1) begin
                        if (addr_i[23:16]!=a_1)begin
                            pw_reg1 <= 0; 
                            count_1 <= count_1 + 1;
                        end
                        else begin
                            if (count_1 < data_i) begin
                                pw_reg1 <= 0;
                                count_1 <= count_1 + 1;
                            end else begin
                                pw_reg1 <= 1;
                                count_1 <= 0;
                            end
                        end
                    end else begin
                            pw_reg1 <= 1; 
                            count_1 <= 0;
                    end
                end else begin
                    if (count_1 < b_1/m) begin
                        pw_reg1 <= 1;
                        count_1 <= count_1 + 1;
                    end else begin
                        if (count_1 < a_1/m) begin
                            pw_reg1 <= 0;
                            count_1 <= count_1 + 1;
                        end else begin
                            pw_reg1 <= 1;
                            count_1 <= 0;
                        end
                    end
                end
            end
        end
    end
    
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            pw_reg2 <= 0;
            count_2 <= 0;
        end else begin
            if (c[0] == 0) begin
                pw_reg2 <= 0;
            end else begin
                if (we_i == 1'b1) begin
                    if (count_2 < b_2) begin
                        if (addr_i[23:16]!=B_2)begin
                            pw_reg2 <= 1; 
                            count_2 <= count_2 + 1;
                        end
                        else begin
                            if (count_2 < data_i) begin
                                pw_reg2 <= 1;
                                count_2 <= count_2 + 1;
                            end else begin
                                pw_reg2 <= 0;
                                count_2 <= data_i;
                            end
                        end
                    end else if(count_2 < a_2) begin
                        if (addr_i[23:16]!=a_2)begin
                            pw_reg2 <= 0; 
                            count_2 <= count_2 + 1;
                        end
                        else begin
                            if (count_2 < data_i) begin
                                pw_reg2 <= 0;
                                count_2 <= count_2 + 1;
                            end else begin
                                pw_reg2 <= 1;
                                count_2 <= 0;
                            end
                        end
                    end else begin
                            pw_reg2 <= 1; 
                            count_2 <= 0;
                    end
                end else begin
                    if (count_2 < b_2/m) begin
                        pw_reg2 <= 1;
                        count_2 <= count_2 + 1;
                    end else begin
                        if (count_2 < a_2/m) begin
                            pw_reg2 <= 0;
                            count_2 <= count_2 + 1;
                        end else begin
                            pw_reg2 <= 1;
                            count_2 <= 0;
                        end
                    end
                end
            end
        end
    end
    
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            pw_reg3 <= 0;
            count_3 <= 0;
        end else begin
            if (c[0] == 0) begin
                pw_reg3 <= 0;
            end else begin
                if (we_i == 1'b1) begin
                    if (count_3 < b_3) begin
                        if (addr_i[23:16]!=B_3)begin
                            pw_reg3 <= 1; 
                            count_3 <= count_3 + 1;
                        end
                        else begin
                            if (count_3 < data_i) begin
                                pw_reg3 <= 1;
                                count_3 <= count_3 + 1;
                            end else begin
                                pw_reg3 <= 0;
                                count_3 <= data_i;
                            end
                        end
                    end else if(count_3 < a_3) begin
                        if (addr_i[23:16]!=a_3)begin
                            pw_reg3 <= 0; 
                            count_3 <= count_3 + 1;
                        end
                        else begin
                            if (count_3 < data_i) begin
                                pw_reg3 <= 0;
                                count_3 <= count_3 + 1;
                            end else begin
                                pw_reg3 <= 1;
                                count_3 <= 0;
                            end
                        end
                    end else begin
                            pw_reg3 <= 1; 
                            count_3 <= 0;
                    end
                end else begin
                    if (count_3 < b_3/m) begin
                        pw_reg3 <= 1;
                        count_3 <= count_3 + 1;
                    end else begin
                        if (count_3 < a_3/m) begin
                            pw_reg3 <= 0;
                            count_3 <= count_3 + 1;
                        end else begin
                            pw_reg3 <= 1;
                            count_3 <= 0;
                        end
                    end
                end
            end
        end
    end
    
endmodule
