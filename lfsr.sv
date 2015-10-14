// ------------------------------------------------------------------------------------------------
// Copyright (c) 2015, Tim Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : lfsr.sv
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: 
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME            DEFAULT        DESCRIPTION
//   --------------- -------------- ---------------------------------------------------------------
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:      Asynchronous active-high
//   Clock Domains:       generic
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    None
//   Synthesizable:       Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS: None
// ------------------------------------------------------------------------------------------------
module lfsr #(

  parameter WIDTH             = 16,
  parameter INITIAL_CONDITION = 1)

  (
    input              clk,
    input              rst,
    input              en,
    input  [WIDTH-1:0] taps,
    output [WIDTH-1:0] sr,
    output             sequence
  );

  assign sequence = sr[0];

  always_ff @( posedge clk, posedge rst)
    if ( rst )
      sr <= INITIAL_CONDITION
    else if ( en )
      sr <= sr 
    
      

endmodule
