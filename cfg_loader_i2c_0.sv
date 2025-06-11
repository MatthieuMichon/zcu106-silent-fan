`resetall
`timescale 1ns/1ps

module cfg_loader_i2c_0 #(

    parameter real CLK_MHZ,
    parameter integer I2C_SCL_KHZ = 100

) (

    /*
     * Clocks
     */

        input wire logic clk,
        input wire logic rst,

    /*
     * Status
     */

        output reg conf_done,
        output reg conf_fail,

    /*
     * I2C bus
     */

        input wire logic scl_i,
        output wire logic scl_o,
        output wire logic scl_t,
        input wire logic sda_i,
        output wire logic sda_o,
        output wire logic sda_t

);

assign scl_t = scl_o;
assign sda_t = sda_o;

/*
 * prescale
 *     set prescale to 1/4 of the minimum clock period in units
 *     of input clk cycles (prescale = Fclk / (FI2Cclk * 4))
 */

localparam integer PRESCALE_S32 = $ceil((1000*CLK_MHZ)/(I2C_SCL_KHZ*3));
localparam logic [16-1:0] PRESCALE = PRESCALE_S32;

generate
    if (PRESCALE_S32 < 0) begin : check_negative
        $error("COMPILE-TIME ERROR: PRESCALE_S32 (%0d) cannot be negative for an unsigned target.", PRESCALE_S32);
    end
    if ($clog2(PRESCALE_S32) > $bits(PRESCALE)) begin : check_overflow
        $error("COMPILE-TIME ERROR: PRESCALE_S32 (%0d) requires more than %0d bits.", PRESCALE_S32, $bits(PRESCALE));
    end
endgenerate

localparam logic [24-1:0] I2C_0_CONF [2-1:0] = {
    24'h400260, // output port register pins 7:0: set MAX6643_FANFAUL_B (fullspeed) low
    24'h400697 // configuration register pins 7:0
};
logic [$clog2($size(I2C_0_CONF))-1:0] index;

taxi_axis_if #(.DATA_W(12)) axis_cmd();
taxi_axis_if #() w_axis_data();
taxi_axis_if #() r_axis_data();

logic busy;
logic bus_control;
logic bus_active;
logic missed_ack;

enum {
    WAIT_READY_CMD, 
    ISSUE_CMD,
    WAIT_I2C_READY,
    WAIT_READY_DATA_1,
    WAIT_READY_DATA_2,
    UPDATE_INDEX,
    FINISHED} state; 

always_ff@(posedge clk) begin: latch_missed_ack
    if (rst) begin
        conf_fail <= 1'b0;
    end else begin
        if (missed_ack) begin
            conf_fail <= 1'b1;
        end
    end
end

always_ff@(posedge clk) begin: loader_fsm
    if (rst) begin
        conf_done <= 1'b0;
        index <= 0;
        state <= WAIT_READY_CMD;
        axis_cmd.tvalid <= 1'b0;
        w_axis_data.tvalid <= 1'b0;
    end else begin
        case (state)
            WAIT_READY_CMD: begin
                if (axis_cmd.tready) begin
                    state <= ISSUE_CMD;
                end
            end
            ISSUE_CMD: begin
                axis_cmd.tvalid <= 1'b1;
                axis_cmd.tlast <= 1'b1;
                w_axis_data.tvalid <= 1'b1;
                w_axis_data.tdata <= I2C_0_CONF[index][16-1:8];
                w_axis_data.tlast <= 1'b0;
                state <= WAIT_READY_DATA_1;
            end
            WAIT_READY_DATA_1: begin
                axis_cmd.tvalid <= 1'b0;
                axis_cmd.tlast <= 1'b0;
                w_axis_data.tvalid <= 1'b1;
                if (w_axis_data.tready) begin
                    w_axis_data.tdata <= I2C_0_CONF[index][8-1:0];
                    w_axis_data.tlast <= 1'b1;
                    state <= WAIT_READY_DATA_2;
                end
            end
            WAIT_READY_DATA_2: begin
                axis_cmd.tvalid <= 1'b0;
                axis_cmd.tlast <= 1'b0;
                w_axis_data.tvalid <= 1'b1;
                if (w_axis_data.tready) begin
                    w_axis_data.tvalid <= 1'b0;
                    w_axis_data.tlast <= 1'b0;
                    state <= UPDATE_INDEX;
                end
            end
            UPDATE_INDEX: begin
                if (index < $high(I2C_0_CONF)) begin
                    index <= index + 1;
                    state <= WAIT_READY_CMD;
                end else begin
                    index <= 0;
                    state <= FINISHED;
                end
            end
            FINISHED: begin
                conf_done <= !conf_fail && axis_cmd.tready;
            end
        endcase
    end
end

assign axis_cmd.tdata[7-1:0] = I2C_0_CONF[index][24-1:17];
assign axis_cmd.tdata[7] = 1'b1; // set start bit
assign axis_cmd.tdata[8] = 1'b0; // clear read bit
assign axis_cmd.tdata[9] = 1'b0; // clear write (single byte) bit
assign axis_cmd.tdata[10] = 1'b1; // set write multiple (bytes) bit
assign axis_cmd.tdata[11] = 1'b1; // set stop bit

assign r_axis_data.tready = !rst;

taxi_i2c_master taxi_i2c_master_i (
    .clk(clk),
    .rst(rst),

    /*
     * Host interface
     */
    .s_axis_cmd(axis_cmd),
    .s_axis_data(w_axis_data),
    .m_axis_data(r_axis_data),

    /*
     * I2C interface
     */
    .scl_i(scl_i),
    .scl_o(scl_o),
    .sda_i(sda_i),
    .sda_o(sda_o),

    /*
     * Status
     */
    .busy(busy),
    .bus_control(bus_control),
    .bus_active(bus_active),
    .missed_ack(missed_ack),

    /*
     * Configuration
     */
    .prescale(PRESCALE),
    .stop_on_idle(1'b0)

);

endmodule

`resetall
