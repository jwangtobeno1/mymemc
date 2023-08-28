module array_ctrl #(
    parameter APB_DATA_WIDTH   = 32      ,
    parameter ARRAY_ROW_ADDR   = 14      ,
    parameter ARRAY_COL_ADDR   = 6       ,
    parameter ARRAY_DATA_WIDTH = 64      ,
    parameter MAX_ROW_ADDR     = 14'h3fff,
    parameter FRAME_DATA_WIDTH = 3 + ARRAY_ROW_ADDR + ARRAY_COL_ADDR + ARRAY_DATA_WIDTH
) (
    input                         clk               ,
    input                         rst_n             ,
    //connect to axi_slave
    input                         mc_frame_valid    ,
    output                        mc_frame_ready    ,
    input  [FRAME_DATA_WIDTH-1:0] mc_frame_data     ,
    output                        axi_array_rvalid  ,
    output [ARRAY_DATA_WIDTH-1:0] axi_array_rdata   ,
    // connect DRAM
    output                        array_banksel_n   ,
    output [ARRAY_ROW_ADDR-1:0]   array_raddr       ,
    output                        array_cas_wr      ,
    output [ARRAY_COL_ADDR-1:0]   array_caddr_wr    ,
    output                        array_wdata_rdy   ,
    output [ARRAY_DATA_WIDTH-1:0] array_wdata       ,
    output                        array_cas_rd      ,
    output [ARRAY_COL_ADDR-1:0]   array_caddr_rd    ,
    input                         array_rdata_rdy   ,
    input  [ARRAY_DATA_WIDTH-1:0] array_rdata       ,
    // connect to mc_apb_cfg
    input                         mc_en             ,
    input  [7:0]                  mc_trcd_cfg       ,
    input  [7:0]                  mc_tras_cfg       ,
    input  [7:0]                  mc_trp_cfg        ,
    input  [7:0]                  mc_twr_cfg        ,
    input  [7:0]                  mc_trtp_cfg       ,
    input  [7:0]                  mc_trc_cfg        ,
    input  [APB_DATA_WIDTH-1:0]   mc_refresh_period ,
    input  [APB_DATA_WIDTH-1:0]   mc_refresh_start  
);

    wire                        wr_end              ;
    wire                        rd_end              ;
    wire                        rfsh_end            ;
    wire                        frame_wr_valid      ;
    wire                        frame_wr_ready      ;
    wire [FRAME_DATA_WIDTH-1:0] frame_wr_data       ;
    wire [ARRAY_ROW_ADDR-1:0]   array_wr_raddr      ;
    wire                        array_wr_banksel_n  ;
    wire                        frame_rd_valid      ;
    wire                        frame_rd_ready      ;
    wire [FRAME_DATA_WIDTH-1:0] frame_rd_data       ;
    wire [ARRAY_ROW_ADDR-1:0]   array_rd_raddr      ;
    wire                        array_rd_banksel_n  ;
    wire                        rfsh_flag           ;
    wire [ARRAY_ROW_ADDR-1:0]   array_rfsh_raddr    ;
    wire                        array_rfsh_banksel_n;           

    array_fsm #(
        .ARRAY_ROW_ADDR         (ARRAY_ROW_ADDR     ),
        .ARRAY_COL_ADDR         (ARRAY_COL_ADDR     ),
        .ARRAY_DATA_WIDTH       (ARRAY_DATA_WIDTH   ),
        .FRAME_DATA_WIDTH       (FRAME_DATA_WIDTH   )
    ) array_fsm(
        .clk                    (clk                    ),
        .rst_n                  (rst_n                  ),
        .array_en               (mc_en                  ),
        .mc_frame_valid         (mc_frame_valid         ),
        .mc_frame_ready         (mc_frame_ready         ),
        .mc_frame_data          (mc_frame_data          ),
        .array_refresh_period   (mc_refresh_period      ),
        .array_refresh_start    (mc_refresh_start       ),
        .wr_end                 (wr_end                 ),
        .rd_end                 (rd_end                 ),
        .rfsh_end               (rfsh_end               ),
        .frame_wr_valid         (frame_wr_valid         ),
        .frame_wr_ready         (frame_wr_ready         ),
        .frame_wr_data          (frame_wr_data          ),
        .array_wr_raddr         (array_wr_raddr         ),
        .array_wr_banksel_n     (array_wr_banksel_n     ),
        .frame_rd_valid         (frame_rd_valid         ),
        .frame_rd_ready         (frame_rd_ready         ),
        .frame_rd_data          (frame_rd_data          ),
        .array_rd_raddr         (array_rd_raddr         ),
        .array_rd_banksel_n     (array_rd_banksel_n     ),
        .rfsh_flag              (rfsh_flag              ),
        .array_rfsh_raddr       (array_rfsh_raddr       ),
        .array_rfsh_banksel_n   (array_rfsh_banksel_n   ),
        .array_banksel_n        (array_banksel_n        ),
        .array_raddr            (array_raddr            )
    );

    array_w #(
        .ARRAY_ROW_ADDR         (ARRAY_ROW_ADDR         ),
        .ARRAY_COL_ADDR         (ARRAY_COL_ADDR         ),
        .ARRAY_DATA_WIDTH       (ARRAY_DATA_WIDTH       ),
        .FRAME_DATA_WIDTH       (FRAME_DATA_WIDTH       )  
    ) array_w(
        .clk                    (clk                    ),
        .rst_n                  (rst_n                  ),
        .frame_wr_valid         (frame_wr_valid         ),
        .frame_wr_data          (frame_wr_data          ),
        .frame_wr_ready         (frame_wr_ready         ),
        .array_banksel_n        (array_wr_banksel_n     ),
        .array_raddr            (array_wr_raddr         ),
        .array_cas_wr           (array_cas_wr           ),
        .array_caddr_wr         (array_caddr_wr         ),
        .array_wdata_rdy        (array_wdata_rdy        ),
        .array_wdata            (array_wdata            ),
        .wr_end                 (wr_end                 ),
        .array_trcd_cfg         (mc_trcd_cfg            ),
        .array_trp_cfg          (mc_trp_cfg             ),
        .array_twr_cfg          (mc_twr_cfg             ),
        .array_tras_cfg         (mc_tras_cfg            )
    );

    array_r #(
        .ARRAY_ROW_ADDR         (ARRAY_ROW_ADDR     ),
        .ARRAY_COL_ADDR         (ARRAY_COL_ADDR     ),
        .ARRAY_DATA_WIDTH       (ARRAY_DATA_WIDTH   ),
        .FRAME_DATA_WIDTH       (FRAME_DATA_WIDTH   )  
    ) array_r(
        .clk                    (clk                ),
        .rst_n                  (rst_n              ),
        .frame_rd_valid         (frame_rd_valid     ),
        .frame_rd_data          (frame_rd_data      ),
        .frame_rd_ready         (frame_rd_ready     ),
        .axi_array_rvalid       (axi_array_rvalid   ),
        .axi_array_rdata        (axi_array_rdata    ),   
        .array_banksel_n        (array_rd_banksel_n ),
        .array_raddr            (array_rd_raddr     ),
        .array_cas_rd           (array_cas_rd       ),
        .array_caddr_rd         (array_caddr_rd     ),
        .array_rdata_rdy        (array_rdata_rdy    ),
        .array_rdata            (array_rdata        ),
        .rd_end                 (rd_end             ),
        .array_trcd_cfg         (mc_trcd_cfg        ),
        .array_trp_cfg          (mc_trp_cfg         ),
        .array_trtp_cfg         (mc_trtp_cfg        ),
        .array_tras_cfg         (mc_tras_cfg        )
    );

    array_rfsh #(
        .ADDR_ROW_WIDTH    (ARRAY_ROW_ADDR      ),
        .MAX_ROW_ADDR      (MAX_ROW_ADDR        )
    ) array_rfsh(
        .clk               (clk                 ),
        .rst_n             (rst_n               ),
        .rfsh_flag         (rfsh_flag           ),
        .rfsh_end          (rfsh_end            ),
        .array_tras_cfg    (mc_tras_cfg         ),
        .array_trp_cfg     (mc_trp_cfg          ),
        .array_banksel_n   (array_rfsh_banksel_n),
        .array_raddr       (array_rfsh_raddr    )
    );
    
endmodule