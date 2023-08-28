module array_r #(
    parameter ARRAY_ROW_ADDR   = 14   ,
    parameter ARRAY_COL_ADDR   = 6    ,
    parameter ARRAY_DATA_WIDTH = 64   ,
    parameter FRAME_DATA_WIDTH = 3 + ARRAY_ROW_ADDR + ARRAY_COL_ADDR + ARRAY_DATA_WIDTH
) (
    input                             clk               ,
    input                             rst_n             ,
    input                             frame_rd_valid    ,
    input      [FRAME_DATA_WIDTH-1:0] frame_rd_data     ,
    output                            frame_rd_ready    ,
    output                            axi_array_rvalid  ,
    output     [ARRAY_DATA_WIDTH-1:0] axi_array_rdata   ,   
    output reg                        array_banksel_n   ,
    output reg [ARRAY_ROW_ADDR-1:0]   array_raddr       ,
    output reg                        array_cas_rd      ,
    output reg [ARRAY_COL_ADDR-1:0]   array_caddr_rd    ,
    input                             array_rdata_rdy   ,
    input      [ARRAY_DATA_WIDTH-1:0] array_rdata       ,
    output                            rd_end            ,
    input      [7:0]                  array_trcd_cfg    ,
    input      [7:0]                  array_trp_cfg     ,
    input      [7:0]                  array_trtp_cfg    ,
    input      [7:0]                  array_tras_cfg
);

    parameter   IDLE      = 3'd0,
                RD_SRADDR = 3'd1,
                RD_RCD    = 3'd2,
                RD_SEND   = 3'd3,
                RD_LAST   = 3'd4,
                RD_RTP    = 3'd5,
                RD_PRE_RP = 3'd6,
                RD_RP     = 3'd7;
    
    reg  [2:0]  state_n     ;
    reg  [2:0]  state_c     ;

    wire        rcd_last    ;
    wire        rd_send_last;
    wire        rtp_last    ;
    wire        rp_last     ;

    reg  [7:0]  fsm_cnt     ;
    reg  [7:0]  ras_cnt     ;
    
    wire        sof         ;
    wire        eof         ;
    reg         eof_dly     ;
    wire        rw_flag     ;
    wire [13:0] row_addr    ;
    wire [5:0]  col_addr    ;
    wire [63:0] frame_data  ;

    wire        rd_en;
    wire        empty; 

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state_c <= IDLE;
        else
            state_c <= state_n;
    end

    always @(*) begin
        case(state_c)
            IDLE: begin
                if(frame_rd_valid && sof)
                    state_n = RD_SRADDR;
                else
                    state_n = state_c;
            end     
            RD_SRADDR: begin
                state_n = RD_RCD;
            end
            RD_RCD: begin
                if(rcd_last && eof_dly)
                    state_n =  RD_LAST;
                else if(rcd_last)
                    state_n = RD_SEND;
                else
                    state_n = state_c; 
            end    
            RD_SEND: begin
                if(rd_send_last)
                    state_n = RD_LAST;
                else
                    state_n = state_c;
            end   
            RD_LAST: begin
                state_n = RD_RTP; 
            end   
            RD_RTP: begin
                if(rtp_last)
                    state_n = RD_PRE_RP;
                else
                    state_n = state_c;
            end    
            RD_PRE_RP: begin
                state_n = RD_RP;
            end 
            RD_RP: begin
                if(rp_last)
                    state_n = IDLE;
                else
                    state_n = state_c;
            end     
            default: state_n = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            fsm_cnt <= 8'd0;
        else begin
            case (state_c)
                RD_SRADDR: fsm_cnt <= array_trcd_cfg - 1'b1;
                RD_LAST: fsm_cnt <= array_trtp_cfg - 2'd2;
                RD_PRE_RP: fsm_cnt <= array_trp_cfg - 1'b1;
                default: fsm_cnt <= fsm_cnt==8'd0 ? fsm_cnt : fsm_cnt - 1'b1;
            endcase
        end  
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            ras_cnt <= 8'd0;
        else if(ras_cnt==8'd0)
            ras_cnt <= ras_cnt;
        else if(state_c==RD_SRADDR)
            ras_cnt <= array_tras_cfg;
        else
            ras_cnt <= ras_cnt - 1'b1;
    end

    assign rcd_last = state_c==RD_RCD && fsm_cnt==8'd0;
    assign rtp_last = state_c==RD_RTP && fsm_cnt==8'd0 && ras_cnt==8'd0;
    assign rp_last  = state_c==RD_RP  && fsm_cnt==8'd0;
    
    assign rd_send_last = eof && frame_rd_valid && ~array_cas_rd;  

    assign {sof,eof,rw_flag,row_addr,col_addr,frame_data} = frame_rd_data;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_raddr <= {ARRAY_ROW_ADDR{1'b0}};
        else if(frame_rd_valid && state_c==IDLE)
            array_raddr <= row_addr;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            eof_dly <= 1'b0;
        else if(frame_rd_valid && state_c==IDLE)
            eof_dly <= eof;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_caddr_rd <= {ARRAY_COL_ADDR{1'b0}};
        else if(frame_rd_valid && state_c==IDLE)
            array_caddr_rd <= col_addr;
        else if(frame_rd_valid && state_c==RD_SEND && ~array_cas_rd)
            array_caddr_rd <= col_addr;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_banksel_n <= 1'b1;
        else if(state_c==RD_SRADDR)
            array_banksel_n <= 1'b0;
        else if(state_c==RD_PRE_RP)
            array_banksel_n <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_cas_rd <= 1'b0;
        else if(rcd_last)
            array_cas_rd <= 1'b1;
        else if(state_c==RD_SEND && frame_rd_valid)
            array_cas_rd <= ~array_cas_rd;
        else
            array_cas_rd <= 1'b0;    
    end

    assign frame_rd_ready = state_c==IDLE || state_c==RD_SEND && ~array_cas_rd;

    asy_fifo #(
    .DATA_WIDTH (ARRAY_DATA_WIDTH   ),
    .DEPTH      (8                  )
    ) asy_fifo_rdata(   
    .wr_clk     (array_rdata_rdy    ),
    .wr_rst_n   (rst_n              ),
    .wr_din     (array_rdata        ),
    .wr_en      (1'b1               ),
    .rd_clk     (clk                ),
    .rd_rst_n   (rst_n              ),
    .rd_en      (rd_en              ),
    .rd_dout    (axi_array_rdata    ),
    .full       (                   ),
    .empty      (empty              ),
    .al_full    (                   ),
    .al_empty   (                   )
    );

    assign rd_en = ~empty;

    assign axi_array_rvalid = rd_en;

    assign rd_end = rp_last; 
    
endmodule