`timescale 1ns / 10ps
// ------------------------------------------------------------------------------------------------
// Copyright (c) 2012, Tim Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : rnd_robin_arbiter.sv
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// Description  : Arbitration with rotating fairness.
// -----------------------------------------------------------------------------
// KEYWORDS: round-robin arbiter
// -----------------------------------------------------------------------------
// Parameters
//   NAME              DEFAULT      DESCRIPTION
//   ----------------- ------------ --------------------------------------------
//   PORTS             8            Number of ports to arbitrate
//   REG_OUTPUT        1            Register outputs.
// -----------------------------------------------------------------------------
// Reuse Issues:
//   Reset Strategy:      Asynchronous
//   Clock Domains:       generic clk
//   Critical Timing:     grant_port -> this may create timing issues
//   Test Features:       None
//   Asynchronous I/F:    None
//   Instantiations:      None
//   Synthesizable:       Yes
// -----------------------------------------------------------------------------
// NOTES:
//  1. 'priority_ctr' is a one-hot signal indicating the first request that 
//     should be considered for a grant (given priority). If the port with 
//     priority is not requesting access, then the next higher indexed port 
//     requesting access is given the grant. This continues and wraps around 
//     to the lower bits.
//
//  2. Access is granted to a port until the next enable which may pass access 
//     to another port. A port continues to have access if no other port 
//     requests access.
//
// EXAMPLES:
//   request      ->        0110          1100
//   request_2w   ->   0110_0110     1100_1100  double request
//   priority_ctr -> -      1000          0001
//                     ---------     ---------
//   difference        0101_1110     1100_1011
//  ~difference        1010_0001     0011_0100
//   request_2w      & 0110_0110     1100_1100
//                     ---------     ---------
//   request[1] wins   0010_0000     0000_0100  request[2] wins
// -----------------------------------------------------------------------------

module rnd_robin_arbiter #( 

  parameter PORTS      = 8,
  parameter REG_OUTPUT = 1 )

  (
    input                            clk,
    input                            rst,          // Asynchronous reset
    input                            enable,       // Assert to advance the ring counter
    input                [PORTS-1:0] request,
    output logic         [PORTS-1:0] grant,        // one-hot encoded vector
    output logic [$clog2(PORTS)-1:0] grant_port,   // port number of the grant
    output logic                     grant_port_dv
  );


  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam PORTS_LOG2 = $clog2(PORTS);


  // ---------------------------------------------------------------------------
  // Signal Declarations 
  // ---------------------------------------------------------------------------
  wire     [2*PORTS-1:0] request_2w   = {request,request};
  wire     [2*PORTS-1:0] grant_2w     = request_2w & ~(request_2w-priority_ctr);
  wire       [PORTS-1:0] grant_next   = grant_2w[PORTS-1:0] | grant_2w[2*PORTS-1:PORTS];
  logic      [PORTS-1:0] priority_ctr;
  logic [PORTS_LOG2-1:0] grant_addr;


  // ---------------------------------------------------------------------------
  // Module Instantiations
  // ---------------------------------------------------------------------------
  priority_encoder #(

    .VWIDTH     ( PORTS ),         // bit-width of input vector
    .PIPELINE   ( REG_OUTPUT ),    // Only register the last stage.
    .SEARCH_DIR ( 0 ),             // 0: Search lsb to msb, 1: Search msb to lsb
    .SEARCH_VAL ( 1 ))             // 0: Find first 0, 1: Find first 1

    priority_encoder ( 
      .clk    ( clk ),             // I
      .rst    ( rst ),             // I
      .vector ( grant_next ),      // I [VWIDTH-1:0]  Vector to search
      .addr   ( grant_port ),      // O [AWIDTH-1:0]  bit-position of first SEARCH_VAL found   
      .valid  ( grant_port_dv )    // O               indicates 'addr' output is valid and SEARCH_VAL found
    );


  // ---------------------------------------------------------------------------
  // Sequential Logic
  // ---------------------------------------------------------------------------

  // Create a one-hot priority ring counter (token)
  // Set the lsb on reset. NOTE: Only one bit must be set.
  // The channel winning the arbitration receives the token.
  always_ff @( posedge clk, posedge rst ) begin
    if ( rst )
      priority_ctr <= { {(PORTS-1){1'b0}}, 1'b1 };   
    else if ( enable )
      priority_ctr <= {grant_next[PORTS-2:0],grant_next[PORTS-1]};
  end

  generate 
    if ( REG_OUTPUT ) begin: reg_output
      always_ff @( posedge clk, posedge rst ) begin
	if ( rst ) begin
	  grant <= '0;
	end else if ( enable ) begin
	  grant <= grant_next;
	end
      end
    end else begin: comb_output
      assign grant = grant_2w[PORTS-1:0] | grant_2w[2*PORTS-1:PORTS];
    end
  endgenerate


endmodule

