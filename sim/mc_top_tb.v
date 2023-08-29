module   mc_top_tb;

    parameter AXI_ADDR_WIDTH   = 20     ;
    parameter AXI_DATA_WIDTH   = 64     ;
    parameter ARRAY_ROW_ADDR   = 14     ;
    parameter ARRAY_COL_ADDR   = 6      ;
    parameter ARRAY_DATA_WIDTH = 64     ;
    parameter APB_DATA_WIDTH   = 32     ;
    parameter APB_ADDR_WIDTH   = 32     ;
    parameter MAX_ROW_ADDR     = 14'h8  ;

    reg                              clk              ;
    reg                              rst_n            ;
    reg                              axi_awvalid      ;
    wire                             axi_awready      ;
    reg      [5:0]                   axi_awlen        ;
    reg      [AXI_ADDR_WIDTH-1:0]    axi_awaddr       ;
    reg                              axi_wvalid       ;
    wire                             axi_wready       ;
    reg                              axi_wlast        ;
    reg      [AXI_DATA_WIDTH-1:0]    axi_wdata        ;
    reg                              axi_arvalid      ;
    wire                             axi_arready      ;
    reg      [5:0]                   axi_arlen        ;
    reg      [AXI_ADDR_WIDTH-1:0]    axi_araddr       ;
    wire                             axi_rvalid       ;
    wire                             axi_rlast        ;
    wire     [AXI_DATA_WIDTH-1:0]    axi_rdata        ;
    wire                             array_banksel_n  ;
    wire     [ARRAY_ROW_ADDR-1:0]    array_raddr      ;
    wire                             array_cas_wr     ;
    wire     [ARRAY_COL_ADDR-1:0]    array_caddr_wr   ;
    wire                             array_wdata_rdy  ;
    wire     [ARRAY_DATA_WIDTH-1:0]  array_wdata      ;
    wire                             array_cas_rd     ;
    wire     [ARRAY_COL_ADDR-1:0]    array_caddr_rd   ;
    reg                              array_rdata_rdy  ;
    reg      [ARRAY_DATA_WIDTH-1:0]  array_rdata      ;
    reg                              apb_clk          ;
    reg                              apb_rst_n        ;
    reg                              apb_psel         ;
    reg                              apb_penable      ;
    reg                              apb_pwrite       ;
    reg      [APB_ADDR_WIDTH-1:0]    apb_paddr        ;
    reg      [APB_DATA_WIDTH-1:0]    apb_pwdata       ;
    wire     [APB_DATA_WIDTH-1:0]    apb_prdata       ;
    wire                             apb_pready       ;

