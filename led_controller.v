// Created by BitBangingGod
// Copyright owned by BitBangingGod
// Licensed under MIT License
// GitHub: https://github.com/BitBangingGod
// Source Control: https://github.com/BitBangingGod/neopixel_hdl

`timescale 1ns / 1ps

module transmitter #(
    parameter T0H = 30,
    parameter T1H = 60,
    parameter T0L = 90,
    parameter T1L = 60,
    parameter TRST = 8000,
    parameter pixel_width = 24
) (
    input wire clk,
    input wire reset,
    input wire ready_in,
    input wire [pixel_width -1 : 0] pixelData,
    output reg ready_out,
    output reg data_out
);

    localparam Ready = 0; 
    localparam WaitingForHandShake = 1;
    localparam PixelHigh = 2;
    localparam PixelLow = 3;
    localparam Reset = 4;

    reg[2:0] state;
    integer index;
    integer counter;
    integer threshold;
    reg [pixel_width -1 : 0] currentPixelData;
    
    initial begin
        state = Ready;
        index = 0;
        counter = 0;
        threshold = 0;
        currentPixelData = 0;
    end
    
    always @ (posedge clk) begin
        case (state)
            Ready: begin
                state <= WaitingForHandShake;
                ready_out <= 1;
            end
            WaitingForHandShake: begin
                if (ready_in == 1) begin
                    if (reset == 1) begin
                        state <= Reset;
                        ready_out <= 0;
                        index <= 0;
                        counter <= 0;
                        currentPixelData <= 0;
                    end else begin
                        state <= PixelHigh;
                        currentPixelData <= pixelData;
                        ready_out <= 0;
                        index <= 0;
                        counter <= 0;
                    end
                end else begin
                    state <= WaitingForHandShake;
                end
            end
            PixelHigh: begin 
                if (counter >= threshold) begin
                    state <= PixelLow;
                    counter <= 0;
                end else begin
                    state <= PixelHigh;
                    counter <= counter + 1;
                end
            end
            PixelLow: begin 
                if (counter >= threshold) begin
                    index <= index + 1;
                    if (index >= (pixel_width - 1)) begin
                        state <= Ready;
                        counter <= 0;
                    end else begin
                        state <= PixelHigh;
                        counter <= 0;
                        currentPixelData <= currentPixelData << 1;
                    end
                end else begin
                    state <= PixelLow;
                    counter <= counter + 1;
                end
            end
            Reset: begin 
                if (counter == threshold) begin
                    state <= Ready;
                    counter <= 0;
                end else begin
                    state <= Reset;
                    counter <= counter + 1;
                end
            end
        endcase
    end
    
    always @ (posedge clk) begin
        case (state)
            PixelHigh: begin
                threshold <= currentPixelData[(pixel_width - 1)] == 1'b0 ? T0H : T1H;
                data_out <= 1;
            end
            PixelLow: begin
                threshold <= currentPixelData[(pixel_width - 1)] == 1'b0 ? T0L : T1L;
                data_out <= 0;
            end
            Reset: begin
                threshold <= TRST;
                data_out <= 0;
            end
            default: begin
                threshold <= threshold;
                data_out <= data_out;
            end
        endcase
    end
endmodule

module led_controller # (
    parameter T0H = 30,
    parameter T1H = 60,
    parameter T0L = 90,
    parameter T1L = 60,
    parameter TRST = 8000,
    parameter ADDR_WIDTH = 32,
    parameter PIXEL_WIDTH = 24,
    parameter PIXEL_OFFSET = 4
)(
        input wire clk,
        input wire aresetn,
        input wire [ADDR_WIDTH - 1:0] dout,
        output reg [ADDR_WIDTH - 1:0] addr,
        output reg en,
        output wire led_data,
        output reg [3:0]web,
        output reg rst
    );
    
    localparam Idle = 0;
    localparam RequestPixelCount = 1;
    localparam WaitForPixelCount = 2;
    localparam SetPixelCount = 3;
    localparam IsValidToContinue = 4;
    localparam WaitForPixelValue = 5;
    localparam GetPixelValue = 6;
    localparam WaitForHandShake = 7;
    localparam ShakeHand = 8;
    localparam AdvanceState = 9;
    
    reg [3:0] state;
    reg [PIXEL_WIDTH -1 : 0] nextPixelData;
    reg [ADDR_WIDTH -1 : 0] pixelCount;
    reg [ADDR_WIDTH -1 : 0] pixelIndex;
    reg handshake;
    reg set_reset;
    wire handshake_in;
    
    initial begin
        state = Idle;
        pixelCount = 0;
        addr = 0;
        pixelIndex = 0;
        set_reset = 0;
        handshake = 0;
    end
    
    transmitter #(.T0H(T0H), .T1H(T1H), .T0L(T0L), .T1L(T1L), .TRST(TRST), .pixel_width(PIXEL_WIDTH)) transmitter_int(
        .clk(clk),
        .reset(set_reset),
        .ready_in(handshake),
        .pixelData(nextPixelData),
        .ready_out(handshake_in),
        .data_out(led_data)
    );
    
    always @ (posedge clk) begin
        rst <= 0;
        web <= 0;
    end
    
    always @ (posedge clk) begin
        if (aresetn == 1'b0) begin
            state <= Idle;
            addr <= 0;
            en <= 0;
            pixelCount <= 0;
            nextPixelData <= 0;
            set_reset <= 0;
            handshake <= 0;
            pixelIndex <= 0;
        end else begin
            case (state)
                Idle: begin
                    state <= RequestPixelCount;
                end
                RequestPixelCount: begin
                    addr <= 0;
                    en <= 1;
                    state <= WaitForPixelCount;
                end
                WaitForPixelCount: begin
                    en <= 0;
                    state <= SetPixelCount;
                end
                SetPixelCount: begin
                    pixelCount <= dout;
                    state <= IsValidToContinue;
                end
                IsValidToContinue: begin
                    if (pixelCount == 0) begin
                        state <= RequestPixelCount;
                    end else if (pixelIndex >= pixelCount) begin
                        state <= WaitForHandShake;
                        set_reset <= 1;
                    end else begin
                        addr <= addr + PIXEL_OFFSET;
                        en <= 1;
                        state <= WaitForPixelValue;
                    end
                end
                WaitForPixelValue: begin
                    state <= GetPixelValue;
                    en <= 0;
                end
                GetPixelValue: begin
                    state <= WaitForHandShake;
                    nextPixelData <= dout[PIXEL_WIDTH -1 : 0];
                end
                WaitForHandShake: begin
                    if (handshake_in == 1) begin
                        state <= ShakeHand;
                        handshake <= 1;
                    end else begin
                        state <= WaitForHandShake;
                        handshake <= 0;
                    end
                end
                ShakeHand: begin
                    if (handshake_in == 0) begin
                        state <= AdvanceState;
                        handshake <= 0;
                    end else begin
                        state <= ShakeHand;
                        handshake <= 1;
                    end
                end
                AdvanceState: begin
                    if (set_reset == 1) begin
                        state <= RequestPixelCount;
                        pixelIndex <= 0;
                        set_reset <= 0;
                    end else begin
                        state <= IsValidToContinue;
                        pixelIndex <= pixelIndex + 1;
                    end
                end
            endcase
        end
    end
endmodule
