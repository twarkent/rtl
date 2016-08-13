// ------------------------------------------------------------------------------------------------
// Copyright (c) 2015, Tim Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : cache_vector.sv
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: Keep a vector of free/used cache pages.
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME            DEFAULT        DESCRIPTION
//   --------------- -------------- ---------------------------------------------------------------
//   PAGES           32             Number of pages in cache.
//   AWIDTH*         $clog2(PAGES)  Bit-width of address. *Treat as localparam.
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:      Asynchronous
//   Clock Domains:       generic
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    None
//   Synthesizable:       Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS: 
//   priority_encoder
// ------------------------------------------------------------------------------------------------
// NOTES:
// ------------------------------------------------------------------------------------------------

module cache_vector # ( 
   
  parameter PAGES  = 32,
  parameter AWIDTH = $clog2(PAGES) ) (

  input                   clk,
  input                   rst,

  input                   page_clr,       // cache page clear request
  input      [AWIDTH-1:0] page_id_clr,    // cache page to release
  input                   page_req,       // cache page request

  output reg [AWIDTH-1:0] page_id,        // cache page id 
  output reg              page_grant );   // Asserted if page is available. i.e. page_id is valid


  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------  
  localparam LSB_TO_MSB = 0;


  // ---------------------------------------------------------------------------
  // Signal Declarations
  // ---------------------------------------------------------------------------  
  logic [AWIDTH-1:0] page_addr;
  logic  [PAGES-1:0] page_vector;
  logic  [PAGES-1:0] page_select;
  logic  [PAGES-1:0] page_clear;
  logic              page_avail;
  logic              page_valid;


  // ---------------------------------------------------------------------------
  // Signal Assignments
  // ---------------------------------------------------------------------------
  assign page_clear = (page_clr)? (1'b1<<page_id_clr) : '0;


  // ---------------------------------------------------------------------------
  // Instantiations
  // ---------------------------------------------------------------------------
  
  // Determine the location of the next available cache page. 
  priority_encoder #(

    .VWIDTH     ( PAGES ),         // bit-width of input vector
    .PIPELINE   ( 0 ),             // 0: Do not pipeline
    .SEARCH_DIR ( LSB_TO_MSB ),    // 0: Search lsb to msb
    .SEARCH_VAL ( 1 ) )            // 1: Find first lsb that is set
    
    priority_encoder (
      .clk    ( clk ),             // I
      .rst    ( rst ),             // I
      .vector ( page_vector ),     // I [VWIDTH-1:0]
      .addr   ( page_addr ),       // O [$clog(PAGES)-1:0]
      .found  ( page_avail ),      // O True if a bit is set in page_vector (indicates available page)
      .dv     ( page_valid )       // O
    );


  // ---------------------------------------------------------------------------
  // Combinational Logic
  // ---------------------------------------------------------------------------

  // Find the lsb that is set. This is a one-hot encoded vector that indicates 
  // the first available cache page.
  always_comb
    page_select = page_vector & ~(page_vector - 1'b1);


  // ---------------------------------------------------------------------------
  // Sequential Logic
  // ---------------------------------------------------------------------------
  always_ff @ ( posedge clk, posedge rst )
    if ( rst ) begin 
      page_vector <= '1;         // A '1' indicates an available cache page
      page_id     <= '0; 
      page_grant  <= '0;
    end else begin
      page_vector <= page_vector|page_clear;
      page_id     <= page_addr;
      page_grant  <= '0;

      if ( page_req && page_avail ) begin
        page_vector <= (page_vector|page_clear) ^ page_select;
        page_grant  <= '1;
      end
    end


endmodule

