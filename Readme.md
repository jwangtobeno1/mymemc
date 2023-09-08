# Dram Controller

A Dram Controller

## Feature

This controller implements the read, write and refresh control of mem

- Array timing is configurable
- array refresh cycle is configurable
- Support AXI bus 2 Array bus
- Max 200Mhz

## Arch

![arch](./doc/img/arch.svg)

- Axi_Slave: axi bus to frame
- Array_Ctrl: the read, write and refresh control of mem
- MC_apb_cfg: configure internal registers

## Signals

### Global signal

|signal name | width | direction | description |
| -- | -- | -- | -- | 
|clk | 	1 |input | system clk，400MHz |
|rst_n	|1	|input	|system reset|


### AXI4 bus

|signal name | width | direction | description |
| -- | -- | -- | -- | 
|axi_awvalid	|1	|input 	|axi aw channel valid|
|axi_awready	|1	|output	|axi aw channel ready|
|axi_awlen	|6	|input	|axi aw channel len|
|axi_awaddr	|20	|input	|axi aw channel address|
|axi_wvalid	|1 	|input 	|axi w channel valid|
|axi_wready	|1	|output	|axi w channel ready|
|axi_wlast	|1	|input	|axi w channel last|
|axi_wdata	|64	|input	|axi w channel data|
|axi_arvalid	|1	|input	|axi ar channel valid|
|axi_arready	|1	|output	|axi ar channel ready|
|axi_arlen	|6	|input	|axi ar channel len|
|axi_araddr	|20	|input	|axi ar channel address|
|axi_rvalid	|1	|output	|axi r channel valid|
|axi_rlast	|1	|output	|axi r channel last|
|axi_rdata	|64	|output	|axi r channel data|

### APB bus

|signal name | width | direction | description |
| -- | -- | -- | -- | 
|apb_pclk	|1	|input	|apb clock|
|apb_prst_n	|1	|input	|apb reset|
|apb_psel	|1	|input	|apb select|
|apb_pwrite	|1	|input	|apb read/write indication|
|apb_paddr	|16	|input	|apb addr|
|apb_penable	|1	|input	|apb enable|
|apb_pwdata 	|32	|input	|apb write data|
|apb_pready	|1	|output	|apb ready|
|apb_prdata	|32	|output	|apb read data|

### Array interface

|signal name | width | direction | description |
| -- | -- | -- | -- | 
|array_banksel_n	|1	|output	|array bank select|
|array_raddr	|14	|output	|array row address|
|array_cas_wr	|1	|output	|array column address strobe for write|
|array_caddr_wr	|6	|output	|array column address for write|
|array_cas_rd	|1	|output	|array column address strobe for read|
|array_caddr_rd	|6	|output	|array column address for read|
|array_wdata_rdy	|1	|output	|array write data indication|
|array_wdata	|64	|output	|array write data|
|array_rdata_rdy	|1	|input	|array read data indication|
|array_rdata	|64	|input	|array read data|

## Timing

Write:

![](./doc/img/mc%20top%20write%20timing.png)

Read:

![](./doc/img/mc%20top%20read%20timing.png)

Refresh:

![](./doc/img/mc%20top%20refresh%20timing.png)