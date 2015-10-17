// ------------------------------------------------------------------------------------------------
// Copyright (c) 2015, Tim Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : nco.sv
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: Numerically controlled oscillator. The output frequency is determined by the following
//          equation:
//
//            fo = (M * fc)/2^n), where:
//               M  = Tuning Word (Delta Phase)
//               fc = Frequency of clk
//               n  = Bit-width of accumulator
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME              DEFAULT        DESCRIPTION
//   ----------------- -------------- -------------------------------------------------------------
//   ACCUMULATOR_WIDTH 32             Bit-width of phase accumulator
//   TABLE_WIDTH       14             Bit-width of phaee-to-amplitude converter (RAM)
//   TABLE_DEPTH       256            Depth of taple to store amplitude values from 0 to 90 degrees.
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:      Asynchronous active-high
//   Clock Domains:       generic
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    None
//   Synthesizable:       Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS: memory
// ------------------------------------------------------------------------------------------------
// NOTE: The phase to amplitude converter RAM only stores the amplitude from 0 to 90 degrees 
//       because the quadrature data is contained in the two msbs of the phase accumulator.
// ------------------------------------------------------------------------------------------------
module nco #(

  parameter ACCUMULATOR_WIDTH = 32,       // Bit-width of phase accumulator
  parameter TABLE_WIDTH       = 14,       // Bit-width of the amplitude
  parameter TABLE_DEPTH       = 256)      // Depth of memory -- stores 1/4 of the wave's amplitude

  (
    input                                 clk,
    input                                 rst,
    interface                             bus       // clk, rst, addr, wr, wdata, rdata
    input                                 en,
    input                                 load,
    input               [TABLE_WIDTH-1:0] delta_phase, 
    output signed logic [TABLE_WIDTH-1:0] amplitude
  );

  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam AWIDTH = $clog2(DEPTH);


  // ---------------------------------------------------------------------------
  // Signal Declarations
  // ---------------------------------------------------------------------------
  logic  [WIDTH-1:0] phase_accumulator;
  logic  [WIDTH-1:0] delta_phase_reg;
  logic              sign;
  logic              invert_slope;
  
  logic              mem_clk   [2];
  logic [AWIDTH-1:0] mem_addr  [2];
  logic  [WIDTH-1:0] mem_rdata [2];
  logic  [WIDTH-1:0] mem_wdata;
  logic              mem_wr;


  // ---------------------------------------------------------------------------
  // Signal Assignments & combinational logic
  // ---------------------------------------------------------------------------
  // Amplitude RAM Port-A ---------------------
  assign mem_clk[0]   = bus.clk;
  assign mem_wr       = bus.wr;
  assign mem_addr[0]  = bus.addr;
  assign mem_wdata    = bus.wdata;
  assign bus.rdata    = mem_rdata[0];

  // Amplitude RAM Port-B ---------------------
  assign mem_clk[1]   = clk;

  assign negative     = phase_accumulator[ACCUMULATOR_WIDTH-1];
  assign invert_slope = phase_accumulator[ACCUMULATOR_WIDTH-2];

  // The RAM only stores values for 0 to 90 degrees, so the address bits to the 
  // RAM need to be inverted during a negative slope. 
  always_comb begin
    if ( invert_slope )
      mem_addr[1] = ~phase_accumulator[ACCUMULATOR_WIDTH-3:0];
    else
      mem_addr[1] =  phase_accumulator[ACCUMULATOR_WIDTH-3:0];
  end


  // ---------------------------------------------------------------------------
  // Sequential Logic
  // ---------------------------------------------------------------------------

  // Register amplitude output and switch sign if phase > 180 degrees
  always_ff @( posedge clk, posedge rst )
    if ( rst )
      amplitude <= '0;
    else begin
      if ( negative )
        amplitude = ~mem_rdata[1] + 1'b1; // Switch to negative amplitude
      else
        amplitude =  mem_rdata[1];
    end

  // Load new delta phase when requested and accumulate phase when enabled
  always_ff @( posedge clk, posedge rst )
    if ( rst ) begin
      delta_phase_reg   <= '0;
      phase_accumulator <= '0;

    end else if ( load ) begin
      delta_phase_reg   <= delta_phase;
      phase_accumulator <= '0;

    end else if ( en ) begin
      phase_accumulator <= phase_accumulator + delta_phase_reg;
    end


  // ---------------------------------------------------------------------------
  // Module Instantiations
  // ---------------------------------------------------------------------------
  memory #(

    .DEPTH      ( DEPTH ),
    .WIDTH      ( WIDTH ),
    .CLKS       ( 2 ),
    .PORTS      ( 2 ),
    .WR_PORTS   ( 1 ),
    .RD_PORTS   ( 2 ),
 
    phaase_to_amplitude_converter (
      .clk  ( mem_clk ),               // I     [CLKS-1:0]
      .wr   ( mem_wr ),                // I [WR_PORTS-1:0]
      .addr ( mem_addr ),              // I   [AWIDTH-1:0] addr [PORTS]
      .din  ( mem_wdata ),             // I    [WIDTH-1:0] din  [WR_PORTS]
      .dout ( mem_rdata )              // O    [WIDTH-1:0] dout [RD_PORTS]
    );


endmodule

