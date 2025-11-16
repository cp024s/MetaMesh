// Bus-fed vector interface (easier integration with SRAM buffers/crossbar)

module MAC_Array_Vector #(
  parameter int ACT_W=8, WGT_W=8, PS_W=32,
  parameter int LANES_ACT=256, LANES_WGT=256, LANES_OUT=256
)(
  input  logic                        clk, rst_n, clk_en,
  // Packed vectors from buffers (already tiled/striped)
  input  logic [LANES_ACT*ACT_W-1:0]  act_vec,
  input  logic                        act_vld,
  output logic                        act_rdy,

  input  logic [LANES_WGT*WGT_W-1:0]  wgt_vec,
  input  logic                        wgt_vld,
  output logic                        wgt_rdy,

  input  logic [LANES_OUT*PS_W-1:0]   psum_vec_in,
  input  logic                        psum_vld_in,
  output logic                        psum_rdy_in,

  output logic [LANES_OUT*PS_W-1:0]   psum_vec_out,
  output logic                        psum_vld_out,
  input  logic                        psum_rdy_out,

  // cfg/precision/sparsity same as above…
  input  logic [4:0]                  shift_amount,
  input  logic [1:0]                  round_mode,
  input  logic                        sat_en,
  input  logic [1:0]                  sp_mode,
  input  logic [LANES_WGT/4-1:0][3:0] sp_meta_wgt, // example packing
  // control/status/debug…
  input  logic                        start,
  output logic                        busy, done,
  output logic                        acc_overflow
);
