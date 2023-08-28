module mc_apb_cfg #(
    parameter APB_DATA_WIDTH = 32,
    parameter APB_ADDR_WIDTH = 32,
    parameter TIM_CFG        = 8
) (
    input                           apb_clk             ,
    input                           apb_rst_n           ,
    input                           apb_psel            ,
    input                           apb_penable         ,
    input                           apb_pwrite          ,
    input      [APB_ADDR_WIDTH-1:0] apb_paddr           ,
    input      [APB_DATA_WIDTH-1:0] apb_pwdata          ,
    output reg [APB_DATA_WIDTH-1:0] apb_prdata          ,
    output                          apb_pready          ,
    
    output reg                      mc_en               ,
    output reg [TIM_CFG-1:0]        mc_trcd_cfg         ,
    output reg [TIM_CFG-1:0]        mc_tras_cfg         ,
    output reg [TIM_CFG-1:0]        mc_trp_cfg          ,
    output reg [TIM_CFG-1:0]        mc_twr_cfg          ,
    output reg [TIM_CFG-1:0]        mc_trtp_cfg         ,
    output reg [TIM_CFG-1:0]        mc_trc_cfg          ,
    output reg [APB_DATA_WIDTH-1:0] mc_refresh_period   ,
    output reg [APB_DATA_WIDTH-1:0] mc_refresh_start
);

    always @(posedge apb_clk or negedge apb_rst_n) begin
        if(!apb_rst_n) begin
            mc_en <= 1'h0;            
            mc_trcd_cfg <= 8'd7;
            mc_tras_cfg <= 8'd16;
            mc_trp_cfg <= 8'd6;
            mc_twr_cfg <= 8'd6;
            mc_trtp_cfg <= 8'd4;
            mc_trc_cfg <= 8'd22;
            mc_refresh_period <= 32'd2400_0000;
            mc_refresh_start <= 32'hffff_ffff;
        end
        else if(apb_penable && apb_pready && apb_pwrite) begin
            case(apb_paddr)
                32'd0: begin
                    mc_en <= apb_pwdata[0];
                end
                32'd4: begin
                    mc_trcd_cfg <= apb_pwdata[0*TIM_CFG+:8];
                    mc_tras_cfg <= apb_pwdata[1*TIM_CFG+:8];
                    mc_trp_cfg <= apb_pwdata[2*TIM_CFG+:8];
                    mc_twr_cfg <= apb_pwdata[3*TIM_CFG+:8];
                end
                32'd8: begin
                    mc_trtp_cfg <= apb_pwdata[0*TIM_CFG+:8];
                    mc_trc_cfg <= apb_pwdata[1*TIM_CFG+:8];
                end
                32'd12: begin
                    mc_refresh_period <= apb_pwdata;
                end
                32'd16: begin
                    mc_refresh_start <= apb_pwdata;
                end
            endcase
        end
    end

    always @(posedge apb_clk or negedge apb_rst_n) begin
        if(!apb_rst_n) begin
            apb_prdata <= 32'd0;
        end
        else if(~apb_pwrite && apb_psel) begin
            case(apb_paddr)
                32'd0: begin
                    apb_prdata <= {31'b0,mc_en};
                end
                32'd4: begin
                    apb_prdata <= {mc_twr_cfg,mc_trp_cfg,mc_tras_cfg,mc_trcd_cfg};
                end
                32'd8: begin
                    apb_prdata <= {16'b0,mc_trc_cfg,mc_trtp_cfg};
                end
                32'd12: begin
                    apb_prdata <= mc_refresh_period;
                end
                32'd16: begin
                    apb_prdata <= mc_refresh_start;
                end
            endcase
        end
    end

    assign apb_pready = apb_penable;

    //若实现刷新中可配置，可设置两组数据。
    //en为0取第一组数据，为1时取第二组数据，在0时可配置第二组数据,写入完成后将en拉高即可。

endmodule



