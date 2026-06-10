`timescale 1ns / 1ps

module bridge #(
    parameter addr_width = 32,
    parameter data_width = 32,
    parameter id_width   = 4
)(
    input  wire                     clk,
    input  wire                     rst,

    // -------------------------------------------------
    // AXI SLAVE SIDE  (connect to your axi_master)
    // -------------------------------------------------
    // Write Address Channel
    input  wire [id_width-1:0]      awid,
    input  wire [addr_width-1:0]    awaddr,
    input  wire [7:0]               awlen,
    input  wire [2:0]               awsize,
    input  wire [1:0]               awburst,
    input  wire                     awvalid,
    output reg                      awready,

    // Write Data Channel
    input  wire [data_width-1:0]    wdata,
    input  wire [(data_width/8)-1:0] wstrb,
    input  wire                     wlast,
    input  wire                     wvalid,
    output reg                      wready,

    // Write Response Channel
    output reg [id_width-1:0]       bid,
    output reg [1:0]                bresp,
    output reg                      bvalid,
    input  wire                     bready,

    // Read Address Channel
    input  wire [id_width-1:0]      arid,
    input  wire [addr_width-1:0]    araddr,
    input  wire [7:0]               arlen,
    input  wire [2:0]               arsize,
    input  wire [1:0]               arburst,
    input  wire                     arvalid,
    output reg                      arready,

    // Read Data Channel
    output reg [id_width-1:0]       rid,
    output reg [data_width-1:0]     rdata,
    output reg [1:0]                rresp,
    output reg                      rvalid,
    output reg                      rlast,
    input  wire                     rready,

    // -------------------------------------------------
    // APB MASTER SIDE (connect to your apb_slave)
    // -------------------------------------------------
    output reg                      psel,
    output reg                      penable,
    output reg                      pwrite,
    output reg [addr_width-1:0]     paddr,
    output reg [data_width-1:0]     pwdata,
    output reg [(data_width/8)-1:0] pstrb,
    output reg [2:0]                pprot,

    input  wire [data_width-1:0]    prdata,
    input  wire                     pready,
    input  wire                     pslverr
);

    // -------------------------------------------------
    // State machine
    // -------------------------------------------------
    localparam S_IDLE      = 4'd0;

    localparam S_WR_ACCEPT  = 4'd1;
    localparam S_WR_SETUP   = 4'd2;
    localparam S_WR_ACCESS  = 4'd3;
    localparam S_WR_WAIT    = 4'd4;
    localparam S_WR_RESP    = 4'd5;

    localparam S_RD_SETUP   = 4'd6;
    localparam S_RD_ACCESS  = 4'd7;
    localparam S_RD_WAIT    = 4'd8;
    localparam S_RD_SEND    = 4'd9;

    reg [3:0] state;

    reg [addr_width-1:0] cur_addr;
    reg [7:0]            cur_len;
    reg [7:0]            beat_idx;
    reg [id_width-1:0]   cur_id;
    reg [2:0]            cur_size;

    reg                  wr_err;
    reg                  rd_err;

    reg [data_width-1:0] wr_buf;
    reg [(data_width/8)-1:0] wr_strb_buf;

    // address step = 1 << size (for your master this is 4 bytes)
    wire [addr_width-1:0] beat_step = ({{(addr_width-1){1'b0}}, 1'b1} << cur_size);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= S_IDLE;

            awready <= 1'b0;
            wready  <= 1'b0;
            arready <= 1'b0;

            bvalid  <= 1'b0;
            bresp   <= 2'b00;
            bid     <= {id_width{1'b0}};

            rvalid  <= 1'b0;
            rlast   <= 1'b0;
            rresp   <= 2'b00;
            rid     <= {id_width{1'b0}};
            rdata   <= {data_width{1'b0}};

            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            paddr   <= {addr_width{1'b0}};
            pwdata  <= {data_width{1'b0}};
            pstrb   <= {(data_width/8){1'b0}};
            pprot   <= 3'b000;

            cur_addr <= {addr_width{1'b0}};
            cur_len  <= 8'd0;
            beat_idx <= 8'd0;
            cur_id   <= {id_width{1'b0}};
            cur_size <= 3'd0;

            wr_err   <= 1'b0;
            rd_err   <= 1'b0;

            wr_buf   <= {data_width{1'b0}};
            wr_strb_buf <= {(data_width/8){1'b0}};
        end else begin
            case (state)

                // -------------------------------------------------
                // IDLE: accept either a write burst or a read burst
                // -------------------------------------------------
                S_IDLE: begin
                    awready <= 1'b1;
                    arready <= 1'b1;
                    wready  <= 1'b0;

                    psel    <= 1'b0;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;

                    bvalid  <= 1'b0;
                    rvalid  <= 1'b0;
                    rlast   <= 1'b0;

                    // Write has priority if both arrive together
                    if (awvalid && awready) begin
                        cur_addr <= awaddr;
                        cur_len  <= awlen;     // AXI len = last beat index
                        cur_id   <= awid;
                        cur_size <= awsize;
                        beat_idx <= 8'd0;
                        wr_err   <= (awburst != 2'b01); // assumed INCR, like your master
                        state    <= S_WR_ACCEPT;
                        awready  <= 1'b0;
                        arready  <= 1'b0;
                    end else if (arvalid && arready) begin
                        cur_addr <= araddr;
                        cur_len  <= arlen;     // AXI len = last beat index
                        cur_id   <= arid;
                        cur_size <= arsize;
                        beat_idx <= 8'd0;
                        rd_err   <= (arburst != 2'b01); // assumed INCR, like your master
                        state    <= S_RD_SETUP;
                        awready  <= 1'b0;
                        arready  <= 1'b0;
                    end
                end

                // -------------------------------------------------
                // WRITE CHANNEL
                // -------------------------------------------------
                S_WR_ACCEPT: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b1;

                    psel    <= 1'b0;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;

                    if (wvalid && wready) begin
                        wr_buf      <= wdata;
                        wr_strb_buf <= wstrb;

                        // APB setup phase will use these values
                        paddr   <= cur_addr;
                        pwdata  <= wdata;
                        pstrb   <= wstrb;
                        pprot   <= 3'b000;
                        pwrite  <= 1'b1;

                        wready  <= 1'b0;
                        state   <= S_WR_SETUP;
                    end
                end

                S_WR_SETUP: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b0;

                    psel    <= 1'b1;
                    penable <= 1'b0;
                    pwrite  <= 1'b1;
                    paddr   <= cur_addr;
                    pwdata  <= wr_buf;
                    pstrb   <= wr_strb_buf;
                    pprot   <= 3'b000;

                    state   <= S_WR_ACCESS;
                end

                S_WR_ACCESS: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b0;

                    psel    <= 1'b1;
                    penable <= 1'b1;
                    pwrite  <= 1'b1;
                    paddr   <= cur_addr;
                    pwdata  <= wr_buf;
                    pstrb   <= wr_strb_buf;
                    pprot   <= 3'b000;

                    // slave writes here on its clock edge
                    state   <= S_WR_WAIT;
                end

                S_WR_WAIT: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b0;

                    psel    <= 1'b0;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;

                    // wait one cycle for your APB slave's registered pready/prdata/pslverr
                    if (pready) begin
                        if (pslverr)
                            wr_err <= 1'b1;

                        if (beat_idx == cur_len) begin
                            bid    <= cur_id;
                            bresp  <= ((wr_err || pslverr) ? 2'b10 : 2'b00); // SLVERR / OKAY
                            bvalid <= 1'b1;
                            state  <= S_WR_RESP;
                        end else begin
                            beat_idx <= beat_idx + 1'b1;
                            cur_addr <= cur_addr + beat_step;
                            state    <= S_WR_ACCEPT;
                        end
                    end
                end

                S_WR_RESP: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b0;

                    psel    <= 1'b0;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;

                    bvalid  <= 1'b1;
                    bid     <= cur_id;
                    bresp   <= (wr_err ? 2'b10 : 2'b00);

                    if (bvalid && bready) begin
                        bvalid <= 1'b0;
                        state  <= S_IDLE;
                    end
                end

                // -------------------------------------------------
                // READ CHANNEL
                // -------------------------------------------------
                S_RD_SETUP: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b0;

                    psel    <= 1'b1;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;
                    paddr   <= cur_addr;
                    pprot   <= 3'b000;

                    state   <= S_RD_ACCESS;
                end

                S_RD_ACCESS: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b0;

                    psel    <= 1'b1;
                    penable <= 1'b1;
                    pwrite  <= 1'b0;
                    paddr   <= cur_addr;
                    pprot   <= 3'b000;

                    // slave captures read data here
                    state   <= S_RD_WAIT;
                end

                S_RD_WAIT: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b0;

                    psel    <= 1'b0;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;

                    if (pready) begin
                        rid   <= cur_id;
                        rdata <= prdata;
                        rresp <= (pslverr ? 2'b10 : 2'b00); // SLVERR / OKAY
                        rlast <= (beat_idx == cur_len);
                        rvalid <= 1'b1;
                        rd_err <= pslverr;
                        state  <= S_RD_SEND;
                    end
                end

                S_RD_SEND: begin
                    awready <= 1'b0;
                    arready <= 1'b0;
                    wready  <= 1'b0;

                    psel    <= 1'b0;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;

                    rvalid  <= 1'b1;
                    rid     <= cur_id;
                    rdata   <= rdata;
                    rresp   <= (rd_err ? 2'b10 : 2'b00);

                    if (rvalid && rready) begin
                        if (beat_idx == cur_len) begin
                            rvalid <= 1'b0;
                            rlast  <= 1'b0;
                            state  <= S_IDLE;
                        end else begin
                            rvalid   <= 1'b0;
                            rlast    <= 1'b0;
                            beat_idx <= beat_idx + 1'b1;
                            cur_addr <= cur_addr + beat_step;
                            state    <= S_RD_SETUP;
                        end
                    end
                end

                default: begin
                    state   <= S_IDLE;
                    awready <= 1'b0;
                    wready  <= 1'b0;
                    arready <= 1'b0;
                    bvalid  <= 1'b0;
                    rvalid  <= 1'b0;
                    rlast   <= 1'b0;
                    psel    <= 1'b0;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;
                    pprot   <= 3'b000;
                end
            endcase
        end
    end

endmodule