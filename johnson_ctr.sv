// ------------------------------------------------------------------------------------------------
// Copyright (c) 2015, Tim Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : johnson_ctr.sv
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: 
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME            DEFAULT        DESCRIPTION
//   --------------- -------------- ---------------------------------------------------------------
//   DEPTH           128            Memory depth 
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:      Asynchronous active-high.
//   Clock Domains:       generic
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    None
//   Synthesizable:       Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS: None
// ------------------------------------------------------------------------------------------------
module johnson_ctr #(
  
  parameter WIDTH = 8 )

  (
    input              clk
    input              rst,
    output [WIDTH-1:0] ctr
  );

  always_ff @( posedge clk, posedge rst ) begin
    if ( rst )
      ctr <= '0;
    else
      ctr <= {~ctr[0], ctr[WIDTH-1:1]};
  end


endmodule
