// ------------------------------------------------------------------------------------------------
// Copyright (c) 2012, Timothy Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : priority_encoder.v
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
//   PIPELINE          16'h7        0: Combinational logic, 1: Pipeline data-path. One bit per stage.
//   SEARCH_DIR        0            0: search lsb to msb,   1: search msb to lsb
//   SEARCH_VAL        0            0: Find first 0,        1: Find first 1
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:   Asynchronous
//   Clock Domains:    Generic
//   Critical Timing:  Combinational logic from vector input to addr output if PIPELINE = 0 and 
//                     VWIDTH is large.
//   Test Features:    None
//   Asynchronous I/F: None
//   Synthesizable:    Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS:     priority_encoder.v (recursive)
// ------------------------------------------------------------------------------------------------
// NOTES:
//
//   1. A PIPELINE parameter of 16'h1 would have the following effect given a VWDITH of 8:
// 
//      --
//        |-A-
//      --    |
//            |-
//      --    | |
//        |-A-  |
//      --      |
//              |-R,  Where A = Async output, R = Registered Output
//      --      |
//        |-A-  |
//      --    | |
//            |-
//      --    |
//        |-A-
//      --

// ------------------------------------------------------------------------------------------------

module priority_encoder #(

  parameter VWIDTH     = 8,                                     // bit-width of input vector
  parameter PIPELINE   = 32'h1,                                 // Requires 1-bit per stage
  parameter SEARCH_DIR = 1'b0,                                  // 0: Search lsb to msb, 1: Search msb to lsb
  parameter SEARCH_VAL = 1'b0,                                  // 0: Find first 0, 1: Find first 1
  parameter AWIDTH     = (VWIDTH==1)? 1 : $clog2(VWIDTH))

  (
    input                     clk,
    input                     rst,

    input        [VWIDTH-1:0] vector,                           // Vector to search
    output logic [AWIDTH-1:0] addr,                             // bit-position of first SEARCH_VAL found
    output logic              valid                             // indicates 'addr' output is valid and SEARCH_VAL found
  );


  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam LSB_TO_MSB = 0;
  localparam LWIDTH     = (VWIDTH[0])? VWIDTH/2+1 : VWIDTH/2;
  localparam HWIDTH     = VWIDTH/2;


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
            addr  <= '0;
            valid <= '0;
          end else begin
            addr  <= 1'b0;
            if ( SEARCH_VAL == 1'b1 ) begin: SEARCH_1
              valid <= vector;                       // Searching for a '1', so set if vector == 1
            end else begin: SEARCH_0
              valid <= !vector;                      // Searching for a '0', so set if vector == 0
            end
          end
        end

      else begin: BASE_1_COMB
        assign addr  = 1'b0;
        assign valid = (SEARCH_VAL==1'b1)? vector : !vector;
      end

    // -----------------------------------------------
    // Base case #2: Vector Width = 2
    // -----------------------------------------------
    end else if ( VWIDTH == 2 ) begin: WIDTH_2
      if ( PIPELINE[0] ) begin: BASE_2_SEQ
        always_ff @ ( posedge clk, posedge rst ) begin
          if ( rst ) begin
            addr  <= '0;
            valid <= '0;
          end else begin
            if ( SEARCH_VAL == 1'b1 ) begin: SEARCH_1
              valid <= |vector;                      // Looking for a '1', so set if vector contains a '1'
              if ( SEARCH_DIR == LSB_TO_MSB )
                addr <= !vector[0];
              else
                addr <= vector[1];
            end else begin: SEARCH_0
              valid <= !(&vector);                   // Looking for a '0', so set if vector contains a '0'.
              if ( SEARCH_DIR == LSB_TO_MSB )
                addr <= vector[0];
              else
                addr <= !vector[1];
            end
          end
        end

      end else begin: BASE_2_COMB
        if ( SEARCH_VAL == 1'b1 ) begin: SEARCH_1
          assign valid = |vector;
          if ( SEARCH_DIR == LSB_TO_MSB ) begin: START_LSB
            assign addr  = !vector[0];
          end else begin: START_MSB
            assign addr  = vector[1];
          end
        end else begin: SEARCH_0
          assign valid = !(&vector);
          if ( SEARCH_DIR == LSB_TO_MSB ) begin: START_LSB
            assign addr  = vector[0];
          end else begin: START_MSB
            assign addr  = !vector[1];
          end
        end
      end

    // -----------------------------------------------
    // Split the problem in half
    // -----------------------------------------------
    end else begin: WIDTH_N

      logic [AWIDTH-2:0] addr_low;
      logic [AWIDTH-2:0] addr_high;

      logic              valid_low;
      logic              valid_high;

      // Lower half
      priority_encoder #(

        .VWIDTH     ( LWIDTH ),
        .PIPELINE   ( PIPELINE[AWIDTH-1:1] ),
        .SEARCH_DIR ( SEARCH_DIR ),
        .SEARCH_VAL ( SEARCH_VAL ) )

        pe_low (
          .clk    ( clk ),
          .rst    ( rst ),
          .vector ( vector[VWIDTH/2-1:0] ),
          .addr   ( addr_low ),
          .valid  ( valid_low )
        );

      // Upper half
      priority_encoder #(

        .VWIDTH     ( HWIDTH ),
        .PIPELINE   ( PIPELINE[AWIDTH-1:1] ),
        .SEARCH_DIR ( SEARCH_DIR ),
        .SEARCH_VAL ( SEARCH_VAL ) )

        pe_high (
          .clk    ( clk ),
          .rst    ( rst ),
          .vector ( vector[VWIDTH-1:VWIDTH/2] ),
          .addr   ( addr_high ),
          .valid  ( valid_high )
        );

      // ----------------------------------------------------
      // Combine the outputs of the above 2 priority encoders
      // ----------------------------------------------------
      if ( PIPELINE[0] ) begin: COMBINE_SEQ // sequential
        always_ff @ ( posedge clk, posedge rst ) begin
          if ( rst ) begin
            addr  <= '0;
            valid <= '0;
          end else begin
            valid <= valid_high | valid_low;
            if ( SEARCH_DIR == LSB_TO_MSB ) begin: START_LSB
              addr  <= (valid_low)? {1'b0,addr_low} : {1'b1, addr_high};
            end else begin: START_MSB
              addr  <= (valid_high)? {1'b1,addr_high} : {1'b0, addr_low};
            end
          end
        end

      end else begin: COMBINE_COMB // combinational
        if ( SEARCH_DIR == LSB_TO_MSB ) begin: START_LSB
          assign addr  = (valid_low)? {1'b0,addr_low} : {1'b1,addr_high};
        end else begin: START_MSB
          assign addr  = (valid_high)? {1'b1,addr_high} : {1'b0,addr_low};
        end
        assign valid =  valid_high | valid_low;
      end
    end
  endgenerate


endmodule

// --------------------------------------------------------------------------------------------------
// Release History
//   Version Date        Author            Description
//   ------- ----------- ----------------- ----------------------------------------------------------
//   1.0     2012/02/14  Tim Warkentin     Initial version.
// --------------------------------------------------------------------------------------------------
