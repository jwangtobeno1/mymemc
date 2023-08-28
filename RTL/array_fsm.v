module array_fsm #(
    parameter ARRAY_ROW_ADDR   = 14     ,
    parameter ARRAY_COL_ADDR   = 6      ,
    parameter ARRAY_DATA_WIDTH = 64     ,
    parameter FRAME_DATA_WIDTH = 3 + ARRAY_ROW_ADDR + ARRAY_COL_ADDR + ARRAY_DATA_WIDTH
) (
    input                         clk                   ,
    input                         rst_n                 ,
    input                         array_en              ,
    input                         mc_frame_valid        ,   
    output                        mc_frame_ready        ,
    input  [FRAME_DATA_WIDTH-1:0] mc_frame_data         ,
    
    input  [31:0]                 array_refresh_period  ,
    input  [31:0]                 array_refresh_start   ,
    input                         wr_end                ,
    input                         rd_end                ,
    input                         rfsh_end              ,
    
    output                        frame_wr_valid        , //to array_w
    input                         frame_wr_ready        , //come array_w
    output [FRAME_DATA_WIDTH-1:0] frame_wr_data         , //to array_w come mc_frame_data
    input  [ARRAY_ROW_ADDR-1:0]   array_wr_raddr        , //
    input                         array_wr_banksel_n    ,
    
    output                        frame_rd_valid        ,
    input                         frame_rd_ready        ,
    output [FRAME_DATA_WIDTH-1:0] frame_rd_data         ,
    input  [ARRAY_ROW_ADDR-1:0]   array_rd_raddr        ,
    input                         array_rd_banksel_n    ,
    
    output                        rfsh_flag             ,
    input  [ARRAY_ROW_ADDR-1:0]   array_rfsh_raddr      ,
    input                         array_rfsh_banksel_n  ,
    
    output                        array_banksel_n       ,
    output [ARRAY_ROW_ADDR-1:0]   array_raddr
);

    parameter   IDLE       = 2'd0,
                ARRAY_WR   = 2'd1,
                ARRAY_RD   = 2'd2,
                ARRAY_RFSH = 2'd3;

    reg [1:0] state_c;
    reg [1:0] state_n;

    wire                        sof         ;
    wire                        eof         ;
    wire                        rw_flag     ;
    wire [ARRAY_ROW_ADDR-1:0]   row_addr    ;
    wire [ARRAY_COL_ADDR-1:0]   col_addr    ;
    wire [ARRAY_DATA_WIDTH-1:0] wr_data     ;
    reg  [31:0]                 rfsh_cnt    ;
    reg                         rfsh_wait   ;
    reg                         en_asyn1    ; //对array_en打两拍寄存
    reg                         en_asyn2    ;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state_c <= IDLE;
        else
            state_c <= state_n;
    end

    always @(*) begin
        case (state_c)
            IDLE       : begin
                if(en_asyn2 && (rfsh_wait || rfsh_cnt==array_refresh_start-1'b1))
                    state_n = ARRAY_RFSH;
                else if(en_asyn2 && mc_frame_valid && rw_flag && sof) //根据frame valid来拉起frame ready
                    state_n = ARRAY_WR;
                else if(en_asyn2 && mc_frame_valid && ~rw_flag && sof)
                    state_n = ARRAY_RD;
                else
                    state_n = state_c;
            end   
            ARRAY_WR   : begin
                if(wr_end)
                    state_n = IDLE;
                else
                    state_n = state_c;
            end
            ARRAY_RD   : begin
                if(rd_end)
                    state_n = IDLE;
                else
                    state_n = state_c;
            end
            ARRAY_RFSH : begin
                if(rfsh_end)
                    state_n = IDLE;
                else
                    state_n = state_c;
            end
            default: state_n = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            en_asyn1 <= 1'b0;
            en_asyn2 <= 1'b0;
        end
        else begin
            en_asyn1 <= array_en;
            en_asyn2 <= en_asyn1;
        end
    end

    assign {sof,eof,rw_flag,row_addr,col_addr,wr_data} = mc_frame_data;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rfsh_cnt <= 32'd0;
        else if(rfsh_cnt==array_refresh_period-1'b1)
            rfsh_cnt <= 32'd0;
        else
            rfsh_cnt <= rfsh_cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rfsh_wait <= 1'b0;
        else if(state_c==IDLE)
            rfsh_wait <= 1'b0;
        else if(rfsh_cnt==array_refresh_start-1'b1 && state_c!=IDLE)
            rfsh_wait <= 1'b1;
    end

    assign frame_wr_valid = state_c==ARRAY_WR ? mc_frame_valid : 1'b0;
    assign frame_rd_valid = state_c==ARRAY_RD ? mc_frame_valid : 1'b0;

    assign mc_frame_ready = state_c==ARRAY_WR ? frame_wr_ready : 
                            state_c==ARRAY_RD ? frame_rd_ready :
                            1'b0;

    assign frame_wr_data = mc_frame_data;
    assign frame_rd_data = mc_frame_data;

    assign array_raddr = state_c==ARRAY_WR   ? array_wr_raddr   : 
                        state_c==ARRAY_RD   ? array_rd_raddr   :
                        state_c==ARRAY_RFSH ? array_rfsh_raddr :
                        14'b0;
    
    assign array_banksel_n = state_c==ARRAY_WR   ? array_wr_banksel_n   : 
                            state_c==ARRAY_RD   ? array_rd_banksel_n   :
                            state_c==ARRAY_RFSH ? array_rfsh_banksel_n :
                            1'b1;

    assign rfsh_flag = state_c==ARRAY_RFSH;
    
endmodule