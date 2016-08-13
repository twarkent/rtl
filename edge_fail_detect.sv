`timescale 1ns / 10ps
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// File         : edge_fail_detect.sv
// Author       : Tim Warkentin
// Date         : 2016/03/23
//
// Description  : Determine when a signal fails to have an edge (POS/NEG/ANY).
//                The measurement period depends on the width of the shift 
//                register (determined by the parameter 'SR_WIDTH'), and the 
//                period of the clock. Each time the clock pulses a '1' is 
//                shifted into a shift register. If a '1' is detect at the end 
//                of the shift register then the fail signal is asserted. An 
//                edge on the input 'sig' clears the shift register.
// -----------------------------------------------------------------------------
// KEYWORDS: edge fail detect
// -----------------------------------------------------------------------------
// Parameters
//   NAME              VALUE        DESCRIPTION
//   ----------------- ------------ --------------------------------------------
//   SR_WIDTH          2            Bitwidth of shift register. Determines the 
//                                  number of clk edges to consider before 
//                                  asserting the fail signal.
//   EDGE              2'b01        Rising-Edge
//                     2'b10        Falling-Edge
//                     2'b11        Any Edge
// -----------------------------------------------------------------------------
// Reuse Issues:
//   Reset Strategy:      Asynchronous
//   Clock Domains:       generic clk
//   Critical Timing:     None
//   Test Features:       None
//   Asynchronous I/F:    The input 'sig' may be async to 'clk'.
//   Instantiations:      None
//   Synthesizable:       Yes
// -----------------------------------------------------------------------------
// NOTES:
// -----------------------------------------------------------------------------

module edge_fail_detect #(

  parameter SR_WIDTH = 2,
  parameter EDGE     = 2'b11) (       // POS: 2'b01, NEG: 2'b10, ANY: 2'b11

  input  clk,                         // Sample clock   -- must be a stable clock and 
                                      // slower than signal 'sig', or increase SR_WIDTH
  input  sig,                         // Signal to test -- may be unstable. Used as an 
                                      // async reset to flops
  output logic fail );

  localparam PE_DETECT = EDGE[1];     // posedge detect
  localparam NE_DETECT = EDGE[0];     // negedge detect

  logic [SR_WIDTH-1:0] dly_pe;
  logic [SR_WIDTH-1:0] dly_ne;
  logic                fail_meta;

  generate
    if (PE_DETECT) begin: PE
      always_ff @(posedge clk, posedge sig) begin
        if (sig)
          dly_pe <= '0;
        else
          dly_pe <= {1'b1, dly_pe[SR_WIDTH-1:1]};
      end
    end else 
      assign dly_pe = '0;
  endgenerate

  generate
    if (NE_DETECT) begin: NE
      always_ff @(posedge clk, negedge sig) begin
        if (~sig)
          dly_ne <= '0;
        else
          dly_ne <= {1'b1, dly_ne[SR_WIDTH-1:1]};
      end
    end else
      assign dly_ne = '0;
  endgenerate

  always_ff @(posedge clk) begin
    {fail, fail_meta} <= {fail_meta, (dly_pe[0] | dly_ne[0])};
  end
  
endmodule
