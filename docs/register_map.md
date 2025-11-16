Base: 0x0000_0000

0x0000  CTRL                 RW  Bitfields
    [0]    NPU_ENABLE         0 = disable, 1 = enable
    [1]    SOFT_RESET        write-1 clears; self-clear after reset sequence
    [2]    HALT_ISSUE        1 = stop issuing new tiles (drains in-flight)
    [4:3]  MODE_SELECT       00=Systolic,01=SIMD,10=Hybrid
    [7:5]  RESERVED
    [15:8] GLOBAL_CLK_DIV    (optional drive for simulation/testing)
    [31:16] RESERVED

0x0004  STATUS               RO
    [0]    BUSY
    [1]    IDLE
    [2]    FAULT
    [3]    JOBQ_FULL
    [7:4]  ERR_CODE[3:0]     (see error enum)
    [31:8] RESERVED

0x0008  CONTROL_SHADOW_LO    RW  (shadow register for atomic tile commit - low 32 bits)
0x000C  CONTROL_SHADOW_HI    RW  (shadow - high)

0x0010  CONTROL_COMMIT       RW  writing 1 triggers commit of shadow regs

0x0014  INT_ENABLE           RW  bitmask for interrupts
    [0] JOB_DONE
    [1] DMA_ERR
    [2] MEM_ECC
    [3] THERMAL
    [31:4] reserved

0x0018  INT_STATUS           RW1C (write 1 to clear)
    same bits as INT_ENABLE

0x0020  JOBQ_HEAD_PTR_LO     RW  (host writes tail ptr to enqueue)
0x0024  JOBQ_HEAD_PTR_HI     RW
0x0028  JOBQ_TAIL_PTR_LO     RO  (hw updates)
0x002C  JOBQ_TAIL_PTR_HI     RO

0x0030  PERF_CTRL            RW
    [0] PERF_ENABLE
    [1] PERF_SNAPSHOT       (write 1 to snapshot counters)
    [3:2] PERF_CLK_DIV
    [31:4] reserved

0x0034  PERF_SNAPSHOT_STATUS RO
    [0] SNAPSHOT_BUSY
    [1] SNAPSHOT_VALID

// Performance counters block: 0x0100 - 0x01FF (each 64-bit)
0x0100  PERF_PE_UTIL_LO      RO
0x0104  PERF_PE_UTIL_HI
0x0108  PERF_DMA_BW_LO
0x010C  PERF_DMA_BW_HI
0x0110  PERF_BANK_CONFLICTS_LO
0x0114  PERF_BANK_CONFLICTS_HI
0x0118  PERF_TILE_LATENCY_LO
0x011C  PERF_TILE_LATENCY_HI
... (expand as needed up to 32 counters)

// DMA channel config area (per channel) (0x0200 + N*0x20)
Per channel (CH0):
0x0200  DMA0_SRC_ADDR_LO    RW
0x0204  DMA0_SRC_ADDR_HI    RW
0x0208  DMA0_DST_ADDR_LO    RW
0x020C  DMA0_DST_ADDR_HI    RW
0x0210  DMA0_LEN_LO         RW
0x0214  DMA0_LEN_HI         RW
0x0218  DMA0_STRIDE         RW  (32-bit signed)
0x021C  DMA0_CTRL           RW
     [0] ENABLE
     [1] INT_ON_COMPLETE
     [2] DIRECTION (0=READ_FROM_DRAM,1=WRITE_TO_DRAM)
     [4:3] TRANSFER_TYPE (0=1D,1=2D)
     [31:5] reserved

// Micro-op upload region (optional, for downloadable microcode)
0x0300  MICRO_OP_ADDR_LO    RW
0x0304  MICRO_OP_ADDR_HI    RW
0x0308  MICRO_OP_DATA0      RW
0x030C  MICRO_OP_DATA1      RW
0x0310  MICRO_OP_CTRL       RW  (write 1 to write data into micro-op RAM)

// Cluster config
0x0400  CLUSTER_CFG         RW
    [3:0] PE_ROWS
    [7:4] PE_COLS
    [15:8] TILE_H_DEFAULT
    [23:16] TILE_W_DEFAULT
    [31:24] RESERVED

0x0404  MODE_CFG            RW
    [0] MIXED_PRECISION_EN
    [3:1] DEFAULT_PRECISION (0=INT8,1=INT16,2=FP16,3=BF16)
    [7:4] RESERVED
    [31:8] reserved

// PMU and clock gating
0x0500  PMU_CTRL            RW
    [0] CLK_GATING_GLOBAL_EN
    [31:1] PER_DOMAIN_MASK (each bit = clock enable for domain)

// Error / Fault logs
0x0600  LAST_ERR_CODE       RO
0x0604  LAST_ERR_ADDR_LO    RO
0x0608  LAST_ERR_ADDR_HI    RO

// Debug trace read region (circular buffer)
0x0800  TRACE_RD_PTR        RW
0x0804  TRACE_WR_PTR        RO
0x0808  TRACE_DATA          RO (read pops next word)
