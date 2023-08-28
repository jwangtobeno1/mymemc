module asy_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
) (
    input                       wr_clk      ,
    input                       wr_rst_n    ,
    input      [DATA_WIDTH-1:0] wr_din      ,
    input                       wr_en       ,
    input                       rd_clk      ,
    input                       rd_rst_n    ,
    input                       rd_en       ,
    output     [DATA_WIDTH-1:0] rd_dout     ,
    output reg                  full        ,
    output reg                  empty       ,
    output reg                  al_full     ,
    output reg                  al_empty
);

    localparam PTR_WIDTH = (log2(DEPTH)==0) ? 1 : log2(DEPTH);

    reg  [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1]  ;
    reg  [PTR_WIDTH:0]    wr_ptr                ;
    reg  [PTR_WIDTH:0]    wr_ptr_gray           ;
    reg  [PTR_WIDTH:0]    wr_ptr_gray_rsyn1     ;
    reg  [PTR_WIDTH:0]    wr_ptr_gray_rsyn2     ;
    reg  [PTR_WIDTH:0]    rd_ptr                ;
    reg  [PTR_WIDTH:0]    rd_ptr_gray           ;
    reg  [PTR_WIDTH:0]    rd_ptr_gray_wsyn1     ;
    reg  [PTR_WIDTH:0]    rd_ptr_gray_wsyn2     ;
    wire [PTR_WIDTH:0]    wr_ptr_nxt            ;
    wire [PTR_WIDTH:0]    rd_ptr_nxt            ;
    wire [PTR_WIDTH:0]    rd_ptr_nxt_gray       ;
    wire [PTR_WIDTH:0]    wr_ptr_nxt_gray       ;
    wire [PTR_WIDTH:0]    wr_ptr_gray_rsyn      ;
    wire [PTR_WIDTH:0]    rd_ptr_gray_wsyn      ;
    wire                  full_comb             ;
    wire                  empty_comb            ;
    wire [PTR_WIDTH:0]    wr_ptr_rsyn           ;
    wire [PTR_WIDTH:0]    rd_ptr_wsyn           ;
    wire                  al_full_comb          ;
    wire                  al_empty_comb         ;
    wire [PTR_WIDTH:0]    wr_rmn                ;
    wire [PTR_WIDTH:0]    rd_rmn                ;

    
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if(!wr_rst_n)
            wr_ptr <= {(PTR_WIDTH+1){1'b0}};
        else
            wr_ptr <= wr_ptr_nxt;
    end

    assign wr_ptr_nxt = (wr_en&(~full)) ? (wr_ptr+1) : wr_ptr;

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if(!rd_rst_n)
            rd_ptr <= {(PTR_WIDTH+1){1'b0}};
        else
            rd_ptr <= rd_ptr_nxt;
    end

    assign rd_ptr_nxt = (rd_en&(~empty))?(rd_ptr+1):rd_ptr;

    assign rd_ptr_nxt_gray = (rd_ptr_nxt>>1) ^ rd_ptr_nxt;
    assign wr_ptr_nxt_gray = (wr_ptr_nxt>>1) ^ wr_ptr_nxt;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if(!wr_rst_n)
            wr_ptr_gray <= {(PTR_WIDTH+1){1'b0}};
        else
            wr_ptr_gray <= wr_ptr_nxt_gray;
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if(!rd_rst_n)
            rd_ptr_gray <= {(PTR_WIDTH+1){1'b0}};
        else
            rd_ptr_gray <= rd_ptr_nxt_gray;
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if(!wr_rst_n) begin
            rd_ptr_gray_wsyn1 <= {(PTR_WIDTH+1){1'b0}};
            rd_ptr_gray_wsyn2 <= {(PTR_WIDTH+1){1'b0}};
        end
        else begin
            rd_ptr_gray_wsyn1 <= rd_ptr_gray;
            rd_ptr_gray_wsyn2 <= rd_ptr_gray_wsyn1;
        end
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if(!rd_rst_n) begin
            wr_ptr_gray_rsyn1 <= {(PTR_WIDTH+1){1'b0}};
            wr_ptr_gray_rsyn2 <= {(PTR_WIDTH+1){1'b0}};
        end
        else begin
            wr_ptr_gray_rsyn1 <= wr_ptr_gray;
            wr_ptr_gray_rsyn2 <= wr_ptr_gray_rsyn1;
        end
    end

    assign wr_ptr_gray_rsyn = wr_ptr_gray_rsyn2;
    assign rd_ptr_gray_wsyn = rd_ptr_gray_wsyn2;

    assign full_comb = (wr_ptr_nxt_gray=={~rd_ptr_gray_wsyn[PTR_WIDTH:PTR_WIDTH-1],rd_ptr_gray_wsyn[PTR_WIDTH-2:0]});
    assign empty_comb = (rd_ptr_nxt_gray==wr_ptr_gray_rsyn);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if(!wr_rst_n)
            full <= 1'b0;
        else
            full <= full_comb;        
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if(!rd_rst_n)
            empty <= 1'b0;
        else 
            empty <= empty_comb;
    end

    generate
        genvar i;
        for(i=PTR_WIDTH;i>=0;i=i-1) begin:WR_GRAY_TO_BIN
            if(i==PTR_WIDTH) begin
                assign wr_ptr_rsyn[i] = wr_ptr_gray_rsyn[i];
                assign rd_ptr_wsyn[i] = rd_ptr_gray_wsyn[i];
            end
            else begin
                assign wr_ptr_rsyn[i] = wr_ptr_gray_rsyn[i] ^ wr_ptr_rsyn[i+1];
                assign rd_ptr_wsyn[i] = rd_ptr_gray_wsyn[i] ^ rd_ptr_wsyn[i+1];
            end
        end
    endgenerate

    assign wr_rmn = wr_ptr_nxt - rd_ptr_wsyn;
    assign rd_rmn = wr_ptr_rsyn - rd_ptr_nxt;

    assign al_full_comb = (wr_rmn>=DEPTH-1);
    assign al_empty_comb = (rd_rmn<=1);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if(!wr_rst_n)
            al_full <= 1'b0;
        else
            al_full <= al_full_comb;
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if(!rd_rst_n)
            al_empty <= 1'b0;
        else
            al_empty <= al_empty_comb;
    end

    integer j;
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if(!wr_rst_n)
            for(j=0;j<DEPTH;j=j+1)
                fifo_mem[j] <= {DATA_WIDTH{1'b0}};
        else if(wr_en & (~full))
            fifo_mem[wr_ptr[PTR_WIDTH-1:0]] <= wr_din;
    end

    /*always @(posedge rd_clk or negedge rd_rst_n) begin
        if(!rd_rst_n)
            rd_dout <= {DATA_WIDTH{1'b0}};
        else if(rd_en & (~empty))
            rd_dout <= fifo_mem[rd_ptr[PTR_WIDTH-1:0]];
    end*/

    assign rd_dout = fifo_mem[rd_ptr[PTR_WIDTH-1:0]];

    function integer log2;
        input integer depth;
        begin
            for(log2=0;depth>1;log2=log2+1)
                depth = depth>>1;
        end
    endfunction

endmodule