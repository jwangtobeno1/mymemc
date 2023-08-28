module mc_top #(
    parameter AXI_ADDR_WIDTH   = 20         ,
    parameter AXI_DATA_WIDTH   = 64         ,
    parameter ARRAY_ROW_ADDR   = 14         ,
    parameter ARRAY_COL_ADDR   = 6          ,
    parameter ARRAY_DATA_WIDTH = 64         ,
    parameter APB_DATA_WIDTH   = 32         ,
    parameter APB_ADDR_WIDTH   = 32         ,
    parameter MAX_ROW_ADDR     = 14'h3fff
) (
    input                              clk              ,
    input                              rst_n            ,
    /*                 AXI interface                   
    	To do: 	add axi response channel; 需要在axi slave端加一个缓存
    			outstand,burst,out_of_order?	 
    */
    //Write addr
    input                              axi_awvalid      ,
    output                             axi_awready      ,
    input      [5:0]                   axi_awlen        ,
    input      [AXI_ADDR_WIDTH-1:0]    axi_awaddr       , 
    //Write data
    input                              axi_wvalid       ,
    output                             axi_wready       ,
    input                              axi_wlast        ,
    input      [AXI_DATA_WIDTH-1:0]    axi_wdata        ,
    //read addr
    input                              axi_arvalid      ,
    output                             axi_arready      ,
    input      [5:0]                   axi_arlen        ,
    input      [AXI_ADDR_WIDTH-1:0]    axi_araddr       ,
    //read data
    output                             axi_rvalid       ,
    output                             axi_rlast        ,
    output     [AXI_DATA_WIDTH-1:0]    axi_rdata        ,
    
    /*           array interface To DRAM               */
    output                             array_banksel_n  ,
    output     [ARRAY_ROW_ADDR-1:0]    array_raddr      ,
    // wdata
    output                             array_cas_wr     ,
    output     [ARRAY_COL_ADDR-1:0]    array_caddr_wr   ,
    output                             array_wdata_rdy  ,
    output     [ARRAY_DATA_WIDTH-1:0]  array_wdata      ,
    // rdata
    output                             array_cas_rd     ,
    output     [ARRAY_COL_ADDR-1:0]    array_caddr_rd   ,
    input                              array_rdata_rdy  ,
    input      [ARRAY_DATA_WIDTH-1:0]  array_rdata      ,
    /*       APB interface config  array_ctrl.v        */
    input                              apb_clk          ,
    input                              apb_rst_n        ,
    input                              apb_psel         ,
    input                              apb_penable      ,
    input                              apb_pwrite       ,
    input      [APB_ADDR_WIDTH-1:0]    apb_paddr        ,
    input      [APB_DATA_WIDTH-1:0]    apb_pwdata       ,
    output     [APB_DATA_WIDTH-1:0]    apb_prdata       ,
    output                             apb_pready       
);

    parameter FRAME_DATA_WIDTH = 3 + ARRAY_ROW_ADDR + ARRAY_COL_ADDR + ARRAY_DATA_WIDTH;

    wire                         mc_axi_frame_valid    ;
    wire                         mc_axi_frame_ready    ;
    wire [FRAME_DATA_WIDTH-1:0]  mc_axi_frame_data     ;
    wire                         mc_array_frame_valid  ;
    wire                         mc_array_frame_ready  ;
    wire [FRAME_DATA_WIDTH-1:0]  mc_array_frame_data   ;
    wire                         axi_array_rvalid      ;   
    wire [AXI_DATA_WIDTH-1:0]    axi_array_rdata       ;
    wire [7:0]                   mc_trcd_cfg           ;
    wire [7:0]                   mc_tras_cfg           ;
    wire [7:0]                   mc_trp_cfg            ;
    wire [7:0]                   mc_twr_cfg            ;
    wire [7:0]                   mc_trtp_cfg           ;
    wire [7:0]                   mc_trc_cfg            ;
    wire [APB_DATA_WIDTH-1:0]    mc_refresh_period     ;
    wire [APB_DATA_WIDTH-1:0]    mc_refresh_start      ; 

    axi_slave #(
        .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH  ),
        .AXI_DATA_WIDTH   (AXI_DATA_WIDTH  ),
        .ARRAY_ROW_ADDR   (ARRAY_ROW_ADDR  ),
        .ARRAY_COL_ADDR   (ARRAY_COL_ADDR  ),
        .ARRAY_DATA_WIDTH (ARRAY_DATA_WIDTH),
        .FRAME_DATA_WIDTH (FRAME_DATA_WIDTH)
    ) axi_slave(
        .clk              (clk                  ),
        .rst_n            (rst_n                ),
        .axi_awvalid      (axi_awvalid          ),
        .axi_awready      (axi_awready          ),
        .axi_awlen        (axi_awlen            ),
        .axi_awaddr       (axi_awaddr           ),  
        .axi_wvalid       (axi_wvalid           ),
        .axi_wready       (axi_wready           ),
        .axi_wlast        (axi_wlast            ),
        .axi_wdata        (axi_wdata            ),
        .axi_arvalid      (axi_arvalid          ),
        .axi_arready      (axi_arready          ),
        .axi_arlen        (axi_arlen            ),
        .axi_araddr       (axi_araddr           ),
        .axi_rvalid       (axi_rvalid           ),
        .axi_rlast        (axi_rlast            ),
        .axi_rdata        (axi_rdata            ),
        .mc_frame_valid   (mc_axi_frame_valid   ),
        .mc_frame_ready   (mc_axi_frame_ready   ),
        .mc_frame_data    (mc_axi_frame_data    ),
        .axi_array_rvalid (axi_array_rvalid     ),    
        .axi_array_rdata  (axi_array_rdata      )                   
    );

    flow_control_buffer #(
        .DATA_WIDTH   (FRAME_DATA_WIDTH),
        .BUFFER_DEPTH (2)
    ) flow_control_buffer(
        .clk        (clk                 ),
        .rst_n      (rst_n               ),
        .data_i     (mc_axi_frame_data   ),
        .valid_i    (mc_axi_frame_valid  ),
        .ready_i    (mc_axi_frame_ready  ),
        .valid_o    (mc_array_frame_valid),
        .data_o     (mc_array_frame_data ),
        .ready_o    (mc_array_frame_ready)
    );

    array_ctrl #(
        .APB_DATA_WIDTH   (APB_DATA_WIDTH  ),
        .ARRAY_ROW_ADDR   (ARRAY_ROW_ADDR  ),
        .ARRAY_COL_ADDR   (ARRAY_COL_ADDR  ),
        .ARRAY_DATA_WIDTH (ARRAY_DATA_WIDTH),
        .FRAME_DATA_WIDTH (FRAME_DATA_WIDTH),
        .MAX_ROW_ADDR     (MAX_ROW_ADDR    )
    ) array_ctrl(
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),
        .mc_frame_valid     (mc_array_frame_valid   ),
        .mc_frame_ready     (mc_array_frame_ready   ),
        .mc_frame_data      (mc_array_frame_data    ),
        .axi_array_rvalid   (axi_array_rvalid       ),
        .axi_array_rdata    (axi_array_rdata        ),
        .array_banksel_n    (array_banksel_n        ),
        .array_raddr        (array_raddr            ),
        .array_cas_wr       (array_cas_wr           ),
        .array_caddr_wr     (array_caddr_wr         ),
        .array_wdata_rdy    (array_wdata_rdy        ),
        .array_wdata        (array_wdata            ),
        .array_cas_rd       (array_cas_rd           ),
        .array_caddr_rd     (array_caddr_rd         ),
        .array_rdata_rdy    (array_rdata_rdy        ),
        .array_rdata        (array_rdata            ),
        .mc_en              (mc_en                  ),
        .mc_trcd_cfg        (mc_trcd_cfg            ),
        .mc_tras_cfg        (mc_tras_cfg            ),
        .mc_trp_cfg         (mc_trp_cfg             ),
        .mc_twr_cfg         (mc_twr_cfg             ),
        .mc_trtp_cfg        (mc_trtp_cfg            ),
        .mc_trc_cfg         (mc_trc_cfg             ),
        .mc_refresh_period  (mc_refresh_period      ),
        .mc_refresh_start   (mc_refresh_start       )
    );

    mc_apb_cfg #(
        .APB_DATA_WIDTH         (APB_DATA_WIDTH ),
        .APB_ADDR_WIDTH         (APB_ADDR_WIDTH ),
        .TIM_CFG                (8              )
    ) mc_apb_cfg(
        .apb_clk             (apb_clk          ),
        .apb_rst_n           (apb_rst_n        ),
        .apb_psel            (apb_psel         ),
        .apb_penable         (apb_penable      ),
        .apb_pwrite          (apb_pwrite       ),
        .apb_paddr           (apb_paddr        ),
        .apb_pwdata          (apb_pwdata       ),
        .apb_prdata          (apb_prdata       ),
        .apb_pready          (apb_pready       ),
        .mc_en               (mc_en            ),
        .mc_trcd_cfg         (mc_trcd_cfg      ),
        .mc_tras_cfg         (mc_tras_cfg      ),
        .mc_trp_cfg          (mc_trp_cfg       ),
        .mc_twr_cfg          (mc_twr_cfg       ),
        .mc_trtp_cfg         (mc_trtp_cfg      ),
        .mc_trc_cfg          (mc_trc_cfg       ),
        .mc_refresh_period   (mc_refresh_period),
        .mc_refresh_start    (mc_refresh_start )
    );

endmodule