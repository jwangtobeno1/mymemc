module axi_slave #(
    parameter AXI_ADDR_WIDTH   = 20   ,
    parameter AXI_DATA_WIDTH   = 64   ,
    parameter ARRAY_ROW_ADDR   = 14   ,
    parameter ARRAY_COL_ADDR   = 6    ,
    parameter ARRAY_DATA_WIDTH = 64   ,
    parameter FRAME_DATA_WIDTH = 3 + ARRAY_ROW_ADDR + ARRAY_COL_ADDR + ARRAY_DATA_WIDTH //87
) (
    input                              clk              ,
    input                              rst_n            ,

    input                              axi_awvalid      ,
    output                             axi_awready      ,
    input      [5:0]                   axi_awlen        ,
    input      [AXI_ADDR_WIDTH-1:0]    axi_awaddr       , 

    input                              axi_wvalid       ,
    output                             axi_wready       ,
    input                              axi_wlast        ,
    input      [AXI_DATA_WIDTH-1:0]    axi_wdata        ,

    input                              axi_arvalid      ,
    output                             axi_arready      ,
    input      [5:0]                   axi_arlen        ,
    input      [AXI_ADDR_WIDTH-1:0]    axi_araddr       ,

    output                             axi_rvalid       ,
    output                             axi_rlast        ,
    output     [AXI_DATA_WIDTH-1:0]    axi_rdata        ,
    
    output                             mc_frame_valid   ,
    input                              mc_frame_ready   ,
    output     [FRAME_DATA_WIDTH-1:0]  mc_frame_data    ,
    //connect to array_ctrl
    input                              axi_array_rvalid ,    
    input      [AXI_DATA_WIDTH-1:0]    axi_array_rdata                    
);

    parameter   IDLE    = 3'd0,
                WR_ADDR = 3'd1,
                WR_DATA = 3'd2,
                RD_ADDR = 3'd3,
                RD_DATA = 3'd4;
    
    reg  [2:0]                state_c       ;
    reg  [2:0]                state_n       ;
                
    wire                      rw_flag       ;
    wire                      wr_en         ;
    wire                      rd_en         ;
    wire                      wr_last       ;
    wire                      rd_last       ;

    reg                       sof           ;
    wire                      eof           ;

    reg  [AXI_ADDR_WIDTH-1:0] rw_addr_temp  ;

    reg  [5:0]                rd_len        ;
    reg  [5:0]                rd_addr_cnt   ;
    reg  [5:0]                rd_data_cnt   ;
    wire [5:0]                rd_len_fifo   ;
    reg                       valid_flag    ;
    wire                      en_wr_fifo    ;
    wire                      en_rd_fifo    ;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state_c <= IDLE;
        else
            state_c <= state_n;
    end

    always @(*) begin
        case(state_c)
            IDLE: begin
                if(wr_en)
                    state_n = WR_ADDR;
                else if(rd_en)
                    state_n = RD_ADDR;
                else
                    state_n = state_c;
            end   
            WR_ADDR: begin
                state_n = WR_DATA;
            end
            WR_DATA: begin
                if(wr_last)
                    state_n = IDLE;
                else 
                    state_n = state_c;
            end
            RD_ADDR: begin
                state_n = RD_DATA;
            end
            RD_DATA: begin
                if(rd_last)
                    state_n = IDLE;
                else 
                    state_n = state_c;
            end
            default: state_n = IDLE;
        endcase
    end

	//控制交替优先仲裁
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            valid_flag <= 1'b0;
        else if(state_c==WR_ADDR)
            valid_flag <= 1'b0;
        else if(state_c==RD_ADDR)
            valid_flag <= 1'b1;
    end
    assign wr_en = {axi_awvalid,axi_arvalid}==2'b10 || {axi_awvalid,axi_arvalid}==2'b11 && valid_flag==1'b1; //先&&然后||
    assign rd_en = {axi_awvalid,axi_arvalid}==2'b01 || {axi_awvalid,axi_arvalid}==2'b11 && valid_flag==1'b0;

    assign wr_last = axi_wlast && axi_wvalid && axi_wready;
    assign rd_last = mc_frame_valid && mc_frame_ready && rd_addr_cnt==rd_len && ~rw_flag;

    assign rw_flag = state_c==WR_DATA;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rw_addr_temp <= 20'd0;
        else if(axi_arvalid && axi_arready)
            rw_addr_temp <= axi_araddr;
        else if(axi_awvalid && axi_awready)
            rw_addr_temp <= axi_awaddr;
        else if(mc_frame_valid && mc_frame_ready)
            rw_addr_temp <= rw_addr_temp + 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            sof <= 1'b0;
        else if(state_c==WR_ADDR || state_c==RD_ADDR) //axi_arready -> fsm -> sof
            sof <= 1'b1;
        else if(mc_frame_valid && mc_frame_ready) begin
            if(rw_addr_temp[5:0]==6'd63 && ~wr_last && ~rd_last)
                sof <= 1'b1;
            else
                sof <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rd_len <= 6'b0;
        else if(axi_arvalid && axi_arready)
            rd_len <= axi_arlen;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rd_addr_cnt <= 6'b0;
        else if(axi_arvalid && axi_arready)
            rd_addr_cnt <= 6'd0;
        else if(mc_frame_valid && mc_frame_ready)
            rd_addr_cnt <= rd_addr_cnt + 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rd_data_cnt <= 6'b0;
        else if(axi_rlast)
            rd_data_cnt <= 6'd0;
        else if(axi_rvalid)
            rd_data_cnt <= rd_data_cnt + 1;
    end

    assign en_wr_fifo = axi_arvalid && axi_arready;
    assign en_rd_fifo = mc_frame_valid && mc_frame_ready && rd_addr_cnt==6'd0 && ~rw_flag;

    fifo #(
    .WIDTH      (6          ),
    .DEPTH      (2          )
    ) fifo_rd_len(
    .clk        (clk        ),
    .reset      (rst_n      ),
    .en_wr      (en_wr_fifo ),
    .en_rd      (en_rd_fifo ),
    .din        (axi_arlen  ),
    .dout       (rd_len_fifo),
    .empty      (           ),
    .full       (           )
    );

    assign axi_rlast = rd_data_cnt==rd_len_fifo && axi_rvalid;

    assign eof = rw_addr_temp[5:0]==6'd63 || rd_last || wr_last;

    assign mc_frame_data = {sof,eof,rw_flag,rw_addr_temp,axi_wdata};//考虑是否不使用mux

    assign axi_awready = state_c==WR_ADDR;
    assign axi_arready = state_c==RD_ADDR;

    assign axi_wready = rw_flag && mc_frame_ready;

    assign mc_frame_valid = state_c==RD_DATA || axi_wvalid;

    assign axi_rvalid = axi_array_rvalid;
    assign axi_rdata = axi_array_rdata;

endmodule