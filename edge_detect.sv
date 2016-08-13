`timescale 1ns / 10ps
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// File         : edge_detect.sv
// Author       : Tim Warkentin
// Date         : 2015/12/23
//
// Description  : Edge detect a signal and create a pulse for one clock period.
//                The edge to detect can be rising, falling, or any, and 
//                depends on the parameter 'EDGE'.
// -----------------------------------------------------------------------------
// KEYWORDS: edge detect
// -----------------------------------------------------------------------------
// Parameters
//   NAME              VALUE        DESCRIPTION
//   ----------------- ------------ --------------------------------------------
//   EDGE              2'b01        Rising-Edge
//                     2'b10        Falling-Edge
//                     2'b11        Any Edge
//   SYNC              1'b1         Synchronize din to clk before edge detection.
// -----------------------------------------------------------------------------
// Reuse Issues:
//   Reset Strategy:      Asynchronous
//   Clock Domains:       generic clk
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    None
//   Instantiations:      None
//   Synthesizable:       Yes
// -----------------------------------------------------------------------------
// NOTES:
// -----------------------------------------------------------------------------
module edge_detect #( 

  parameter EDGE = 2'b11,  
  parameter SYNC = 1'b1 )(

  input        clk,
  input        rst,
  input        din,
  output logic pulse );


  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam RISING  = 2'b01;
  localparam FALLING = 2'b10;
  localparam ANY     = 2'b11;
 

  // ---------------------------------------------------------------------------
  // Signal Declarations
  // ---------------------------------------------------------------------------
  logic [1:0] din_sync;


  // ---------------------------------------------------------------------------
  // Synchronous Logic
  // ---------------------------------------------------------------------------
  generate
    if (SYNC) begin : sync_stage

      // Sync incoming signal to this clock domain
      (* ASYNC_REG = "TRUE" *) logic din_meta;

      always @(posedge clk) begin
        din_meta <= din;
        din_sync <= {din_sync[0], din_meta};
      end

    end else begin : direct_sample
      always @(posedge clk) begin
        din_sync <= {din_sync[0], din};
      end
    end
  endgenerate    

  always @(posedge clk, posedge rst)
    if (rst)
      pulse <= 1'b0;
    else if ( EDGE == RISING )
      pulse <=  din_sync[0] & ~din_sync[1];
    else if ( EDGE == FALLING )
      pulse <= ~din_sync[0] &  din_sync[1];
    else if ( EDGE == ANY )
      pulse <=  din_sync[0] ^  din_sync[1];


endmodule


