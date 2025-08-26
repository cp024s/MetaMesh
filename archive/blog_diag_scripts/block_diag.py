#!/usr/bin/env python3
"""
draw_npu_arch_neat.py

Generates a clean, organized PNG of the detailed dual-engine NPU architecture.

Requirements:
    pip install matplotlib
Run:
    python3 draw_npu_arch_neat.py
"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, FancyArrowPatch
import textwrap

plt.rcParams.update({'font.size': 9})

def add_box(ax, xy, wh, label, fontsize=9, pad=0.1):
    x, y = xy
    w, h = wh
    box = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=%s" % pad, linewidth=1.0, fill=False)
    ax.add_patch(box)
    # Wrap text
    wrapped = "\n".join(textwrap.wrap(label, int(max(12, w*6))))
    ax.text(x + w/2, y + h/2, wrapped, ha='center', va='center', fontsize=fontsize)
    return box

def add_arrow(ax, start, end, text=None, text_pos=0.5, lw=1.0):
    sx, sy = start
    ex, ey = end
    arr = FancyArrowPatch((sx, sy), (ex, ey), arrowstyle='-|>', mutation_scale=12, linewidth=lw)
    ax.add_patch(arr)
    if text:
        tx = sx + (ex-sx)*text_pos
        ty = sy + (ey-sy)*text_pos
        ax.text(tx, ty, text, fontsize=8, va='bottom', ha='center', backgroundcolor='white')

def main():
    fig, ax = plt.subplots(figsize=(22, 14))
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 60)
    ax.axis('off')

    # Top Row: Host, Control, Debug, Interfaces
    host = add_box(ax, (2, 50), (22, 8), "Host Interface\nAXI-Lite/APB\nJob Queue\nInterrupt Ctrl")
    control = add_box(ax, (26, 50), (28, 8), "Control Unit\nDecoder\nScheduler\nEngine Selector\nTiler\nError Handler")
    debug = add_box(ax, (56, 50), (20, 8), "Debug Unit\nPerf Counters\nTrace Buffers\nJTAG/Scan")
    interfaces = add_box(ax, (78, 50), (20, 8), "Interfaces\nAXI Master (DRAM)\nAXI-Lite/APB (CPU)\nCoherency Optional")

    # Middle Row: Compute Cluster
    systolic = add_box(ax, (30, 32), (20, 10), "Systolic Array Engine\nPE Array R x C\nIngress/Collector\nLocal Scheduler")
    mac = add_box(ax, (52, 32), (20, 10), "MAC Array Engine\nSIMD PE Array\nMAC Ctrl\nInput Distributor\nOutput Accumulator")
    postproc = add_box(ax, (40, 20), (28, 10), "PostProcessing\nVector Units\nActivation (ReLU/LUT/CORDIC)\nPooling\nQuantization\nPackager")

    # Bottom Row: Memory Subsystem
    w_buf = add_box(ax, (2, 2), (18, 10), "Weight Buffer\nBanked SRAMs\nPrefetch Ctrl")
    a_buf = add_box(ax, (22, 2), (18, 10), "Activation Buffer\nPing-Pong SRAMs\nBank Conflict Resolver")
    psum_buf = add_box(ax, (42, 2), (18, 10), "PSUM Buffer\nAccumulate/Spill")
    agu = add_box(ax, (62, 2), (12, 10), "AGU Cluster\nSystolic + SIMD")
    dma = add_box(ax, (76, 2), (18, 10), "DMA Engine\nAXI Master\nRead/Write FSMs")

    # Arrows: Host → Control → Compute / Memory
    add_arrow(ax, (13, 50), (40, 42), "Job descriptor")
    add_arrow(ax, (40, 50), (40, 42), "Control commands")
    add_arrow(ax, (26, 50), (40, 42), "Engine cfg")
    add_arrow(ax, (13, 50), (13, 42), "Status/IRQ feedback")
    
    # Compute → Memory arrows
    add_arrow(ax, (40, 32), (30, 12), "Weight fetch")
    add_arrow(ax, (60, 32), (40, 12), "Activation fetch")
    add_arrow(ax, (52, 32), (42, 12), "PSUM spill / accumulation")
    add_arrow(ax, (54, 22), (62, 12), "PostProc outputs → Memory writeback")

    # Memory → Compute arrows
    add_arrow(ax, (11, 12), (35, 32), "Weights / tiles")
    add_arrow(ax, (31, 12), (55, 32), "Activations / tiles")
    add_arrow(ax, (73, 12), (52, 32), "AGU addr streams")
    add_arrow(ax, (85, 12), (60, 32), "DMA bursts / prefetch")

    # Title
    ax.text(50, 58, "Detailed NPU Architecture (Dual Engines: Systolic + MAC)", ha='center', fontsize=14, weight='bold')

    # Save PNG
    plt.tight_layout()
    plt.savefig("npu_architecture_neat.png", dpi=300, bbox_inches='tight')
    print("Saved npu_architecture_neat.png")
    plt.show()

if __name__ == "__main__":
    main()
