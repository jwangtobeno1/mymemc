//因为时序过不了，所以需要这个模块插寄存器，打断握手时序
// 其实就是一个同步FIFO，写使能是valid_i, ~full信号为ready_i；
// 读使能是ready_o ~empty信号为valid_o；
module flow_control_buffer #(
    parameter DATA_WIDTH   = 64,
    parameter BUFFER_DEPTH = 2
) (
    input                   clk     ,
    input                   rst_n   ,
    //connect to axi_slave
    input  [DATA_WIDTH-1:0] data_i  ,
    input                   valid_i ,
    output                  ready_i ,
    //connect to array_ctl
    output                  valid_o ,
    output [DATA_WIDTH-1:0] data_o  ,
    input                   ready_o
);

    reg  [DATA_WIDTH-1:0] buffer_reg [0:BUFFER_DEPTH-1];
    reg                   ptr_wr    ;
    reg                   ptr_rd    ;
    reg  [1:0]            count     ;

    wire                  empty     ;
    wire                  full      ;
    wire                  wr_en     ;
    wire                  rd_en     ;
                
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            ptr_wr <= 1'd0;
        else if(wr_en && ~full)
            ptr_wr <= ~ptr_wr;
        else
        	ptr_wr <= ptr_wr;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            ptr_rd <= 1'd0;
        else if(~empty && rd_en)
            ptr_rd <= ~ptr_rd;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            count <= 2'd0;
        else if(~empty && rd_en && wr_en && ~full)
            count <= count + 1'd1;
        else if(~empty && rd_en)
            count <= count - 1'd1;
        else if(wr_en && ~full)
            count <= count + 1'd1;
    end

    assign full = count==2'd2;
    assign empty = count==2'd0;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            buffer_reg[0] <= {DATA_WIDTH{1'd0}};
            buffer_reg[1] <= {DATA_WIDTH{1'd0}};
        end
        else if(wr_en && ~full)
            buffer_reg[ptr_wr] <= data_i;
    end

    assign data_o = buffer_reg[ptr_rd];

    assign ready_i = ~full;
    assign wr_en = valid_i;

    assign valid_o = ~empty;
    assign rd_en = ready_o;

endmodule

//if needs three-level flip-flop, you can instantiate this module three times and link them tegether.