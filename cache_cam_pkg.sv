// ------------------------------------------------------------------------------------------------
// Copyright (c) 2015, Tim Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : cache_cam_pkg.sv
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: SystemVerilog package file for the cache_cam block.
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME            DEFAULT        DESCRIPTION
//   --------------- -------------- ---------------------------------------------------------------
//   DEPTH           128            Memory depth 
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:      sync/async etc.
//   Clock Domains:       generic
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    None
//   Synthesizable:       Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS: None
// ------------------------------------------------------------------------------------------------

package cache_cam_pkg;

  parameter PS_WIDTH  = 5;
  parameter KEY_WIDTH = 14;

  typedef enum logic [2:0] {
    CMD_NOP,
    CMD_STORE,
    CMD_DONE,
    CMD_VALID,
    CMD_DIRTY,
    CMD_CHG_PS,
    CMD_ERASE
  } cache_cam_cmd_e;

  typedef enum logic [1:0] {
    FREE     = 2'b00,
    RESERVED = 2'b01,
    VALID    = 2'b10,
    DIRTY    = 2'b11
  } cache_page_status_e;

  typedef struct packed {
    cache_page_status_e   status;
    logic  [PS_WIDTH-1:0] ps_id;
    logic [KEY_WIDTH-1:0] key;
  } cache_cam_s;


endpackage: cache_cam_pkg

