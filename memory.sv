// ------------------------------------------------------------------------------------------------
// Copyright (c) 2012, Tim Warkentin. All Rights Reserved.
// ------------------------------------------------------------------------------------------------
// FILE NAME      : memory.v
// CURRENT AUTHOR : Tim Warkentin
// AUTHOR'S EMAIL : tim.warkentin@gmail.com
// ------------------------------------------------------------------------------------------------
// PURPOSE: Generic dual-port RAM.
// ------------------------------------------------------------------------------------------------
// PARAMETERS
//   NAME            DEFAULT        DESCRIPTION
//   --------------- -------------- ---------------------------------------------------------------
//   DEPTH           128            Memory depth 
//   WIDTH           16             Memory bit-width
//   CLKS            1              Number of clocks
//   PORTS           1              Number of ports       (1,2)
//   WR_PORTS        1              Number of write ports (1,2)
//   RD_PORTS        2              Number of read ports  (1,2)
//   AWIDTH*         $clog2(DEPTH)  Address bit-width. Derivative of DEPTH.
//
// *Treat as localparam
// ------------------------------------------------------------------------------------------------
// REUSE ISSUES:
//   Reset Strategy:      No resets
//   Clock Domains:       generic
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    None
//   Synthesizable:       Yes
// ------------------------------------------------------------------------------------------------
// INSTANTIATIONS: None
// ------------------------------------------------------------------------------------------------

module memory #(

  parameter DEPTH      = 128,
  parameter WIDTH      = 16,
  parameter CLKS       = 1,
  parameter PORTS      = 1,
  parameter WR_PORTS   = 1,
  parameter RD_PORTS   = 1,
  parameter AWIDTH     = $clog2(DEPTH) )

  (
    input      [CLKS-1:0] clk,
    input  [WR_PORTS-1:0] wr,
    input    [AWIDTH-1:0] addr [PORTS],
    input     [WIDTH-1:0] din  [WR_PORTS],
    output    [WIDTH-1:0] dout [RD_PORTS]

  );

  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam PA = 0;  // Index for port A
  localparam PB = 1;  // Index for port B


  // ---------------------------------------------------------------------------
  // Signal Declarations
  // ---------------------------------------------------------------------------
  logic [WIDTH-1:0] mem [DEPTH];


  // ---------------------------------------------------------------------------
  // Sequential Logic
  // ---------------------------------------------------------------------------
  generate

    // ------------------
    // Single Port Memory
    // ------------------
    if ( PORTS == 1 ) begin: SINGLE_PORT

      if ( WR_PORTS == 0 ) begin: SP_ROM
        always_ff @ ( posedge clk )
          dout[0] <= mem[addr[0]];
      end else begin: SP_RAM
        always_ff @ ( posedge clk ) begin
          if ( wr ) begin
            mem[addr[0]] <= din[0];
          end
          dout[0] <= mem[addr[0]];
        end
      end

    // ------------------
    // Dual-port Memory
    // ------------------
    end else if ( PORTS == 2 ) begin: DUAL_PORT
      if ( CLKS == 1 ) begin: CLK_1

        if ( WR_PORTS == 1 ) begin: WR_1
          if ( RD_PORTS == 1 ) begin: RD_1

            // CLK=1, WR=1, RD=1

            // Port-A: WO, Port-B: RO ---------
            always_ff @( posedge clk ) begin
              if ( wr ) begin
                mem[addr[PA]] <= din[0];
              end
              dout <= mem[addr[1]];
            end

          end else if ( RD_PORTS == 2 ) begin: RD_2

            // CLK=1, WR=1, RD=2

            // Port-A: RW, Port-B: RO ---------
            always_ff @( posedge clk[PA] ) begin
              if ( wr ) begin
                mem[addr[PA]] <= din;
                dout[PA]      <= din;
              end else begin
                dout[PA] <= mem[addr[PA]];
              end
              dout[PB] <= mem[addr[PB]];
            end
          end

        end else if ( WR_PORTS == 2 ) begin: WR_2

          if ( RD_PORTS == 2 ) begin: RD_2

            // CLK=1, WR=2, RD=2

            // Simultaneous writes to the same location on
            // both ports results in indeterminate behavior

            // Port-A: RW ---------------------
            always_ff @( posedge clk ) begin
              if ( wr[PA] ) begin
                mem[addr[PA]] <= din[PA];
                dout[PA]      <= din[PA];
              end else begin
                dout[PA] <= mem[addr[PA]];
              end
            end

            // Port-B: RW ---------------------
            always_ff @( posedge clk ) begin
              if ( wr[PB] ) begin
                mem[addr[PB]] <= din[PB];
                dout[PB]      <= din[PB];
              end else begin
                dout[PB] <= mem[addr[PB]];
              end
            end
          end
        end

      end else if ( CLKS == 2 ) begin: CLK_2

        if ( WR_PORTS == 1 ) begin: WR_1
          if ( RD_PORTS == 1 ) begin: RD_1

            // CLK=2, WR=1, RD=1

            // Port-A: WO ---------------------
            always_ff @( posedge clk[PA] ) begin
              if ( wr[PA] ) begin
                mem[addr[PA]] <= din;
              end
            end

            // Port-B: RO ---------------------
            always_ff @( posedge clk[PB] ) begin
              dout <= mem[addr[PB]];
            end

          end else if ( RD_PORTS == 2 ) begin: RD_2

            // CLK=2, WR=1, RD=2

            // Port-A: RW ---------------------
            always_ff @( posedge clk[PA] ) begin
              if ( wr[PA] ) begin
                mem[addr[PA]] <= din[PA];
                dout[PA]      <= din[PA];
              end else begin
                dout[PA] <= mem[addr[PA]];
              end
            end

            // Port-B: RO ---------------------
            always_ff @( posedge clk[PB] ) begin
              dout[PB] <= mem[addr[PB]];
            end
          end

        end else if ( WR_PORTS == 2 ) begin: WR_2

          if ( RD_PORTS == 2 ) begin: RD_2

            // CLK=2, WR=2, RD=2 -- TRUE Dual-Port RAM
            // Simultaneous writes to the same location on
            // both ports results in indeterminate behavior

            // Port-A: RW ---------------------
            always_ff @( posedge clk[PA] ) begin
              if ( wr[PA] ) begin
                mem[addr[PA]] <= din[PA];
                dout[PA]      <= din[PA];
              end else begin
                dout[PA] <= mem[addr[PA]];
              end
            end

            // Port-B: RW ---------------------
            always_ff @( posedge clk[PB] ) begin
              if ( wr[PB] ) begin
                mem[addr[PB]] <= din[PB];
                dout[PB]      <= din[PB];
              end else begin
                dout[PB] <= mem[addr[PB]];
              end
            end
          end
        end

      end
    end
    /*
      assert (PORTS==1 || PORTS==2) else
        $error("Only memories with 1 or 2 ports are supported!");
    end */
  endgenerate


endmodule


