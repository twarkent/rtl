// ------------------------------------------------------------------------------------------------
// Copyright (c) 2012, Timothy Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : vector_adder.v
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: Find the msb/lsb one or zero of a vector. This creates a balanced binary search tree
//          decoder to improve timing margins (compared to a sequential search).
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME              DEFAULT      DESCRIPTION
//   ----------------- ------------ ---------------------------------------------------------------
//   VWIDTH            8            Vector bit-width
//   PIPELINE          16'h1        0: Combinational logic, 1: Pipeline data-path. One bit per stage.
//   SEARCH_VAL        1            0: Sum the number of 0's in the vector. 
//                                  1: Sum the number of 1's in the vector.
//   SWIDTH            $clog2(VWIDTH) 
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:   Asynchronous
//   Clock Domains:    Generic
//   Critical Timing:  Combinational logic from vector input to addr output if PIPELINE = 0
//                     and VWIDTH is large.
//   Test Features:    None
//   Asynchronous I/F: None
//   Synthesizable:    Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS:     vector_adder (recursive)
// ------------------------------------------------------------------------------------------------
// NOTES:
//
//   1. A PIPELINE parameter of 3'b011 would have the following effect given a VWDITH of 8:
// 
//      --
//        |-A-
//      --    |
//            |-R-
//      --    |   |
//        |-A-    |
//        --      |
//                |-R,  Where A = Async output, R = Registered Output
//      --        |
//        |-A-    |
//      --    |   |
//            |-R-
//      --    |
//        |-A-
//      --

// ------------------------------------------------------------------------------------------------

module vector_adder #(

  parameter VWIDTH     = 8,                                     // bit-width of input vector
  parameter PIPELINE   = 32'h1,                                 // Requires 1-bit per stage
  parameter SEARCH_VAL = 1'b0,                                  // 0: Sum 0's, 1: Sum 1's
  parameter SWIDTH     = (VWIDTH==1)? 1 : $clog2(VWIDTH))       // Bit-width of sum. Treat as localparam 

  (
    input                     clk,
    input                     rst,

    input        [VWIDTH-1:0] vector,                           // Vector to search
    output logic [SWIDTH-1:0] sum,                              // Sum of SEARCH_VAL's found
    output logic              valid                             // Indicates 'sum' output is valid
  );


  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam LWIDTH = (VWIDTH[0])? VWIDTH/2+1 : VWIDTH/2;
  localparam HWIDTH = VWIDTH/2;


  // ---------------------------------------------------------------------------
  // Logic (Sequential/Combinational) -- Depends on PIPELINE parameter
  // ---------------------------------------------------------------------------
  generate

    // -----------------------------------------------
    // Base case #1: Vector Width = 1
    // -----------------------------------------------
    if ( VWIDTH == 1 ) begin: WIDTH_1
      if ( PIPELINE[0] ) begin: BASE_1_SEQ

        always_ff @ ( posedge clk, posedge rst )
          if ( rst ) begin
            sum   <= '0;
            valid <= '0;
          end else begin
            valid <= 1'b1;
            if ( SEARCH_VAL == 1'b1 ) begin: SEARCH_1
              sum <=  vector;
            end else begin: SEARCH_0
              sum <= !vector;
            end
          end
        end

      else begin: BASE_1_COMB
        assign sum   = (SEARCH_VAL==1'b1)? vector : !vector;
        assign valid = 1'b1;
      end

    // -----------------------------------------------
    // Base case #2: Vector Width = 2
    // -----------------------------------------------
    end else if ( VWIDTH == 2 ) begin: WIDTH_2
      if ( PIPELINE[0] ) begin: BASE_2_SEQ
        always_ff @ ( posedge clk, posedge rst ) begin
          if ( rst ) begin
            sum   <= '0;
            valid <= '0;
          end else begin
            valid <= 1'b1;
            if ( SEARCH_VAL == 1'b1 ) begin: SEARCH_1
              sum[0] <=   vector[0] ^ vector[1];
              sum[1] <=   vector[0] & vector[1];
            end else begin: SEARCH_0
              sum[0] <=   vector[0] ^ vector[1];
              sum[1] <= ~(vector[0] | vector[1]);
            end
          end
        end

      end else begin: BASE_2_COMB
        assign valid = 1'b1;
        if ( SEARCH_VAL == 1'b1 ) begin: SEARCH_1
          assign sum[0] <=   vector[0] ^ vector[1];
          assign sum[1] <=   vector[0] & vector[1];
        end else begin: SEARCH_0
          assign sum[0] <=   vector[0] ^ vector[1];
          assign sum[1] <= ~(vector[0] | vector[1]);
        end
      end

    // -----------------------------------------------
    // Split the problem in half
    // -----------------------------------------------
    end else begin: WIDTH_N

      logic [SWIDTH-2:0] sum_low;
      logic [SWIDTH-2:0] sum_high;

      logic              valid_low;
      logic              valid_high;

      // Sum Lower half
      vector_adder #(

        .VWIDTH     ( LWIDTH ),
        .PIPELINE   ( PIPELINE[SWIDTH-1:1] ),
        .SEARCH_VAL ( SEARCH_VAL ) )

        adder_low (
          .clk    ( clk ),
          .rst    ( rst ),
          .vector ( vector[VWIDTH/2-1:0] ),
          .sum    ( sum_low ),
          .valid  ( valid_low )
        );

      // Sum Upper half
      vector_adder #(

        .VWIDTH     ( HWIDTH ),
        .PIPELINE   ( PIPELINE[SWIDTH-1:1] ),
        .SEARCH_VAL ( SEARCH_VAL ) )

        adder_high (
          .clk    ( clk ),
          .rst    ( rst ),
          .vector ( vector[VWIDTH-1:VWIDTH/2] ),
          .sum    ( sum_high ),
          .valid  ( valid_high )
        );

      // -----------------------------------------
      // Combine the outputs of the above 2 adders
      // -----------------------------------------
      if ( PIPELINE[0] ) begin: COMBINE_SEQ // sequential
        always_ff @ ( posedge clk, posedge rst ) begin
          if ( rst ) begin
            sum   <= '0;
            valid <= '0;
          end else begin
            valid <= valid_high;
            sum   <= sum_low + sum_high;
          end
        end

      end else begin: COMBINE_COMB // combinational
        assign sum   = sum_low + sum_high;
        assign valid = valid_high;
      end
    end
  endgenerate


endmodule

// --------------------------------------------------------------------------------------------------
// Release History
//   Version Date        Author            Description
//   ------- ----------- ----------------- ----------------------------------------------------------
//   1.0     2015/10/09  Tim Warkentin     Initial version.
// --------------------------------------------------------------------------------------------------

