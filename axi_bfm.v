`timescale 1ns / 1ps










module bfm (
    input  wire        clk,
    input  wire        resetn,

    // user signal
    output reg write,
    output reg read,
    output reg [31:0] user_waddr,
    output reg [31:0] user_wdata,
    output reg [31:0] user_raddr,
    input  wire [31:0] user_rdata,
    input  wire wr_ready,
    input  wire rd_ready,
    input  wire [14:0] sw,
    input  wire sw15,
    output reg [15:0] led
);



    wire wr_rd;
    assign wr_rd = sw15 ? 1 : 0;

    always @(posedge clk) begin
        if(resetn == 1'b0) begin

            write       <= 1'b0;
            read        <= 1'b0;
            user_waddr  <= 32'h0;
            user_wdata  <= 32'h0;
            user_raddr  <= 32'h0;
            led         <= 16'b0;
        end 
        else begin
            if (wr_rd == 1'b1) begin

                write      <= 1'b1;
                user_waddr <= 32'h0;        
                user_wdata <= {17'b0, sw};   
            end
            
            if (wr_ready) begin
               
                write      <= 1'b0;
                user_waddr <= 32'h0;
            end

            if (wr_rd == 1'b0) begin
              
                read       <= 1'b1;
                user_raddr <= 32'h0;
                
                if (rd_ready) begin
                   
                    led <= user_rdata[15:0]; 
                end
            end
        end
    end
endmodule
