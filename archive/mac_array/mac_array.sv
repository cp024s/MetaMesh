// Systolic-border interface (closest to paper designs; great for scaling across tiles)

module MAC_Array_Systolic #(
  parameter int ACT_W=8, WGT_W=8, PS_W=32,
  parameter int ROWS=64, COLS=64
)(
  input  logic                 clk, rst_n,
  input  logic                 clk_en,

  // Geometry & timing
  input  logic [15:0]          cfg_rows,       // <= ROWS
  input  logic [15:0]          cfg_cols,       // <= COLS
  input  logic [15:0]          cfg_k_steps,    // reduction length
  input  logic [1:0]           cfg_dataflow,   // 0=WS,1=OS,2=RS
  input  logic                 clear_acc,

  // Borders (ready/valid per edge)
  input  logic [ACT_W-1:0]     west_act_in   [ROWS];
  input  logic                  west_act_vld  [ROWS];
  output logic                  west_act_rdy  [ROWS];

  input  logic [WGT_W-1:0]     north_wgt_in  [COLS];
  input  logic                  north_wgt_vld [COLS];
  output logic                  north_wgt_rdy [COLS];

  // Optional incoming psums (for output-stationary reuse)
  input  logic [PS_W-1:0]      west_psum_in  [ROWS];
  input  logic                  west_psum_vld [ROWS];
  output logic                  west_psum_rdy [ROWS];

  // South/east borders (propagated streams)
  output logic [ACT_W-1:0]     east_act_out  [ROWS];
  output logic                  east_act_vld  [ROWS];
  input  logic                  east_act_rdy  [ROWS];

  output logic [WGT_W-1:0]     south_wgt_out [COLS];
  output logic                  south_wgt_vld [COLS];
  input  logic                  south_wgt_rdy [COLS];

  // Final psums/results at east (or south) edge
  output logic [PS_W-1:0]      east_psum_out [ROWS];
  output logic                  east_psum_vld [ROWS];
  input  logic                  east_psum_rdy [ROWS];

  // Precision/scaling
  input  logic [4:0]           shift_amount;     // per-op scale
  input  logic [1:0]           round_mode;       // RNE/RTZ/…
  input  logic                 sat_en;

  // Sparsity metadata (optional)
  input  logic [1:0]           sp_mode;          // 0=off,1=2:4,2=block
  input  logic [COLS-1:0][3:0] sp_meta_wgt;      // example: 2:4 masks per col
  input  logic [ROWS-1:0][3:0] sp_meta_act;      // optional act sparsity

  // Control/Status
  input  logic                 start;
  output logic                 busy, done;
  output logic                 acc_overflow;
  output logic [15:0]          stall_cause;
  // DFT/Perf/Debug
  input  logic                 scan_en, mbist_en;
  output logic [31:0]          mac_count, util_cycles;
  output logic [PS_W-1:0]      dbg_tap_row_psum, dbg_tap_col_psum
);
