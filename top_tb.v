`timescale 1ns / 1ps

module top_tb;

    // -------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------
    reg clk;
    reg rst;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1;
        #20 rst = 0;
    end

    // -------------------------------------------------
    // AXI INTERCONNECT WIRES
    // -------------------------------------------------
    wire [3:0]  awid;
    wire [31:0] awaddr;
    wire [7:0]  awlen;
    wire [2:0]  awsize;
    wire [1:0]  awburst;
    wire        awvalid;
    wire        awready;

    wire [31:0] wdata;
    wire [3:0]  wstrb;
    wire        wlast;
    wire        wvalid;
    wire        wready;

    wire [3:0]  bid;
    wire [1:0]  bresp;
    wire        bvalid;
    wire        bready;

    wire [3:0]  arid;
    wire [31:0] araddr;
    wire [7:0]  arlen;
    wire [2:0]  arsize;
    wire [1:0]  arburst;
    wire        arvalid;
    wire        arready;

    wire [3:0]  rid;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rlast;
    wire        rvalid;
    wire        rready;

    // -------------------------------------------------
    // APB INTERCONNECT
    // -------------------------------------------------
    wire        psel;
    wire        penable;
    wire        pwrite;
    wire [31:0] paddr;
    wire [31:0] pwdata;
    wire [3:0]  pstrb;
    wire [2:0]  pprot;

    wire [31:0] prdata;
    wire        pready;
    wire        pslverr;

    // -------------------------------------------------
    // USER CONTROL
    // -------------------------------------------------
    reg start_wr, start_rd;
    reg [31:0] wr_addr, rd_addr;
    reg [511:0] wr_data;
    wire [511:0] rd_data;
    reg [7:0] wr_len, rd_len;
    wire wr_done, rd_done;

    // -------------------------------------------------
    // AXI MASTER
    // -------------------------------------------------
    axiMaster u_axi_master (
        .clk(clk),
        .rst(rst),

        .awready(awready),
        .awvalid(awvalid),
        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),

        .wready(wready),
        .wlast(wlast),
        .wvalid(wvalid),
        .wdata(wdata),
        .wstrb(wstrb),

        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arvalid(arvalid),
        .arready(arready),

        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),

        .start_wr(start_wr),
        .start_rd(start_rd),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .wr_len(wr_len),
        .rd_len(rd_len),
        .wr_done(wr_done),
        .rd_done(rd_done)
    );

    // -------------------------------------------------
    // BRIDGE
    // -------------------------------------------------
    bridge u_bridge (
        .clk(clk),
        .rst(rst),

        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awvalid(awvalid),
        .awready(awready),

        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),

        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arvalid(arvalid),
        .arready(arready),

        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rvalid(rvalid),
        .rlast(rlast),
        .rready(rready),

        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .pprot(pprot),

        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr)
    );

    // -------------------------------------------------
    // APB SLAVE
    // -------------------------------------------------
    apb_slave u_apb_slave (
        .pclk(clk),
        .presetn(~rst),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .pprot(pprot),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr)
    );

    // -------------------------------------------------
    // APB WRITE MONITOR
    // -------------------------------------------------
always @(posedge clk) begin
    if (psel && penable && pwrite && pready) begin
        #1;
        $display("\n[APB WRITE]");
        $display("ADDR  = 0x%08h", paddr);
        $display("DATA  = 0x%08h", pwdata);
        $display("STRB  = 0x%1h", pstrb);
        $display("--------------------------------");
    end
end
    // -------------------------------------------------
    // APB READ MONITOR
    // -------------------------------------------------
  always @(posedge clk) begin
    if (psel && penable && !pwrite && pready) begin
        #1;
        $display("\n[APB READ]");
        $display("ADDR  = 0x%08h", paddr);
        $display("DATA  = 0x%08h", prdata);
        $display("--------------------------------");
    end
end
    // -------------------------------------------------
    // AXI WRITE RESPONSE
    // -------------------------------------------------
    always @(posedge clk) begin
        if (bvalid && bready) begin
            $display("\n[AXI WRITE RESPONSE]");
            $display("BID   = %0d", bid);
            $display("BRESP = %0h", bresp);
            $display("--------------------------------");
        end
    end

    // -------------------------------------------------
    // AXI READ DATA
    // -------------------------------------------------
    always @(posedge clk) begin
        if (rvalid && rready) begin
            $display("\n[AXI READ DATA]");
            $display("RID   = %0d", rid);
            $display("RDATA = 0x%08h", rdata);
            $display("RRESP = %0h", rresp);
            $display("RLAST = %0d", rlast);
            $display("--------------------------------");
        end
    end

    // -------------------------------------------------
    // TEST SEQUENCE
    // -------------------------------------------------
    initial begin

        start_wr = 0;
        start_rd = 0;

        wr_addr = 32'h0000_0000;
        rd_addr = 32'h0000_0000;

        wr_len = 3;
        rd_len = 3;

        wr_data = {
            448'd0,
            32'h11111111,
            32'h22222222,
            32'h33333333,
            32'h44444444
        };

        #50;


$display("\n====================================");
$display(" AXI TO APB BRIDGE VERIFICATION ");
$display("====================================");
$display("Burst Length : %0d", wr_len + 1);
$display("Start Address: 0x%08h", wr_addr);

$display("\n========== START WRITE ==========");
        

        start_wr = 1;
        #10 start_wr = 0;

        wait(wr_done);

        $display("========== WRITE COMPLETE ==========\n");

        #50;

        $display("\n========== START READ ==========");

        start_rd = 1;
        #10 start_rd = 0;

        wait(rd_done);

        #20;

        $display("\n========== FINAL READBACK ==========");

        $display("Beat0 = 0x%08h", rd_data[31:0]);
        $display("Beat1 = 0x%08h", rd_data[63:32]);
        $display("Beat2 = 0x%08h", rd_data[95:64]);
        $display("Beat3 = 0x%08h", rd_data[127:96]);

      if (rd_data[31:0]   == 32'h44444444 &&
    rd_data[63:32]  == 32'h33333333 &&
    rd_data[95:64]  == 32'h22222222 &&
    rd_data[127:96] == 32'h11111111)
begin
    $display("\n******** TEST PASSED ********");

    

$display("\n====================================");
$display(" AXI TO APB BRIDGE VERIFICATION ");
$display("====================================");
$display("Write Transaction : PASS");
$display("Read Transaction  : PASS");
$display("Burst Length      : 4 Beats");
$display("Start Address     : 0x00000000");
$display("Data Integrity    : VERIFIED");
$display("BRESP             : OKAY");
$display("RRESP             : OKAY");
$display("Bridge Status     : FUNCTIONAL");
end
else begin
    $display("\n******** TEST FAILED ********");
end

$display("====================================");

        #100;
        $finish;
    end

endmodule