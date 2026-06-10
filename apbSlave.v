`timescale 1ns / 1ps
module apb_slave #(
    parameter base_addr = 32'h0000_0000
)(
    input         pclk,
    input         presetn,
    input         psel,
    input         penable,
    input         pwrite,
    input  [31:0] paddr,
    input  [31:0] pwdata,
    input  [3:0]  pstrb,
    input  [2:0]  pprot,
    output reg [31:0] prdata,
    output reg        pready,
    output reg        pslverr
);

    // 4 × 32-bit register file
    reg [31:0] regfile [0:3];
    wire [1:0] reg_sel    = paddr[3:2];
    wire       addr_valid = (paddr[31:4] == base_addr[31:4]);

    // SINGLE-CYCLE READY
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pready <= 0;
        end else begin
            pready <= (psel && penable);  
        end
    end

    // ERROR FLAG
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pslverr <= 0;
        end else if (psel && penable) begin
            pslverr <= ~addr_valid;
        end else begin
            pslverr <= 0;
        end
    end

    // WRITE (with PSTRB)
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            regfile[0] <= 0;
            regfile[1] <= 0;
            regfile[2] <= 0;
            regfile[3] <= 0;
        end else if (psel && penable && pwrite && addr_valid) begin
            if (pstrb[0]) regfile[reg_sel][7:0]   <= pwdata[7:0];
            if (pstrb[1]) regfile[reg_sel][15:8]  <= pwdata[15:8];
            if (pstrb[2]) regfile[reg_sel][23:16] <= pwdata[23:16];
            if (pstrb[3]) regfile[reg_sel][31:24] <= pwdata[31:24];
        end
    end

    // READ
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            prdata <= 0;
        end else if (psel && penable && !pwrite && addr_valid) begin
            prdata <= regfile[reg_sel];
        end
    end

endmodule