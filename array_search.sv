// ------------------------------------------------------------------------------------------------
// Copyright (c) 2012, Timothy Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : array_search.sv
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: Find the min or max in an array.
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME              DEFAULT      DESCRIPTION
//   ----------------- ------------ ---------------------------------------------------------------
//   DWIDTH            8            Data bit-width
//   DEPTH             8            Array Depth
//   PIPELINE          16'h1        0: Combinational logic, 1: Pipeline data-path. One bit per stage.
//   SEARCH_MAX        0            0: Search for minimum value. 1: Search for maximum value.
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:   Asynchronous active-high
//   Clock Domains:    Generic
//   Critical Timing:  Combinational logic from vector input to addr output if PIPELINE = 0 and 
//                     VWIDTH is large.
//   Test Features:    None
//   Asynchronous I/F: None
//   Synthesizable:    Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS:     array_search (recursive)
// ------------------------------------------------------------------------------------------------
// NOTES:
//
//   1. A PIPELINE parameter of 3'b011 would have the following effect given a DEPTH value of 8:
// 
//      --
//        |-A-
//      --    |
//            |-R-
//      --    |   |
//        |-A-    |
//      --        |
//                |-R,  Where A = Async output, R = Registered Output
//      --        |
//        |-A-    |
//      --    |   |
//            |-R-
//      --    |
//        |-A-
//      --

// ------------------------------------------------------------------------------------------------

module array_search #(

  parameter DWIDTH     = 8,                                     // Data bit-width.
  parameter DEPTH      = 8,                                     // Array Depth
  parameter PIPELINE   = 32'h7,                                 // Requires 1-bit per stage
  parameter SEARCH_MAX = 1'b0,                                  // 0: Search for min value, 1: search for max value
  parameter AWIDTH     = $clog2(DEPTH))

  (
    input                     clk,
    input                     rst,
    input        [DWIDTH-1:0] array [DEPTH],                    // Array to search

    output logic [AWIDTH-1:0] addr,                             // address of min/max value
    output logic [DWIDTH-1:0] data,
    output logic              dv                                // Indicates outputs are valid
  );


  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam LOW_DEPTH  = (DEPTH[0])? DEPTH/2+1 : DEPTH/2;
  localparam HIGH_DEPTH =  DEPTH/2;


  // ---------------------------------------------------------------------------
  // Logic (Sequential/Combinational) -- Depends on PIPELINE parameter
  // ---------------------------------------------------------------------------
  generate

    // -----------------------------------------------
    // Base case #1: Vector Width = 1
    // -----------------------------------------------
    if ( DEPTH == 1 ) begin: DEPTH_1
      if ( PIPELINE[0] ) begin: BASE_1_SEQ

        always_ff @ ( posedge clk, posedge rst )
          if ( rst ) begin
            addr  <= '0;
            data  <= '0;
            dv    <= '0;
          end else begin
            addr <= 1'b0;
            data <= array[0];
            dv   <= 1'b1;
          end
        end

      else begin: BASE_1_COMB
        assign addr  = 1'b0;
        assign data  = array[0];
        assign dv    = 1'b1;
      end

    // -----------------------------------------------
    // Base case #2: Vector Width = 2
    // -----------------------------------------------
    end else if ( DEPTH == 2 ) begin: DEPTH_2
      if ( PIPELINE[0] ) begin: BASE_2_SEQ
        always_ff @ ( posedge clk, posedge rst ) begin
          if ( rst ) begin
            addr <= '0;
            data <= '0;
            dv   <= '0;
          end else begin
            dv <= '1;

            // Search for min/max value
            if ( array[1] >= array[0] ) begin
              addr <= SEARCH_MAX;
              data <= array[SEARCH_MAX];
            end else begin
              addr <= ~SEARCH_MAX;
              data <= array[~SEARCH_MAX];
            end
          end
        end

      end else begin: BASE_2_COMB
        assign dv = 1'b1;
        always_comb begin
          if ( array[1] >= array[0] ) begin
            addr = SEARCH_MAX;
            data = array[SEARCH_MAX];
          end else begin
            addr = ~SEARCH_MAX;
            data = array[~SEARCH_MAX];
          end
        end
       
      end

    // -----------------------------------------------
    // Split the problem in half
    // -----------------------------------------------
    end else begin: DEPTH_N
 
      // Search lower half -----------------
      logic            [DWIDTH-1:0] low_array[LOW_DEPTH];
      logic [$clog2(LOW_DEPTH)-1:0] low_addr;
      logic            [DWIDTH-1:0] low_data;
      logic                         low_dv;

      assign low_array = array[0:LOW_DEPTH-1];

      array_search #(

        .DWIDTH     ( DWIDTH ),                 // Data bit-width.
        .DEPTH      ( LOW_DEPTH ),              // Array Depth
        .PIPELINE   ( PIPELINE[AWIDTH-1:1] ),   // Requires 1-bit per stage
        .SEARCH_MAX ( SEARCH_MAX ) )            // 0: Search for min value, 1: search for max value

        search_low (
          .clk    ( clk ),          // I
          .rst    ( rst ),          // I
          .array  ( low_array ),    // I
          .addr   ( low_addr ),     // O
          .data   ( low_data ),     // O
          .dv     ( low_dv )        // O
        );

      // Search upper half -----------------
      logic             [DWIDTH-1:0] high_array[HIGH_DEPTH];
      logic [$clog2(HIGH_DEPTH)-1:0] high_addr;
      logic             [DWIDTH-1:0] high_data;
      logic                          high_dv;

      assign high_array = array[LOW_DEPTH:DEPTH-1];

      array_search #(

        .DWIDTH     ( DWIDTH ),                 // Data bit-width.
        .DEPTH      ( HIGH_DEPTH ),             // Array Depth
        .PIPELINE   ( PIPELINE[AWIDTH-1:1] ),   // Requires 1-bit per stage
        .SEARCH_MAX ( SEARCH_MAX ) )            // 0: Search for min value, 1: search for max value

        search_high (
          .clk    ( clk ),          // I
          .rst    ( rst ),          // I
          .array  ( high_array ),   // I
          .addr   ( high_addr ),    // O
          .data   ( high_data ),    // O
          .dv     ( high_dv )       // O
        );

      // ----------------------------------------------------
      // Combine the outputs of the above 2 array searches
      // ----------------------------------------------------
      if ( PIPELINE[0] ) begin: COMBINE_SEQ // sequential
        always_ff @ ( posedge clk, posedge rst ) begin
          if ( rst ) begin
            addr <= '0;
            data <= '0;
            dv   <= '0;
          end else begin
            dv <= high_dv | low_dv;
            if ( high_data >= low_data ) begin
              addr <= (SEARCH_MAX)? {1'b1, high_addr} : {1'b0,low_addr};
              data <= (SEARCH_MAX)? high_data : low_data;
            end else begin
              addr <= (SEARCH_MAX)? {1'b0, low_addr} : {1'b1,high_addr};
              data <= (SEARCH_MAX)? low_data : high_data;
            end
          end
        end

      end else begin: COMBINE_COMB // combinational
        assign dv = high_dv | low_dv;
        if ( SEARCH_MAX ) begin: COMBINE_COMB_MAX
          assign addr = (high_data >= low_data)? {1'b1, high_addr} : {1'b0,low_addr};
          assign data = (high_data >= low_data)? high_data : low_data;
        end else begin: COMBINE_COMB_MIN
          assign addr = (high_data >= low_data)? {1'b0, low_addr} : {1'b1,high_addr};
          assign data = (high_data >= low_data)? low_data : high_data;
        end
      end
    end
  endgenerate


endmodule

