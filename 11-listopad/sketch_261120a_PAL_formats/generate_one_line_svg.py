#!/usr/bin/env python3
"""
Generate a continuous one-line SVG (Eulerian path, zero pen lifts) for Drkota V-plotter
representing sketch_261120a_PAL_formats (36 decans = 36 * 10° Earth rays).

Ensures:
- Exact concentricity around (cx, cy)
- Perfectly symmetric bounding box (center is identically (cx, cy))
- All transitions occur strictly along Ray 0 (primary decan axis)
- Exactly 1 initial 'M' command, followed exclusively by 'L' commands (zero pen lifts)
"""

import math
import sys
import os

def generate_pal_oneline_svg(
    filename="dh36_paprsky_oneline.svg",
    width_mm=200.0,
    height_mm=200.0,
    num_dekans=36,
    r_hub=3.5,          # Central micro-hub radius in mm
    r_in=20.0,          # Inner circle 1 radius in mm
    r_in2=22.0,         # Inner circle 2 radius in mm
    r_out=87.0,         # Outer ray radius in mm
    r_out2=90.0,        # Outer guard ring radius in mm
    arc_subdiv=16       # Subdivisions per decan arc (16 * 36 = 576 pts per full circle)
):
    points = []
    
    # Center coordinates
    cx = width_mm / 2.0
    cy = height_mm / 2.0
    
    def pt(r, angle_rad):
        return (cx + r * math.cos(angle_rad), cy + r * math.sin(angle_rad))

    def arc(r, start_angle, end_angle, steps=None):
        if steps is None:
            steps = max(2, int(abs(end_angle - start_angle) / (2.0 * math.pi / num_dekans) * arc_subdiv))
        pts = []
        for i in range(steps + 1):
            t = float(i) / steps
            a = start_angle + t * (end_angle - start_angle)
            pts.append(pt(r, a))
        return pts

    delta_theta = 2.0 * math.pi / num_dekans

    # --- Phase 1: Start at Outer Guard Ring on Ray 0 ---
    points.append(pt(r_out2, 0.0))

    # --- Phase 2: Outer Guard Ring (r_out2) full 360° circle ---
    full_outer2 = arc(r_out2, 0.0, 2.0 * math.pi, num_dekans * arc_subdiv)
    points.extend(full_outer2[1:])

    # --- Phase 3: Transition along Ray 0 to Outer Ring (r_out) ---
    points.append(pt(r_out, 0.0))

    # --- Phase 4: 36 Decan Ray Meander ---
    # Alternating inward and outward rays across all 36 decans:
    # Ray 2k: r_out -> r_in along theta_a
    # Inner arc: theta_a -> theta_b at r_in
    # Ray 2k+1: r_in -> r_out along theta_b
    # Outer arc: theta_b -> theta_c at r_out
    for k in range(num_dekans // 2):
        th_a = (2 * k) * delta_theta
        th_b = (2 * k + 1) * delta_theta
        th_c = (2 * k + 2) * delta_theta
        
        # Ray inward along th_a
        points.append(pt(r_in, th_a))
        
        # Inner arc from th_a to th_b
        inner_arc = arc(r_in, th_a, th_b, arc_subdiv)
        points.extend(inner_arc[1:])
        
        # Ray outward along th_b
        points.append(pt(r_out, th_b))
        
        # Outer arc from th_b to th_c
        outer_arc = arc(r_out, th_b, th_c, arc_subdiv)
        points.extend(outer_arc[1:])

    # Now pen is back at (r_out, 0)
    # --- Phase 5: Inward along Ray 0 to Inner Ring 1 (r_in) ---
    points.append(pt(r_in, 0.0))

    # --- Phase 6: Inner Ring 1 (r_in) full 360° circle ---
    # Completes the remaining inner arcs so the inner ring is continuous and complete
    full_inner1 = arc(r_in, 0.0, 2.0 * math.pi, num_dekans * arc_subdiv)
    points.extend(full_inner1[1:])

    # --- Phase 7: Transition along Ray 0 to Inner Ring 2 (r_in2) ---
    points.append(pt(r_in2, 0.0))

    # --- Phase 8: Inner Ring 2 (r_in2) full 360° circle ---
    full_inner2 = arc(r_in2, 0.0, 2.0 * math.pi, num_dekans * arc_subdiv)
    points.extend(full_inner2[1:])

    # --- Phase 9: Inward along Ray 0 to Central Hub (r_hub) ---
    points.append(pt(r_hub, 0.0))

    # --- Phase 10: Central Hub full 360° circle ---
    hub_circle = arc(r_hub, 0.0, 2.0 * math.pi, num_dekans)
    points.extend(hub_circle[1:])

    # --- Phase 11: Final anchor to exact mathematical center ---
    points.append((cx, cy))

    # Format into single SVG path
    d_parts = []
    d_parts.append(f"M {points[0][0]:.3f} {points[0][1]:.3f}")
    for p in points[1:]:
        d_parts.append(f"L {p[0]:.3f} {p[1]:.3f}")
    
    d_str = " ".join(d_parts)

    svg_content = f'''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="{width_mm}mm" height="{height_mm}mm"
     viewBox="0 0 {width_mm} {height_mm}" version="1.1">
  <title>36 Decans PAL Formats - Single Line Astrolabe</title>
  <desc>One-line continuous Eulerian trajectory for Drkota V-plotter (zero pen lifts)</desc>
  <path d="{d_str}"
        fill="none" stroke="#000000" stroke-width="0.35" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
'''
    with open(filename, "w", encoding="utf-8") as f:
        f.write(svg_content)

    print(f"Generated: {filename}")
    print(f"Total points in single continuous line: {len(points)}")
    print(f"Pen lifts: 0 (exactly 1 'M' command at the start)")
    
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    print(f"Bounding Box: X=[{min(xs):.3f}, {max(xs):.3f}], Y=[{min(ys):.3f}, {max(ys):.3f}]")
    print(f"Center: ({(min(xs)+max(xs))/2.0:.3f}, {(min(ys)+max(ys))/2.0:.3f})")

    # Calculate total plotting distance
    total_dist = 0.0
    for i in range(1, len(points)):
        dx = points[i][0] - points[i-1][0]
        dy = points[i][1] - points[i-1][1]
        total_dist += math.hypot(dx, dy)
    print(f"Total continuous pen-down drawing distance: {total_dist:.1f} mm (~{total_dist/1000.0:.2f} m)")
    return filename

if __name__ == "__main__":
    out_file = sys.argv[1] if len(sys.argv) > 1 else "/home/kof/src/2026/11-listopad/sketch_261120a_PAL_formats/dh36_paprsky_oneline.svg"
    generate_pal_oneline_svg(out_file)
