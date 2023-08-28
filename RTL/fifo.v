module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
) (
    input                  clk,
    input                  reset,
    input                  en_wr,
    input                  en_rd,
    input [WIDTH-1:0]      din,
    output reg [WIDTH-1:0] dout,
    output                 empty,
    output                 full 
);
    
    localparam WIDTH_DEPTH = (log2(DEPTH)==0) ? 1 : log2(DEPTH);

    reg [WIDTH-1:0] mem_fifo [0:DEPTH-1];
    reg [WIDTH_DEPTH-1:0] ptr_wr;
    reg [WIDTH_DEPTH-1:0] ptr_rd;
    reg [WIDTH_DEPTH:0]   count;

    always @(posedge clk or negedge reset) begin
        if(!reset)
            count <= {WIDTH_DEPTH{1'b0}};
        else if(en_wr & (~full) & en_rd & (~empty))
            count <= count;
        else if(en_wr & (~full))
            count <= count + 1;
        else if(en_rd & (~empty))
            count <= count -1;
    end

    integer i;
    always @(posedge clk or negedge reset) begin
        if(!reset) begin
            for(i=0;i<DEPTH;i=i+1)
            mem_fifo[i] <= {WIDTH{1'b0}};
        end
        else if(en_wr & (~full))
            mem_fifo[ptr_wr] <= din;
    end

    always @(posedge clk or negedge reset) begin
        if(!reset)
            ptr_wr <= {WIDTH_DEPTH{1'b0}};
        else if(en_wr & (~full) & (ptr_wr==DEPTH-1))
            ptr_wr <= {WIDTH_DEPTH{1'b0}};
        else if(en_wr & (~full))
            ptr_wr <= ptr_wr + 1;
    end

    always @(posedge clk or negedge reset) begin
        if(!reset)
            ptr_rd <= {WIDTH_DEPTH{1'b0}};
        else if(en_rd & (~empty) & (ptr_rd==DEPTH-1))
            ptr_rd <= {WIDTH_DEPTH{1'b0}};
        else if(en_rd & (~empty))
            ptr_rd <= ptr_rd + 1;
    end

    always @(posedge clk or negedge reset) begin
        if(!reset)
            dout <= {WIDTH{1'b0}};
        else if(en_rd & (~empty))
            dout <= mem_fifo[ptr_rd];
    end

    assign full = (count == DEPTH)?1'b1:1'b0;
    assign empty = (count == {(WIDTH_DEPTH+1){1'b0}})?1'b1:1'b0;
    
    function integer log2;
        input integer depth;
        begin
            for(log2=0;depth>1;log2=log2+1)
                depth = depth>>1;
        end
    endfunction

endmodule