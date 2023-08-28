module array_rfsh #(
    parameter ADDR_ROW_WIDTH = 14,
    parameter MAX_ROW_ADDR   = 14'h3fff
) (
    input                           clk               ,
    input                           rst_n             ,
    input                           rfsh_flag         ,
    output                          rfsh_end          ,
    input      [7:0]                array_tras_cfg    ,
    input      [7:0]                array_trp_cfg     ,
    output reg                      array_banksel_n   ,
    output reg [ADDR_ROW_WIDTH-1:0] array_raddr
);
    
    parameter   IDLE          = 3'd0,
                RFSH_SRADDR   = 3'd1,
                RFSH_RAS      = 3'd2,
                RFSH_RAS_LAST = 3'd3,
                RFSH_RP       = 3'd4;

    reg [2:0] state_c;
    reg [2:0] state_n;

    reg [7:0] fsm_cnt;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state_c <= IDLE;
        else
            state_c <= state_n;         
    end

    always @(*) begin
        case (state_c)
            IDLE         :begin
                if(rfsh_flag)
                    state_n = RFSH_SRADDR;
                else
                    state_n = state_c;
            end       
            RFSH_SRADDR  :begin
                state_n = RFSH_RAS;
            end
            RFSH_RAS     :begin
                if(fsm_cnt==8'd0)
                    state_n = RFSH_RAS_LAST;
                else
                    state_n = state_c;
            end
            RFSH_RAS_LAST:begin
                state_n = RFSH_RP;
            end
            RFSH_RP      :begin
                if(array_raddr==MAX_ROW_ADDR && fsm_cnt==8'd0)
                    state_n = IDLE;
                else if(fsm_cnt==8'd0)
                    state_n = RFSH_SRADDR;
                else
                    state_n = state_c;
            end
            default: state_n = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_raddr <= {ADDR_ROW_WIDTH{1'b0}};
        else if(state_c==IDLE)
            array_raddr <= {ADDR_ROW_WIDTH{1'b0}};
        else if(state_c==RFSH_RP && fsm_cnt==8'd0)
            array_raddr <= array_raddr + 1'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            array_banksel_n <= 1'b1;
        else if(state_c==RFSH_RAS_LAST)
            array_banksel_n <= 1'b1;
        else if(state_c==RFSH_SRADDR)
            array_banksel_n <= 1'b0;       
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            fsm_cnt <= 8'd0;
        else begin
            case(state_c)
            RFSH_RAS_LAST : fsm_cnt <=  array_trp_cfg - 1'd1;
            RFSH_SRADDR   : fsm_cnt <=  array_tras_cfg - 2'd2;
            default       : fsm_cnt <=  fsm_cnt==8'd0 ? fsm_cnt : fsm_cnt - 1'b1;
            endcase
        end
    end
                
    assign rfsh_end = state_c==RFSH_RP && array_raddr==MAX_ROW_ADDR && fsm_cnt==8'd0;

endmodule