module array_w #(
    parameter ARRAY_ROW_ADDR   = 14 ,
    parameter ARRAY_COL_ADDR   = 6  ,
    parameter ARRAY_DATA_WIDTH = 64 ,
    parameter FRAME_DATA_WIDTH = 3 + ARRAY_ROW_ADDR + ARRAY_COL_ADDR + ARRAY_DATA_WIDTH //87
) (
    input                             clk               ,
    input                             rst_n             ,
    input                             frame_wr_valid    ,
    input      [FRAME_DATA_WIDTH-1:0] frame_wr_data     ,
    output                            frame_wr_ready    ,
    
    output reg                        array_banksel_n   ,
    output reg [ARRAY_ROW_ADDR-1:0]   array_raddr       ,
    output reg                        array_cas_wr      ,
    output reg [ARRAY_COL_ADDR-1:0]   array_caddr_wr    ,
    output                            array_wdata_rdy   ,
    output reg [ARRAY_DATA_WIDTH-1:0] array_wdata       ,
    
    output                            wr_end            ,
    input      [7:0]                  array_trcd_cfg    ,
    input      [7:0]                  array_trp_cfg     ,
    input      [7:0]                  array_twr_cfg     ,
    input      [7:0]                  array_tras_cfg
);

    parameter   IDLE      = 3'd0,
                WR_SRADDR = 3'd1,
                WR_RCD    = 3'd2,
                WR_SEND   = 3'd3,
                WR_WR     = 3'd4,
                WR_RP     = 3'd5;

    reg  [2:0]                  state_c         ;
    reg  [2:0]                  state_n         ;
    
    wire                        rcd_last        ;
    wire                        wr_send_last    ;
    wire                        wr_last         ;
    wire                        rp_last         ;
 
    wire                        sof             ;
    wire                        eof             ;
    reg                         eof_reg         ;
    wire                        rw_flag         ;

    reg  [7:0]                  array_wr_cnt    ;
    reg  [7:0]                  array_rcd_cnt   ; 
    reg                         trcd_wait       ;
    reg                         twr_wait        ;

    wire [ARRAY_ROW_ADDR-1:0]   row_addr        ;
    wire [ARRAY_COL_ADDR-1:0]   col_addr        ;
    wire [ARRAY_DATA_WIDTH-1:0] frame_data      ; 

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state_c <= IDLE;
        else
            state_c <= state_n;
    end

    always @(*) begin
        case(state_c)
            IDLE: begin
                if(frame_wr_valid && sof)
                    state_n =  WR_SRADDR;
                else 
                    state_n = state_c;
            end     
            WR_SRADDR: begin
                state_n = WR_RCD;
            end 
            WR_RCD: begin
                if(rcd_last)
                    state_n = WR_SEND;
                else
                    state_n = state_c;
            end    
            WR_SEND: begin
                if(wr_send_last)
                    state_n = WR_WR;
                else 
                    state_n = state_c;
            end  
            WR_WR: begin
                if(wr_last)
                    state_n = WR_RP;
                else
                    state_n = state_c;
            end     
            WR_RP: begin
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
            array_banksel_n <= 1'b1;
        else if(wr_last)
            array_banksel_n <= 1'b1;
        else if(state_c==WR_SRADDR)
            array_banksel_n <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_raddr <= {ARRAY_ROW_ADDR{1'b0}};
        else if(state_c==IDLE && frame_wr_valid)
            array_raddr <= row_addr;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            array_caddr_wr <= {ARRAY_ROW_ADDR{1'b0}};
            array_wdata <= {ARRAY_DATA_WIDTH{1'b0}};
            eof_reg <= 1'b0;
        end
        else if(frame_wr_ready && frame_wr_valid) begin
            array_caddr_wr <= col_addr;
            array_wdata <= frame_data;
            eof_reg <= eof;
        end
    end

    assign {sof,eof,rw_flag,row_addr,col_addr,frame_data} = frame_wr_data;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_cas_wr <= 1'b0;
        else if(rcd_last)
            array_cas_wr <= 1'b1;
        else if(state_c==WR_SEND && frame_wr_valid)
            array_cas_wr <= ~array_cas_wr;
        else
            array_cas_wr <= 1'b0;
    end

    assign array_wdata_rdy = ~array_cas_wr;

    assign frame_wr_ready = state_c==IDLE || (state_c==WR_SEND && ~array_cas_wr);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_wr_cnt <= 8'd0;
        else if(wr_last)
            array_wr_cnt <= 8'd0;
        else if(state_c==WR_RCD || state_c==WR_WR || state_c==WR_RP)
            array_wr_cnt <= array_wr_cnt + 1'd1;
        else 
            array_wr_cnt <= 8'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_rcd_cnt <= 8'd0;
        else if(state_c==WR_RCD || state_c==WR_WR || state_c==WR_SEND)
            array_rcd_cnt <= array_rcd_cnt + 1'd1;
        else
            array_rcd_cnt <= 8'd0;
    end

    assign rcd_last = array_wr_cnt==array_trcd_cfg-1'b1 && state_c==WR_RCD;
    assign rp_last = array_wr_cnt==array_trp_cfg-1'b1 && state_c==WR_RP;

    assign wr_end = rp_last;

    assign wr_send_last = eof_reg && array_cas_wr;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            trcd_wait <= 1'b0;
        else if(wr_last)
            trcd_wait <= 1'b0;
        else if(array_rcd_cnt==array_tras_cfg-2'd2)
            trcd_wait <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            twr_wait <= 1'b0;
        else if(wr_last)
            twr_wait <= 1'b0;
        else if(array_wr_cnt==array_twr_cfg-2'd2 && state_c==WR_WR)
            twr_wait <= 1'b1;
    end

    assign wr_last = twr_wait && trcd_wait;

    //assign wr_last = state_c==WR_WR && ((twr_wait && array_rcd_cnt==array_tras_cfg-1'b1) || (trcd_wait && array_wr_cnt==array_twr_cfg-1'b1) || (array_rcd_cnt==array_tras_cfg-1'b1 && array_wr_cnt==array_twr_cfg-1'b1));

    // could use case to config  array_wr_cnt as single of cfg-1, this operaton needs extra state to config, if cnt==0
    // the timing is benifit 
endmodule