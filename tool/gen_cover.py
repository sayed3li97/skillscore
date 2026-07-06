#!/usr/bin/env python3
"""Generate the skillscore cover banner: a radial rubric ring hero in the
dark / monospace / blue-accent house style. Each ring segment is a rubric
category, sized by its point weight; a full blue ring is a perfect score."""
import math

W, H = 1200, 480
CX, CY = 948, 236          # ring center (right side)
R = 138                    # mid radius of the donut
TH = 24                    # ring thickness
GAP = 5.0                  # degrees of gap between segments

# rubric categories A..F with point weights (the positive total = 105)
SEGS = [("A", 17), ("B", 28), ("C", 15), ("D", 15), ("E", 20), ("F", 10)]
TOTAL = sum(w for _, w in SEGS)

def pt(angle_deg, radius=R):
    a = math.radians(angle_deg)
    return (CX + radius * math.cos(a), CY + radius * math.sin(a))

def arc_path(a0, a1, radius=R):
    x0, y0 = pt(a0, radius)
    x1, y1 = pt(a1, radius)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M {x0:.2f} {y0:.2f} A {radius} {radius} 0 {large} 1 {x1:.2f} {y1:.2f}"

segments = []
labels = []
cursor = -90.0  # start at top, go clockwise
for i, (letter, w) in enumerate(SEGS):
    span = w / TOTAL * 360.0
    a0 = cursor + GAP / 2
    a1 = cursor + span - GAP / 2
    mid = (a0 + a1) / 2
    length = math.radians(a1 - a0) * R           # stroke length for draw anim
    segments.append((i, arc_path(a0, a1), length))
    lx, ly = pt(mid, R + TH / 2 + 18)
    labels.append((letter, lx, ly))
    cursor += span

seg_svg = []
for i, d, length in segments:
    seg_svg.append(
        f'    <path class="seg s{i}" d="{d}" stroke-dasharray="{length:.1f}" '
        f'stroke-dashoffset="0" style="--len:{length:.1f}"/>'
    )
seg_svg = "\n".join(seg_svg)

lab_svg = "\n".join(
    f'    <text class="rlab" x="{x:.1f}" y="{y+5:.1f}" text-anchor="middle">{ltr}</text>'
    for ltr, x, y in labels
)

# per-segment draw-in delays
delays = "\n".join(
    f"      .s{i}{{animation-delay:{0.25 + i*0.11:.2f}s}}" for i in range(len(SEGS))
)

svg = f'''<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg" font-family="'SFMono-Regular','SF Mono','JetBrains Mono',Menlo,Consolas,'DejaVu Sans Mono',monospace">
  <defs>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#1f6feb" stop-opacity="0.22"/>
      <stop offset="1" stop-color="#1f6feb" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#4d9fff"/>
      <stop offset="1" stop-color="#2f6fd0"/>
    </linearGradient>
    <pattern id="dots" width="26" height="26" patternUnits="userSpaceOnUse">
      <circle cx="1.4" cy="1.4" r="1.4" fill="#5a6472" fill-opacity="0.09"/>
    </pattern>
    <filter id="ringglow" x="-40%" y="-40%" width="180%" height="180%">
      <feGaussianBlur stdDeviation="11"/>
    </filter>
    <style>
      .prompt{{fill:#3fb950}} .word{{fill:#e6edf3}} .cursor{{fill:#2f3845}}
      .h{{fill:#e6edf3;font-size:41px;font-weight:700;letter-spacing:-0.5px}}
      .acc{{fill:#4d9fff}}
      .sub{{fill:#7d8795;font-size:15px}}
      .cta{{fill:#4d9fff;font-size:16px}}
      .foot{{fill:#59626f;font-size:14px}}
      .track{{fill:none;stroke:#1a212b;stroke-width:{TH}}}
      .seg{{fill:none;stroke:url(#ring);stroke-width:{TH};stroke-linecap:butt;
            animation:draw 1.1s cubic-bezier(.2,.7,.2,1) both}}
      .score{{fill:#eaf2ff;font-size:58px;font-weight:700;letter-spacing:-1px}}
      .grade{{fill:#4d9fff;font-size:17px;letter-spacing:3px}}
      .rlab{{fill:#7d8795;font-size:14px}}
      .blink{{animation:blink 1.1s steps(1) infinite}}
      @keyframes draw{{from{{stroke-dashoffset:var(--len)}}to{{stroke-dashoffset:0}}}}
      @keyframes blink{{0%,50%{{opacity:1}}51%,100%{{opacity:0}}}}
{delays}
    </style>
  </defs>

  <rect width="{W}" height="{H}" fill="#0d1117"/>
  <rect width="{W}" height="{H}" fill="url(#dots)"/>
  <circle cx="{CX}" cy="200" r="300" fill="url(#glow)"/>
  <line x1="0" y1="0.5" x2="{W}" y2="0.5" stroke="#4d9fff" stroke-opacity="0.35" stroke-width="1"/>

  <!-- LEFT: wordmark, headline, tagline, install -->
  <text x="72" y="120" font-size="28" font-weight="600"><tspan class="prompt">$ </tspan><tspan class="word">skillscore</tspan><tspan class="cursor blink"> _</tspan></text>

  <text class="h" x="71" y="196">Score your agent's</text>
  <text class="h" x="71" y="244"><tspan class="acc">SKILL.md</tspan>, <tspan class="acc">0 to 100</tspan>.</text>

  <text class="sub" x="72" y="302">Lint and grade skills against the Claude, Codex,</text>
  <text class="sub" x="72" y="324">and Antigravity guides. Offline. Deterministic.</text>

  <text class="cta" x="72" y="392">dart pub global activate skillscore</text>
  <text class="foot" x="72" y="430">26 rules &#183; 7 categories &#183; cited sources &#183; Apache-2.0</text>

  <!-- HERO: radial rubric ring -->
  <circle cx="{CX}" cy="{CY}" r="{R}" fill="none" stroke="#4d9fff" stroke-width="{TH}" opacity="0.16" filter="url(#ringglow)"/>
  <circle class="track" cx="{CX}" cy="{CY}" r="{R}"/>
{seg_svg}
{lab_svg}
  <text class="score" x="{CX}" y="{CY+6}" text-anchor="middle">100</text>
  <text class="grade" x="{CX}" y="{CY+38}" text-anchor="middle">GRADE A</text>
</svg>
'''

with open("docs/assets/cover.svg", "w") as f:
    f.write(svg)
print("wrote docs/assets/cover.svg")
