`timescale 1ns / 1ps







module axilite_s_v(
    // Global signal
    input  wire         s_axi_aclk,
    input  wire         s_axi_aresetn,

    // AW Channel
    input  wire         s_axi_awvalid,
    output reg          s_axi_awready,
    input  wire [31: 0] s_axi_awaddr,

    // W Channel
    input  wire         s_axi_wvalid,
    output reg          s_axi_wready,
    input  wire [31: 0] s_axi_wdata,

    // B Channel
    output reg          s_axi_bvalid,
    input  wire         s_axi_bready,
    output reg  [1: 0]  s_axi_bresp,

    // AR Channel
    input  wire         s_axi_arvalid,
    output reg          s_axi_arready,
    input  wire [31: 0] s_axi_araddr,

    // R Channel
    output reg          s_axi_rvalid,
    input  wire         s_axi_rready,
    output reg [31: 0]  s_axi_rdata,
    output reg  [1: 0]  s_axi_rresp
);

localparam idle            = 0, 
           send_wready     = 1,
           send_wdata      = 2,
           update_mem      = 3,
           send_wr_resp    = 4,
           send_wr_err     = 5,
           check_araddr    = 6,
           pop_data        = 7,
           send_rd_err     = 8;

reg [3:0] state      = idle;
reg [3:0] next_state = idle;
reg [1:0] count    = 0;
reg [31:0] waddr, raddr, wdata, rdata;

reg [31:0] mem [0:127];

always @(posedge s_axi_aclk) begin
    if (s_axi_aresetn == 1'b0) begin
        state <= idle;
        for (integer i = 0; i < 128; i=i+1) begin
            mem[i] <= 0;
        end
        s_axi_awready <= 0;
        s_axi_wready  <= 0;
        s_axi_bvalid  <= 0;
        s_axi_bresp   <= 0;
        s_axi_arready <= 0;
        s_axi_rvalid  <= 0;
        s_axi_rdata   <= 0;
        s_axi_rresp   <= 0;
        waddr         <= 0;
        raddr         <= 0;
        wdata         <= 0;
        rdata         <= 0;
    end else begin
        case (state)
            idle: begin
                s_axi_awready <= 0;
                s_axi_wready  <= 0;
                s_axi_bvalid  <= 0;
                s_axi_bresp   <= 0;
                s_axi_arready <= 0;
                s_axi_rvalid  <= 0;
                s_axi_rdata   <= 0;
                s_axi_rresp   <= 0;
                waddr         <= 0;
                raddr         <= 0;
                wdata         <= 0;
                rdata         <= 0;
                count         <= 0;
                s_axi_rvalid  <= 1'b0;
                
                if (s_axi_awvalid == 1'b1) begin
                    state         <= send_wready;
                    waddr         <= s_axi_awaddr;
                    s_axi_awready <= 1'b1;
                end else if (s_axi_arvalid == 1'b1) begin
                    state         <= check_araddr;
                    raddr         <= s_axi_araddr;
                    s_axi_arready <= 1'b1;
                end else begin
                    state         <= idle;
                end
            end
            
            send_wready: begin
                s_axi_awready <= 1'b0;
                if (s_axi_wvalid) begin
                    wdata        <= s_axi_wdata;
                    s_axi_wready <= 1'b1;
                    state        <= send_wdata;
                end else begin
                    state        <= send_wready;
                end
            end

            send_wdata: begin
                s_axi_wready <= 1'b0;
                if (waddr < 128) begin
                    state      <= update_mem;
                    mem[waddr] <= wdata;
                end else begin
                    state        <= send_wr_err;
                    s_axi_bresp  <= 2'b11;
                    s_axi_bvalid <= 1'b1;
                end
            end

            update_mem: begin
                mem[waddr] <= wdata;
                state      <= send_wr_resp;
            end

            send_wr_resp: begin
                s_axi_bresp  <= 2'b00;
                s_axi_bvalid <= 1'b1;
                if (s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    state <= idle;
                end else begin
                    state <= send_wr_resp;
                end
            end

            send_wr_err: begin
                if (s_axi_bready) begin
                    state <= idle;
                end else begin
                    state <= send_wr_err;
                end
            end
////////////////////////// write complete
            check_araddr: begin
                s_axi_arready <= 1'b0;
                if (raddr < 128) begin
                    state <= pop_data;
                end else begin
                    s_axi_rvalid <= 1'b1;  
                    state        <= send_rd_err;
                    s_axi_rdata  <= 0;
                    s_axi_rresp  <= 2'b11;
                end
            end

            pop_data: begin
                if (count < 2) begin
                    rdata <= mem[raddr];
                    state <= pop_data;
                    count <= count + 1;
                end else begin
                    s_axi_rvalid <= 1'b1;  
                    s_axi_rdata  <= rdata; 
                    s_axi_rresp  <= 2'b00;
                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        s_axi_rdata  <= 0;
                        state <= idle;
                    end else begin
                        state <= pop_data;
                    end
                end
            end

            send_rd_err: begin
                if (s_axi_rready) begin
                    state <= idle;
                end else begin
                    state <= send_rd_err;
                end
            end

            default: state <= idle;
        endcase
    end
end

endmodule
 

module axilite_m_v(
    // Global signal
    input  wire        m_axi_aclk,
    input  wire        m_axi_aresetn,

    // AW Channel
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,
    output reg [31: 0] m_axi_awaddr,
 
    // W Channel
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,
    output reg [31: 0] m_axi_wdata,
 
    // B Channel
    input  wire       m_axi_bvalid,
    output reg        m_axi_bready,
    input  [1: 0]     m_axi_bresp,
 
    // AR Channel
    output reg         m_axi_arvalid,
    input   wire       m_axi_arready,
    output reg [31: 0] m_axi_araddr,
 
    // R Channel
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready,
    input wire [31: 0] m_axi_rdata,
    input wire [1: 0]  m_axi_rresp,

    // user signal
    input wire write,
    input wire read,
    input wire [31:0] user_waddr,
    input wire [31:0] user_wdata,
    input wire [31:0] user_raddr,
    output reg [31:0] user_rdata,
    output reg wr_error,
    output reg rd_error,
    output reg wr_ready,
    output reg rd_ready 
);

localparam idle            = 0, 
           send_awvalid    = 1,
           send_wvalid     = 2,
           send_bready     = 3,
           rcv_wr_err      = 4,
           send_arvalid    = 5,
           rcv_arready     = 6,
           send_rready     = 7,
           send_rdata      = 8,
           rcv_rd_err      = 9;

           
reg [3:0] state      = idle;
reg [3:0] next_state = idle;
reg [31:0] waddr, raddr, wdata, rdata;
reg wr_flag, rd_flag; 
reg [31:0] mem [0:127];

always @(posedge m_axi_aclk) begin
    if (m_axi_aresetn == 1'b0) begin
        state <= idle;
        for (integer i = 0; i < 128; i = i + 1) begin
            mem[i] <= 0;
        end
        m_axi_awvalid  <= 0;
        m_axi_awaddr   <= 0;
        m_axi_wvalid   <= 0;
        m_axi_wdata    <= 0;
        m_axi_bready   <= 0;
        m_axi_arvalid  <= 0;
        m_axi_araddr   <= 0;
        m_axi_rready   <= 0;
        user_rdata     <= 0;
        wr_flag        <= 0;
        rd_flag        <= 0;
        waddr          <= 0;
        raddr          <= 0;
        wdata          <= 0;
        rdata          <= 0;
        wr_error       <= 0;
        rd_error       <= 0;
        wr_ready       <= 0;
        rd_ready       <= 0;
    end else begin
        case (state)
        idle: begin
            m_axi_awvalid  <= 0;
            m_axi_awaddr   <= 0;
            m_axi_wvalid   <= 0;
            m_axi_wdata    <= 0;
            m_axi_bready   <= 0;
            m_axi_arvalid  <= 0;
            m_axi_araddr   <= 0;
            m_axi_rready   <= 0;
            user_rdata     <= 0;
            wr_flag        <= 0;
            rd_flag        <= 0;
            waddr          <= 0;
            raddr          <= 0;
            wdata          <= 0;
            rdata          <= 0;
            wr_error       <= 0;
            rd_error       <= 0;
            wr_ready       <= 0;
            rd_ready       <= 0;
            
            if (write == 1'b1) begin
                wr_flag   <= 1'b1;
                waddr     <= user_waddr; 
                wdata     <= user_wdata;
                state     <= send_awvalid;
            end else if (read == 1'b1) begin
                rd_flag   <= 1'b1;
                raddr     <= user_raddr;
                state     <= send_arvalid;
            end else begin
                state     <= idle;
            end
        end
        
        send_awvalid: begin
            if (wr_flag == 1'b1) begin
                wr_flag       <= 1'b0;
                m_axi_awvalid <= 1'b1;
                m_axi_awaddr  <= waddr;
                state <= send_wvalid;
            end
                else begin
                    state <= send_awvalid;
                end
            
        end

        // W channel
        send_wvalid: begin
          if (m_axi_awready == 1'b1) begin
                m_axi_awvalid <= 1'b0;
                m_axi_wvalid  <= 1'b1;
                m_axi_awaddr  <= 0;
            m_axi_wdata  <= wdata;
            end 
            if (m_axi_wready == 1'b1) begin
                m_axi_wvalid <= 1'b0;
                m_axi_wdata  <= 0;
                state <= send_bready;
            end
        end

        send_bready: begin
            if (m_axi_bvalid == 1'b1) begin
                m_axi_bready <= 1'b1;

                if (m_axi_bresp == 2'b00) begin
                    wr_ready     <= 1'b1;
                    state <= idle; 
                end 
                else if (m_axi_bresp == 2'b11) begin
                    state <= rcv_wr_err; 
                end 
                else begin 
                    state <= send_bready;  // m_axi_brespê°? ?•ˆ ?˜¨ ê²½ìš°
                end
            end 
            else begin
                state <= send_bready;  // m_axi_bvalidê°? 0?´ë©? ê³„ì† ??ê¸?
            end
        end


        rcv_wr_err : begin
          if(m_axi_bvalid == 1'b1) begin
          wr_error    <= 1'b1;
          wr_ready    <= 1'b1;
          state       <= idle;
          end
        end

//////////////////////////////////write complete
        send_arvalid: begin
            if (rd_flag == 1'b1) begin
                rd_flag       <= 1'b0;
                m_axi_arvalid <= 1'b1;
                m_axi_araddr  <= raddr;
                state <= rcv_arready;
            end 
            else state <= idle;
        end

        rcv_arready: begin
                if (m_axi_arready == 1'b1) begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_araddr  <= 0;
                    state         <= send_rready;
                end else begin
                    state <= rcv_arready;
                end
        end

        send_rready: begin
            if (m_axi_rvalid == 1'b1) begin
                m_axi_rready <= 1'b1;
                rdata <= m_axi_rdata;
                if(m_axi_rresp == 2'b00) begin
                    state <= send_rdata;
                end 
                else if (m_axi_rresp == 2'b11) begin
                    state <= rcv_rd_err;
                end
                else begin
                    state <= send_rready;
                end
            end 
            
            else begin
                state <= send_rready;
            end
        end

        send_rdata: begin
            m_axi_rready <= 1'b0;
            rd_ready <= 1'b1;
            user_rdata <= rdata;
            state <= idle;
        end


        rcv_rd_err : begin
            rd_error <= 1'b1;
            rd_ready <= 1'b1;
            state       <= idle;
        end

        default: state <= idle; 

        endcase
    end
end

endmodule









