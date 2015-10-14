// ------------------------------------------------------------------------------------------------
// FILE NAME      : cache_cam.v
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: A simple content addressable memory.
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME              DEFAULT        DESCRIPTION
//   ----------------- -------------- -------------------------------------------------------------
//   PAGES             32             Number of cache pages
//   KEY_WIDTH         14             Bit-width of key into CAM
//   PS_WIDTH          5              Bit-width of Parameter Set ID
//   AWIDTH            $clog2(PAGES)  Required address bit-width. Treat as a localparam.
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:      Synchronous
//   Clock Domains:       generic
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    None
//   Synthesizable:       Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS:        cache_vector
// ------------------------------------------------------------------------------------------------

module cache_cam #( 

  parameter PAGES      = 32,                // Number of cache pages available
  parameter KEY_WIDTH  = 14,                //
  parameter AWIDTH     = $clog2(PAGES))     //
  
  (
    input                                     clk,
    input                                     rst,

    input                                     en,
    input      cache_cam_pkg::cache_cam_cmd_e cmd,
    input                     [KEY_WIDTH-1:0] key,
    input                        [AWIDTH-1:0] clr_page_addr,
    input                                     clr_en,

    output reg                   [AWIDTH-1:0] page_addr,
    output cache_cam_pkg::cache_page_status_e page_status,
    output reg                                page_found,
    output reg                                page_grant,
    output reg                                page_dv,

    output                       [AWIDTH-1:0] page_eject_addr,
    output                                    page_eject_valid
  );

  import framework_pkg::*;


  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------  
  localparam LSB_TO_MSB = 0;


  // ---------------------------------------------------------------------------
  // Signal Declarations
  // ---------------------------------------------------------------------------  

  logic             [3:0] en_dly;
  logic   [KEY_WIDTH-1:0] key_dly        [2];

  cache_cam_cmd_e         cmd_dly        [3];

  logic   [KEY_WIDTH-1:0] search_fcn     [PAGES];
  logic       [PAGES-1:0] key_search;

  logic       [PAGES-1:0] page_vector;
  logic      [AWIDTH-1:0] page_id;
  logic                   page_valid;
  logic                   page_match;
  logic       [PAGES-1:0] page_eject_list;

  logic                   cache_page_req;
  logic                   cache_page_req_p;
  logic                   cache_page_access;
  logic                   cache_page_done;
  logic                   cache_page_clr;
  logic      [AWIDTH-1:0] cache_page_id;
  logic      [AWIDTH-1:0] cache_page_id_clr;
  logic                   cache_page_grant;
  logic                   cache_page_valid;
  logic                   cache_page_dirty;

  cache_cam_s [PAGES-1:0] cache_cam_table;    // Cache CAM lookup table

  integer p;

  cache_cam_cmd_e         last_cmd;


  // ---------------------------------------------------------------------------
  // Signal Assignments
  // ---------------------------------------------------------------------------
  assign cache_page_req    = en_dly[1] & ~page_match & (cmd_dly[1]==CMD_STORE);
  assign cache_page_access = en_dly[1] &  page_match & (cmd_dly[1]==CMD_STORE);
  assign cache_page_done   = en_dly[1] &  page_match & (cmd_dly[1]==CMD_DONE);
  assign cache_page_valid  = en_dly[1] &  page_match & (cmd_dly[1]==CMD_VALID);
  assign cache_page_dirty  = en_dly[1] &  page_match & (cmd_dly[1]==CMD_DIRTY);


  // ---------------------------------------------------------------------------
  // Instantiations
  // ---------------------------------------------------------------------------

  // Keep track of available cache pages
  cache_vector # ( .PAGES(PAGES) ) cache_vector (
    .clk          ( clk ),                  // I
    .rst          ( rst ),                  // I

    .page_clr     ( cache_page_clr ),       // I:              cache release request
    .page_id_clr  ( cache_page_id_clr ),    // I: [AWIDTH-1:0] cache number to release

    .page_req     ( cache_page_req ),       // I:              cache request
    .page_id      ( cache_page_id ),        // O: [AWIDTH-1:0] cache id 
    .page_grant   ( cache_page_grant )      // O:              cache_page_id is valid
  );

  // Convert the one-hot encoded page_vector to an address
  // The vector will equal zero if the page is not found
  priority_encoder #(

    .VWIDTH     ( PAGES ),                  // bit-width of input vector
    .PIPELINE   ( 1'b0 ),                   // 0: Do not pipeline
    .SEARCH_DIR ( LSB_TO_MSB ),             // 0: Search lsb to msb
    .SEARCH_VAL ( 1'b1 ) )                  // 1: Find first lsb that is set
    
    search (
      .clk    ( clk ),                      // I
      .rst    ( rst ),                      // I
      .vector ( page_vector ),              // I [VWIDTH-1:0]
      .addr   ( page_id ),                  // O [$clog(PAGES)-1:0]
      .valid  ( page_valid )                // O True if a bit is set in page_vector (indicates available page)
    );

  // Keep track of pages that have received HTM 'DONE' messages 
  // These pages are candidates for page ejection when the cache is full
  // If a page is added/erased the page_eject_list must also update
  priority_encoder #(

    .VWIDTH     ( PAGES ),                  // bit-width of input vector
    .PIPELINE   ( 1'b0 ),                   // 0: Do not pipeline
    .SEARCH_DIR ( LSB_TO_MSB ),             // 0: Search lsb to msb
    .SEARCH_VAL ( 1'b1 ) )                  // 1: Find first lsb that is set
    
    search_eject (
      .clk    ( clk ),                      // I
      .rst    ( rst ),                      // I
      .vector ( page_eject_list ),          // I [VWIDTH-1:0]
      .addr   ( page_eject_addr ),          // O [$clog(PAGES)-1:0]
      .valid  ( page_eject_valid )          // O True if a bit is set in page_eject_list
    );


  // ---------------------------------------------------------------------------
  // Combinational Logic
  // ---------------------------------------------------------------------------

  // Search CAM keys in parallel
  always_comb 
    for ( p=0; p<PAGES; p++ ) begin
      search_fcn[p] = cache_cam_table[p].key ^ key_dly[0];                       // search_fcn[p] = '0 if key matches
      key_search[p] = !(|search_fcn[p]) && (cache_cam_table[p].status != FREE);  // key_search[p] = '1 if key matches && page is used
    end

  // Control erasing of cache pages
  //  - A page can be erased by specifying the CAM key and erase command.
  //  - A page can be erased directly when clr_en is set.
  always_comb begin
    if ( clr_en ) begin
      cache_page_id_clr = clr_page_addr;
      cache_page_clr    = clr_en;
    end else begin
      cache_page_id_clr = page_id;
      cache_page_clr    = en_dly[1] & page_valid & (cmd_dly[1]==CMD_ERASE);
    end
  end


  // ---------------------------------------------------------------------------
  // Sequential Logic
  // ---------------------------------------------------------------------------

  // Control contents of the cache CAM table.
  always_ff @ ( posedge clk )
    if ( rst )
      cache_cam_table <= '0;

    else if ( cache_page_grant ) begin
      cache_cam_table[cache_page_id].key    <= key_dly[1];
      cache_cam_table[cache_page_id].ps_id  <= ps_id_dly[1];
      cache_cam_table[cache_page_id].status <= VALID;

    end else if ( cache_page_valid ) begin
      cache_cam_table[page_id].status <= VALID;

    end else if ( cache_page_dirty ) begin
      cache_cam_table[page_id].status <= DIRTY;

    end else if ( cache_page_chg_ps ) begin
      cache_cam_table[page_id].ps_id  <= ps_id_dly[1];
      cache_cam_table[page_id].status <= VALID;

    end else if ( cache_page_clr ) begin
      cache_cam_table[cache_page_id_clr].key    <= '0;
      cache_cam_table[cache_page_id_clr].ps_id  <= '0;
      cache_cam_table[cache_page_id_clr].status <= FREE;
    end

  // Search for the key (latency 2 clks) -- Possible to reduce latency if timing is not an issue
  //  - Clk 1: register key_dly[0]
  //  - Clk 2: register page_match and page_vector
  always_ff @ ( posedge clk )
    if ( rst ) begin
      page_match  <= '0;
      page_vector <= '0;
    end else if ( en_dly[0] ) begin
      page_match  <= |key_search;
      page_vector <=  key_search;
    end

  // Register outputs
  always_ff @ ( posedge clk )
    if ( rst ) begin
      page_addr   <= '0;
      page_status <= FREE;
      page_ps_id  <= '0;
      page_grant  <= '0;
      page_dv     <= '0;
      page_found  <= '0;

    end else begin
      page_dv    <= en_dly[2];
      page_grant <= cache_page_grant;
      page_found <= '0;

      if ( cache_page_grant ) begin    // New page request was successful
        page_addr   <= cache_page_id;
        page_ps_id  <= ps_id_dly[1];
        page_status <= RESERVED;
        page_found  <= page_match;

      end else if ( en_dly[2] ) begin
        page_addr   <= page_id;
        page_ps_id  <= cache_cam_table[page_id].ps_id;
        page_status <= cache_cam_table[page_id].status;
        page_found  <= page_match;
      end

    end

  // Keep track of commands issued and use to control page_eject_list
  // A delayed version of the command is needed for 'page_dv' latency-matching.
  always_ff @ ( posedge clk )
    if ( rst )
      last_cmd <= CMD_NOP;
    else if ( en_dly[2] )
      last_cmd <= cmd_dly[2];

  // Keep track of pages available for ejection (each bit in the vector represents a page)
  //  - A set bit indicates the page is available for ejection.
  //  - Set the page bit if the page is erased or sees an HTM 'DONE' message
  //  - Clear the page bit if the page is added.
  always_ff @ ( posedge clk ) begin
    if ( rst )
      page_eject_list <= '1; 

    else if ( page_dv ) begin
      if ( page_grant || page_found ) begin
        if ( (last_cmd==CMD_ERASE) || (last_cmd==CMD_DONE) )
          page_eject_list[page_addr] <= 1'b1;
        else if ( last_cmd == CMD_STORE )
          page_eject_list[page_addr] <= 1'b0;
      end
    end

    else if ( clr_en ) begin
      page_eject_list[clr_page_addr] <= 1'b1;
    end
  end

  // ----------------------------------
  // Register inputs when enable is set
  // ----------------------------------
  always_ff @ ( posedge clk )
    if ( rst ) begin
      key_dly[0]    <= '0;
      cmd_dly[0]    <= CMD_NOP;

    end else if ( en ) begin
      cmd_dly[0]    <= cmd;
      key_dly[0]    <= key;
    end


  // ---------------
  // Delay Registers
  // ---------------
  always_ff @ ( posedge clk ) begin
    cache_page_req_p <= cache_page_req;
    en_dly           <= (en_dly<<1)| en;
    cmd_dly[1]       <= cmd_dly[0];
    cmd_dly[2]       <= cmd_dly[1];
    key_dly[1]       <= key_dly[0];
  end
      

endmodule


