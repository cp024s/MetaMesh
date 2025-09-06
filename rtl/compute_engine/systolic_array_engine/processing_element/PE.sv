module pe_mac #(
  parameter int WA       = 16,    // A input width
  parameter int WB       = 16,    // B input width
  parameter int ACCW     = 40,    // accumulator width
  parameter int MULT_LAT = 1,     // multiplier pipeline stages
  parameter int ADD_LAT  = 0      // adder pipeline stages (beside reg)
) (
  input  logic                    clk,
  input  logic                    rst_n,

  // Input stream (aligned A,B,psum_in)
  input  logic                    in_valid,
  output logic                    in_ready,
  input  logic signed [WA-1:0]    a_in,
  input  logic signed [WB-1:0]    b_in,
  input  logic signed [ACCW-1:0]  psum_in,

  // Output stream to neighbors
  output logic                    out_valid,
  input  logic                    out_ready,
  output logic signed [WA-1:0]    a_out,
  output logic signed [WB-1:0]    b_out,
  output logic signed [ACCW-1:0]  psum_out
);

  // Local widths
  localparam int PRODW = WA + WB;

  // Input registers
  logic signed [WA-1:0]   a_reg;
  logic signed [WB-1:0]   b_reg;
  logic signed [ACCW-1:0] psum_reg;

  // back-pressure: ready when we can accept data
  // for simple design ready tied to out_ready (no internal buffering)
  // can be made more complex (elastic buffer)
  assign in_ready = out_ready;

  // latch inputs on accept
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      a_reg    <= '0;
      b_reg    <= '0;
      psum_reg <= '0;
    end else if (in_valid && in_ready) begin
      a_reg    <= a_in;
      b_reg    <= b_in;
      psum_reg <= psum_in;
    end
  end

  // pipeline multiplier
  // use generate to create MULT_LAT stages
  logic signed [PRODW-1:0] mult_pipe [0:MAX_MULT_PIPE-1];
  // helper localparam for array size (synthesis-friendly)
  localparam int MAX_MULT_PIPE = (MULT_LAT>0)? MULT_LAT : 1;
  // instantiate pipeline
  genvar i;
  generate
    if (MULT_LAT == 0) begin
      logic signed [PRODW-1:0] mult0;
      assign mult0 = a_reg * b_reg;
      // single-cycle mult
      assign mult_pipe[0] = mult0;
    end else begin
      // pipeline registers
      for (i=0; i<MAX_MULT_PIPE; i=i+1) begin : mult_stages
        if (i==0) begin
          always_ff @(posedge clk) if (!rst_n) mult_pipe[i] <= '0; else mult_pipe[i] <= a_reg * b_reg; 
        end else begin
          always_ff @(posedge clk) if (!rst_n) mult_pipe[i] <= '0; else mult_pipe[i] <= mult_pipe[i-1];
        end
      end
    end
  endgenerate

  // adder stage(s): add product to psum_reg (with optional pipeline)
  logic signed [ACCW-1:0] add_pipe [0:1]; // 0: input, 1: output

  // align widths: extend product to ACCW
  logic signed [ACCW-1:0] mult_ext;
  assign mult_ext = $signed(mult_pipe[MAX_MULT_PIPE-1]);

  // single-cycle or pipelined adder
  if (ADD_LAT == 0) begin : add_nopipe
    always_comb begin
      add_pipe[0] = psum_reg + mult_ext;
    end
    always_ff @(posedge clk) begin
      if (!rst_n) add_pipe[1] <= '0; else add_pipe[1] <= add_pipe[0];
    end
  end else begin : add_pipe_gen
    // simple single-stage pipeline for adder
    always_ff @(posedge clk) begin
      if (!rst_n) add_pipe[0] <= '0; else add_pipe[0] <= psum_reg + mult_ext;
      if (!rst_n) add_pipe[1] <= '0; else add_pipe[1] <= add_pipe[0];
    end
  end

  // outputs
  assign psum_out = add_pipe[1];
  assign a_out    = a_reg;
  assign b_out    = b_reg;

  // valid handshake: pass-through simple scheme
  // out_valid is asserted one cycle after capture (depends on pipelining)
  logic valid_reg;
  always_ff @(posedge clk) begin
    if (!rst_n) valid_reg <= 1'b0;
    else valid_reg <= in_valid && in_ready;
  end

  // delay valid to account for internal latency (mult+add)
  // generate a shift-register for valid
  logic [MAX_LAT-1:0] valid_pipe;
  localparam int MAX_LAT = MAX_MULT_PIPE + 2; // safe upper bound
  integer vp;
  always_ff @(posedge clk) begin
    if (!rst_n) valid_pipe <= '0;
    else begin
      valid_pipe <= {valid_pipe[MAX_LAT-2:0], valid_reg};
    end
  end

  assign out_valid = valid_pipe[MAX_LAT-1];

endmodule
