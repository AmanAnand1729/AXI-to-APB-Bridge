# AXI-to-APB-Bridge
Verilog implementation of an AMBA AXI4-to-APB3 bridge with support for AXI burst transactions, APB3 peripheral access, address translation, error propagation, and end-to-end verification using self-checking testbenches.

# AXI4 to APB3 Bridge

## Overview

This project implements an **AMBA AXI4 to APB3 Bridge** in Verilog RTL. The bridge enables communication between high-performance AXI4 masters and low-power APB3 peripherals by translating AXI4 read/write transactions into APB3-compatible transfers.

The design supports AXI4 burst transactions, address translation, protocol conversion, response generation, and error propagation while maintaining compliance with the AXI4 and APB3 protocols.

---

## Architecture

```text
+-------------+
| AXI4 Master |
+-------------+
       |
       | AXI4 Interface
       v
+------------------+
|  AXI4-APB3       |
|     Bridge       |
+------------------+
       |
       | APB3 Interface
       v
+-------------+
| APB3 Slave  |
+-------------+
```

---

## Features

- AXI4 Slave Interface
- APB3 Master Interface
- AXI4 Read Transaction Support
- AXI4 Write Transaction Support
- Burst-to-Single Transfer Conversion
- INCR Burst Handling
- AXI Address and Data Channel Support
- APB Setup and Access Phase Generation
- AXI BRESP and RRESP Response Generation
- PSLVERR to AXI Error Propagation
- Parameterizable Address and Data Widths
- Fully Synthesizable Verilog RTL
- Verification Testbench Included

---

## Directory Structure

```text
AXI4_APB3_Bridge/
│
├── rtl/
│   ├── axiMaster.v
│   ├── apbSlave.v
│   ├── bridge.v
│
├── tb/
│   └── top_tb.v

└── README.md
```

---

## Verification

The design has been verified using simulation testbenches covering:

- Single Write Transactions
- Single Read Transactions
- Burst Write Transactions
- Burst Read Transactions
- Address Translation
- APB Protocol Timing
- Response Generation
- Error Handling

---

## Applications

- SoC Peripheral Access
- Microcontroller Subsystems
- Low-Power Peripheral Integration
- AMBA-Based Embedded Systems
- FPGA Prototyping and Verification

---

## Contributors

- Aman Anand
- Ashish Kumar Das

---

## License

This project is licensed under the MIT License.
