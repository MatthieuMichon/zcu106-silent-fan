`default_nettype none
`timescale 1ns/1ps

module zcu106_silent_fan (

    // General Purpose Clocks

        input wire clk_74_25_p, clk_74_25_n,
    
    // Primary I2C

        inout wire i2c0_scl, i2c0_sda,

    // General Purpose IOs

        input wire cpu_reset,
        output wire [8-1:0] gpio_led
 
);

logic clk_74_25, rst_74_25;
logic cpu_reset_sync;
logic i2c_0_scl_i, i2c_0_scl_o, i2c_0_scl_t, i2c_0_sda_i, i2c_0_sda_o, i2c_0_sda_t;

IBUFDS ibufds_clk_74_25 (
    .I(clk_74_25_p), .IB(clk_74_25_n),
    .O(clk_74_25)
);
HARD_SYNC #(
    .INIT(1'b1), .LATENCY(3)
) hard_sync_cpu_reset (
    .CLK(clk_74_25),
    .DIN(cpu_reset),
    .DOUT(cpu_reset_sync)
);

logic [8-1:0] cnt_rst_74_25 = 0;

always_ff @(posedge clk_74_25) begin
    if (cpu_reset_sync == 1'b1) begin
        rst_74_25 = 1'b1;
        cnt_rst_74_25 = 0;
    end else if (&cnt_rst_74_25 == 1'b1) begin
        rst_74_25 = 1'b1;
        cnt_rst_74_25 = cnt_rst_74_25 + 1;
    end else begin // max cnt_rst_74_25
        rst_74_25 = 1'b0;
    end
end

logic i2c_0_done;

IOBUF iobuf_i2c [1:0] (
    .I ({i2c_0_scl_o, i2c_0_sda_o}), // logic --> IOBUF --> pad
    .T ({i2c_0_scl_t, i2c_0_sda_t}), // logic --> IOBUF --> pad
    .O ({i2c_0_scl_i, i2c_0_sda_i}), // pad --> IOBUF --> logic
    .IO ({i2c0_scl, i2c0_sda})
);

cfg_loader_i2c_0 #(
    .CLK_MHZ (74.25)
) cfg_loader_i2c_0_i (
    .clk(clk_74_25), .rst(rst_74_25),
    .conf_done(i2c_0_done),
    .scl_i(i2c_0_scl_i), .scl_o(i2c_0_scl_o), .scl_t(i2c_0_scl_t),
    .sda_i(i2c_0_sda_i), .sda_o(i2c_0_sda_o), .sda_t(i2c_0_sda_t)
);

assign gpio_led[7] = 1'b0;
assign gpio_led[6] = rst_74_25;
assign gpio_led[2] = !i2c_0_done;

endmodule

`resetall