mc_top #(
    .AXI_ADDR_WIDTH       (AXI_ADDR_WIDTH  ),
    .AXI_DATA_WIDTH       (AXI_DATA_WIDTH  ),
    .ARRAY_ROW_ADDR       (ARRAY_ROW_ADDR  ),
    .ARRAY_COL_ADDR       (ARRAY_COL_ADDR  ),
    .ARRAY_DATA_WIDTH     (ARRAY_DATA_WIDTH),
    .APB_DATA_WIDTH       (APB_DATA_WIDTH  ),
    .APB_ADDR_WIDTH       (APB_ADDR_WIDTH  ),
    .MAX_ROW_ADDR         (MAX_ROW_ADDR    )
) mc_top(
    .clk              (clk            ),
    .rst_n            (rst_n          ),
    .axi_awvalid      (axi_awvalid    ),
    .axi_awready      (axi_awready    ),
    .axi_awlen        (axi_awlen      ),
    .axi_awaddr       (axi_awaddr     ),  
    .axi_wvalid       (axi_wvalid     ),
    .axi_wready       (axi_wready     ),
    .axi_wlast        (axi_wlast      ),
    .axi_wdata        (axi_wdata      ),
    .axi_arvalid      (axi_arvalid    ),
    .axi_arready      (axi_arready    ),
    .axi_arlen        (axi_arlen      ),
    .axi_araddr       (axi_araddr     ),
    .axi_rvalid       (axi_rvalid     ),
    .axi_rlast        (axi_rlast      ),
    .axi_rdata        (axi_rdata      ),
    .array_banksel_n  (array_banksel_n),
    .array_raddr      (array_raddr    ),
    .array_cas_wr     (array_cas_wr   ),
    .array_caddr_wr   (array_caddr_wr ),
    .array_wdata_rdy  (array_wdata_rdy),
    .array_wdata      (array_wdata    ),
    .array_cas_rd     (array_cas_rd   ),
    .array_caddr_rd   (array_caddr_rd ),
    .array_rdata_rdy  (array_rdata_rdy),
    .array_rdata      (array_rdata    ),
    .apb_clk          (apb_clk        ),
    .apb_rst_n        (apb_rst_n      ),
    .apb_psel         (apb_psel       ),
    .apb_penable      (apb_penable    ),
    .apb_pwrite       (apb_pwrite     ),
    .apb_paddr        (apb_paddr      ),
    .apb_pwdata       (apb_pwdata     ),
    .apb_prdata       (apb_prdata     ),
    .apb_pready       (apb_pready     )
);

    always #5 clk = ~clk;

    always #6 apb_clk = ~apb_clk;

    initial begin
        rst_n = 0;
        #28
        rst_n = 1;
    end

    initial begin
        apb_rst_n = 0;
        #28
        apb_rst_n = 1;
    end

    initial begin
        clk = 0;
        axi_awvalid = 0;
        axi_awlen = 0;  
        axi_awaddr = 0;
        axi_wvalid = 0;
        axi_wlast = 0;  
        axi_wdata = 0;   
        axi_arvalid = 0;  
        axi_arlen = 0;   
        axi_araddr = 0;  
        array_rdata_rdy = 1;
        array_rdata = 0;
        apb_clk = 0;                  
        apb_psel = 0;         
        apb_penable = 0;      
        apb_pwrite = 0;       
        apb_paddr = 0;        
        apb_pwdata = 0;           
    end

    initial begin
        register_config;
        axi_wr_single;
        axi_wr_more;
        axi_rd_single;
        axi_rd_more;
        axi_wr_valid_unconst;
        repeat(600) @(posedge clk);
        $finish();
    end

    task register_config;
        begin
            #30;
            @(posedge apb_clk) begin
                apb_psel   <= 1;
                apb_pwrite <= 1;
                apb_paddr  <= 4;
                apb_pwdata <= {8'd7,8'd7,8'd17,8'd8};  
            end 
            @(posedge apb_clk) begin
                apb_penable <= 1;
            end
            wait(apb_pready) begin
                @(posedge apb_clk);
                apb_psel <= 0;
                apb_penable <= 0;
            end
            @(posedge apb_clk) begin
                apb_psel   <= 1;
                apb_pwrite <= 1;
                apb_paddr  <= 8;
                apb_pwdata <= {8'd0,8'd0,8'd23,8'd5};  
            end 
            @(posedge apb_clk) begin
                apb_penable <= 1;
            end
            wait(apb_pready) begin
                @(posedge apb_clk);
                apb_psel <= 0;
                apb_penable <= 0;
            end
            @(posedge apb_clk) begin
                apb_psel   <= 1;
                apb_pwrite <= 1;
                apb_paddr  <= 12;
                apb_pwdata <= 32'd480;  
            end 
            @(posedge apb_clk) begin
                apb_penable <= 1;
            end
            wait(apb_pready) begin
                @(posedge apb_clk);
                apb_psel <= 0;
                apb_penable <= 0;
            end
            @(posedge apb_clk) begin
                apb_psel   <= 1;
                apb_pwrite <= 1;
                apb_paddr  <= 16;
                apb_pwdata <= 32'd240;  
            end 
            @(posedge apb_clk) begin
                apb_penable <= 1;
            end
            wait(apb_pready) begin
                @(posedge apb_clk);
                apb_psel <= 0;
                apb_penable <= 0;
            end
            @(posedge apb_clk) begin
                apb_psel   <= 1;
                apb_pwrite <= 1;
                apb_paddr  <= 0;
                apb_pwdata <= {31'd0,1'd1};  
            end 
            @(posedge apb_clk) begin
                apb_penable <= 1;
            end
            wait(apb_pready) begin
                @(posedge apb_clk);
                apb_psel <= 0;
                apb_penable <= 0;
            end    
        end
    endtask

    task axi_wr_single;
        begin
            repeat(5) @(posedge clk);
            axi_awvalid <= 1;
            axi_awlen   <= 1;
            axi_awaddr  <= 33;
            wait(axi_awready); 
            @(posedge clk) begin
                axi_wvalid <= 1;
                axi_wlast  <= 1;
                axi_wdata  <= 18;
                axi_awvalid <= 0;
                axi_awlen   <= 0;
                axi_awaddr  <= 0;
            end
            wait(axi_wready); 
            @(posedge clk) begin
                axi_wvalid <= 0;
                axi_wlast  <= 0;
                axi_wdata  <= 0;
            end
        end
    endtask

    task axi_wr_more;
        begin
            repeat(5) @(posedge clk);
            axi_awvalid <= 1;
            axi_awlen   <= 5;
            axi_awaddr  <= 33;
            #1
            wait(axi_awready);
            @(posedge clk) begin
                axi_wvalid <= 1;
                axi_wlast  <= 0;
                axi_wdata  <= 18;
                axi_awvalid <= 0;
                axi_awlen   <= 0;
                axi_awaddr  <= 0;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wdata  <= 19;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wdata  <= 20;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wdata  <= 21;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wlast  <= 1;
                axi_wdata  <= 22;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wlast  <= 0;
                axi_wdata  <= 0;
                axi_wvalid <= 0;
            end
        end
    endtask

    task axi_rd_single;
        begin
            repeat(5) @(posedge clk);
            axi_arvalid <= 1;
            axi_arlen   <= 0;
            axi_araddr  <= 33;
            wait(axi_arready);
            @(posedge clk) begin
                axi_arvalid <= 0;
                axi_arlen   <= 0;
                axi_araddr  <= 0;
            end
            @(posedge array_cas_rd);
            @(posedge clk) begin
                array_rdata_rdy <= 0; 
                array_rdata     <= 55; 
            end
            @(posedge clk) begin
                array_rdata_rdy <= 1;  
            end
            @(posedge clk) begin
                array_rdata <= 0;  
            end
        end
    endtask

    integer i;
    task axi_rd_more;
        begin
            repeat(5) @(posedge clk);
            axi_arvalid <= 1;
            axi_arlen   <= 5;
            axi_araddr  <= 33;
            wait(axi_arready);
            @(posedge clk) begin
                axi_arvalid <= 0;
                axi_arlen   <= 0;
                axi_araddr  <= 0;
            end
            @(posedge array_cas_rd);
            @(posedge clk) begin
                array_rdata_rdy <= 0; 
                array_rdata     <= 56; 
            end
            for(i=0;i<5;i=i+1) begin
                @(posedge clk) begin
                    array_rdata_rdy <= 1;  
                end
                @(posedge clk) begin
                    array_rdata_rdy <= 0;
                    array_rdata <= 57 + i;  
                end
            end
            @(posedge clk) begin
                array_rdata_rdy <= 1;
                array_rdata     <= 0;  
            end
        end
    endtask

    task axi_wr_valid_unconst;
        begin
            repeat(5) @(posedge clk);
            axi_awvalid <= 1;
            axi_awlen   <= 5;
            axi_awaddr  <= 33;
            #1
            wait(axi_awready);
            @(posedge clk) begin
                axi_wvalid <= 1;
                axi_wlast  <= 0;
                axi_wdata  <= 18;
                axi_awvalid <= 0;
                axi_awlen   <= 0;
                axi_awaddr  <= 0;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wdata  <= 19;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wvalid <= 0;
                axi_wdata  <= 20;
            end
            repeat(5) @(posedge clk);
            axi_wvalid <= 1;
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wdata  <= 21;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wlast  <= 1;
                axi_wdata  <= 22;
            end
            #1
            wait(axi_wready);
            @(posedge clk) begin
                axi_wlast  <= 0;
                axi_wdata  <= 0;
                axi_wvalid <= 0;
            end
        end
    endtask

    
endmodule