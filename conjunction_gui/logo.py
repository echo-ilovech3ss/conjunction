"""
Conjunction OS - Logo & Brand Asset Generator
Provides vector SVG assets and renders pixel-perfect high-resolution PNGs
for application icons, window headers, desktop shortcuts, and installer branding.
"""

import math
import os
from pathlib import Path
from typing import Tuple, Dict, Any

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# High-fidelity SVG definitions
CONJUNCTION_MARK_SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="100%" height="100%">
  <defs>
    <!-- Background glow & ambient nebula -->
    <radialGradient id="nebula-glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#00f2fe" stop-opacity="0.25"/>
      <stop offset="45%" stop-color="#7928ca" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0"/>
    </radialGradient>

    <!-- Primary orbital gradient (Cyan to Blue to Purple) -->
    <linearGradient id="major-orbit-grad" x1="10%" y1="10%" x2="90%" y2="90%">
      <stop offset="0%" stop-color="#00f2fe"/>
      <stop offset="28%" stop-color="#4facfe"/>
      <stop offset="65%" stop-color="#6f42c1"/>
      <stop offset="100%" stop-color="#ff007f"/>
    </linearGradient>

    <!-- Secondary intersecting orbit gradient -->
    <linearGradient id="cross-orbit-grad" x1="90%" y1="10%" x2="10%" y2="90%">
      <stop offset="0%" stop-color="#38ef7d"/>
      <stop offset="35%" stop-color="#11998e"/>
      <stop offset="70%" stop-color="#0072ff"/>
      <stop offset="100%" stop-color="#9b51e0"/>
    </linearGradient>

    <!-- Primary celestial orb gradient (Azure world) -->
    <radialGradient id="celestial-body-1" cx="32%" cy="30%" r="68%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="22%" stop-color="#a0f0ff"/>
      <stop offset="55%" stop-color="#0077b6"/>
      <stop offset="85%" stop-color="#023e8a"/>
      <stop offset="100%" stop-color="#03045e"/>
    </radialGradient>

    <!-- Secondary celestial orb gradient (Cosmic companion) -->
    <radialGradient id="celestial-body-2" cx="30%" cy="28%" r="70%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="25%" stop-color="#f8bbd0"/>
      <stop offset="60%" stop-color="#9c27b0"/>
      <stop offset="88%" stop-color="#4a148c"/>
      <stop offset="100%" stop-color="#12005e"/>
    </radialGradient>

    <!-- Planetary ring gradient -->
    <linearGradient id="ring-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00f2fe" stop-opacity="0.85"/>
      <stop offset="50%" stop-color="#ffffff" stop-opacity="0.95"/>
      <stop offset="100%" stop-color="#7928ca" stop-opacity="0.2"/>
    </linearGradient>

    <!-- Starburst / Flare gradient -->
    <radialGradient id="starburst-grad" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="25%" stop-color="#e0f7fa" stop-opacity="0.9"/>
      <stop offset="55%" stop-color="#00f2fe" stop-opacity="0.5"/>
      <stop offset="85%" stop-color="#7928ca" stop-opacity="0.2"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0"/>
    </radialGradient>

    <!-- Filters for bloom and outer glow -->
    <filter id="glow-heavy" x="-40%" y="-40%" width="180%" height="180%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="12" result="blur"/>
      <feMerge>
        <feMergeNode in="blur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>

    <filter id="glow-subtle" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="4" result="blur"/>
      <feMerge>
        <feMergeNode in="blur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <!-- Ambient Nebula Background -->
  <circle cx="256" cy="256" r="230" fill="url(#nebula-glow)"/>

  <!-- Outer Guide Halo (Faint precision ring) -->
  <circle cx="256" cy="256" r="215" fill="none" stroke="#4facfe" stroke-width="1.5" stroke-dasharray="3 7" stroke-opacity="0.35"/>
  <circle cx="256" cy="256" r="185" fill="none" stroke="#7928ca" stroke-width="1" stroke-opacity="0.25"/>

  <!-- Secondary Crossed Orbital Trajectory (The Junction Loop) -->
  <path d="M 120 370 C 90 270, 160 140, 265 130 C 370 120, 430 220, 395 330 C 365 420, 250 435, 175 390 C 130 360, 105 310, 115 255"
        fill="none"
        stroke="url(#cross-orbit-grad)"
        stroke-width="10"
        stroke-linecap="round"
        stroke-opacity="0.8"
        filter="url(#glow-subtle)"/>

  <!-- Major Primary Orbit (The Conjunction Sweep 'C' Arc) -->
  <path d="M 370 110 C 260 50, 110 120, 85 240 C 60 360, 165 455, 305 450 C 390 445, 445 380, 440 310"
        fill="none"
        stroke="url(#major-orbit-grad)"
        stroke-width="16"
        stroke-linecap="round"
        filter="url(#glow-heavy)"/>

  <!-- High-tech Node Track Accents -->
  <circle cx="85" cy="240" r="5" fill="#00f2fe"/>
  <circle cx="440" cy="310" r="6" fill="#ff007f"/>
  <line x1="370" y1="110" x2="385" y2="95" stroke="#00f2fe" stroke-width="3" stroke-linecap="round" stroke-opacity="0.8"/>

  <!-- Primary Celestial Orb & Ring System (Linux Stability / Depth) -->
  <g transform="translate(195, 305)">
    <!-- Planetary Ring Back Segment -->
    <ellipse cx="0" cy="0" rx="68" ry="18" fill="none" stroke="url(#ring-grad)" stroke-width="4" transform="rotate(-28)" opacity="0.65"/>
    
    <!-- Primary Sphere Body -->
    <circle cx="0" cy="0" r="46" fill="url(#celestial-body-1)" filter="url(#glow-subtle)"/>
    
    <!-- Inner Atmosphere Crescent Glow -->
    <path d="M -35 -20 A 44 44 0 0 1 20 40 A 42 42 0 0 0 -35 -20 Z" fill="#00f2fe" opacity="0.45"/>
    <circle cx="-16" cy="-16" r="6" fill="#ffffff" opacity="0.65"/>

    <!-- Planetary Ring Front Segment -->
    <path d="M -60 32 C -40 42, 20 44, 58 12" fill="none" stroke="url(#ring-grad)" stroke-width="5" transform="rotate(-5)" stroke-linecap="round"/>
  </g>

  <!-- Secondary Companion Celestial Orb (Windows / App Convergence) -->
  <g transform="translate(330, 175)">
    <circle cx="0" cy="0" r="30" fill="url(#celestial-body-2)" filter="url(#glow-subtle)"/>
    <path d="M -22 -14 A 28 28 0 0 1 14 26 A 26 26 0 0 0 -22 -14 Z" fill="#ff79c6" opacity="0.5"/>
    <circle cx="-10" cy="-10" r="4" fill="#ffffff" opacity="0.75"/>
    <!-- Orbital Satellite Bead -->
    <circle cx="38" cy="-15" r="4" fill="#00f2fe"/>
  </g>

  <!-- Celestial Ray of Alignment (Connecting the bodies) -->
  <line x1="195" y1="305" x2="330" y2="175" stroke="#ffffff" stroke-width="2.5" stroke-dasharray="4 6" stroke-opacity="0.55"/>

  <!-- THE CONJUNCTION CORE: Stellar Flare / Convergence Nexus -->
  <g transform="translate(262, 240)">
    <!-- Expanding Corona -->
    <circle cx="0" cy="0" r="50" fill="url(#starburst-grad)"/>

    <!-- 8-Pointed Divine Starburst Core -->
    <!-- Major Cardinal Spikes -->
    <path d="M 0 -48 Q 2 -10 24 0 Q 2 10 0 48 Q -2 10 -24 0 Q -2 -10 0 -48 Z" fill="#ffffff" filter="url(#glow-subtle)"/>
    <path d="M -48 0 Q -10 -2 0 -24 Q 10 -2 48 0 Q 10 2 0 24 Q -10 2 -48 0 Z" fill="#ffffff" filter="url(#glow-subtle)"/>
    
    <!-- Diagonal Subtle Spikes -->
    <path d="M -22 -22 Q -2 -2 0 -18 Q 2 -2 22 22 Q 2 2 0 18 Q -2 2 -22 -22 Z" fill="#00f2fe" opacity="0.85"/>
    <path d="M 22 -22 Q 2 -2 18 0 Q 2 2 -22 22 Q -2 2 -18 0 Q -2 -2 22 -22 Z" fill="#00f2fe" opacity="0.85"/>

    <!-- Brilliant Stellar Singularity -->
    <circle cx="0" cy="0" r="6" fill="#ffffff"/>
    <circle cx="0" cy="0" r="2.5" fill="#e0f7fa"/>
  </g>
</svg>
'''

CONJUNCTION_APP_ICON_SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="100%" height="100%">
  <defs>
    <!-- App Icon Surface Gradient -->
    <linearGradient id="squircle-surface" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#131826"/>
      <stop offset="40%" stop-color="#0b0f19"/>
      <stop offset="100%" stop-color="#04060b"/>
    </linearGradient>

    <!-- Squircle Border Stroke Gradient -->
    <linearGradient id="squircle-border" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00f2fe" stop-opacity="0.8"/>
      <stop offset="50%" stop-color="#7928ca" stop-opacity="0.4"/>
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0.1"/>
    </linearGradient>

    <!-- Top Gloss Specular Reflex -->
    <linearGradient id="top-gloss" x1="50%" y1="0%" x2="50%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>

    <filter id="app-shadow" x="-10%" y="-10%" width="120%" height="125%">
      <feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#000000" flood-opacity="0.7"/>
    </filter>
  </defs>

  <!-- Deep App Background Squircle (macOS / GNOME standard radius) -->
  <rect x="24" y="24" width="464" height="464" rx="104" ry="104"
        fill="url(#squircle-surface)"
        stroke="url(#squircle-border)"
        stroke-width="3"
        filter="url(#app-shadow)"/>

  <!-- Top Glass Specular Arc -->
  <path d="M 26 128 C 26 72, 72 26, 128 26 L 384 26 C 440 26, 486 72, 486 128 C 486 210, 26 210, 26 128 Z"
        fill="url(#top-gloss)"/>

  <!-- Scaled Inner Conjunction Emblem -->
  <g transform="translate(40, 40) scale(0.84375)">
''' + CONJUNCTION_MARK_SVG.split('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="100%" height="100%">')[1].replace('</svg>', '  </g>\n</svg>')


CONJUNCTION_BRANDED_BANNER_SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 320" width="100%" height="100%">
  <defs>
    <linearGradient id="banner-bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0b0f19"/>
      <stop offset="50%" stop-color="#111726"/>
      <stop offset="100%" stop-color="#080c14"/>
    </linearGradient>
    <linearGradient id="brand-text-grad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="60%" stop-color="#e0f7fa"/>
      <stop offset="100%" stop-color="#00f2fe"/>
    </linearGradient>
  </defs>

  <rect width="1024" height="320" rx="24" fill="url(#banner-bg)" stroke="#222b40" stroke-width="2"/>

  <!-- Embedded Logo on Left -->
  <g transform="translate(32, 16) scale(0.5625)">
''' + CONJUNCTION_MARK_SVG.split('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="100%" height="100%">')[1].replace('</svg>', '') + '''
  </g>

  <!-- Typography on Right -->
  <g transform="translate(340, 115)">
    <text x="0" y="32" font-family="-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, sans-serif" font-size="52" font-weight="900" letter-spacing="4" fill="url(#brand-text-grad)">
      CONJUNCTION
    </text>
    <text x="440" y="32" font-family="-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, sans-serif" font-size="52" font-weight="300" letter-spacing="6" fill="#38bdf8">
      OS
    </text>
    <text x="4" y="78" font-family="-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, sans-serif" font-size="20" font-weight="500" letter-spacing="3" fill="#94a3b8">
      NEXT-GEN ARCH LINUX · MACOS ELEGANCE · WINDOWS COMPATIBILITY
    </text>
    <line x1="4" y1="102" x2="620" y2="102" stroke="#1e293b" stroke-width="2"/>
    <text x="4" y="128" font-family="-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, sans-serif" font-size="14" font-weight="600" letter-spacing="2" fill="#00f2fe">
      SYSTEM INSTALLER &amp; ENVIRONMENT SETUP
    </text>
  </g>
</svg>
'''

def render_logo_png(output_path: str, size: int = 512, is_app_icon: bool = True) -> bool:
    """
    Renders the Conjunction OS God Logo to a PNG image using PIL.
    Produces high-fidelity anti-aliased geometry with vibrant celestial gradients,
    orbital swoops, planetary bodies, and the conjunction starburst.
    """
    if not HAS_PIL:
        return False

    # Render at 2x super-sampling for pristine anti-aliasing
    scale = 2
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = canvas_size / 512.0

    # 1. Background (if app icon, rounded dark squircle)
    if is_app_icon:
        # Outer glow and squircle
        pad = int(24 * s)
        rect_box = [pad, pad, canvas_size - pad, canvas_size - pad]
        corner_r = int(104 * s)
        
        # Create rounded rect mask
        mask = Image.new("L", (canvas_size, canvas_size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rounded_rectangle(rect_box, corner_r, fill=255)
        
        # Draw gradient inside squircle
        surface = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        surf_draw = ImageDraw.Draw(surface)
        for y in range(pad, canvas_size - pad):
            t = (y - pad) / max(1, (canvas_size - 2 * pad))
            # Deep celestial dark gradient
            r = int(19 * (1 - t) + 4 * t)
            g = int(24 * (1 - t) + 6 * t)
            b = int(38 * (1 - t) + 11 * t)
            surf_draw.line([(pad, y), (canvas_size - pad, y)], fill=(r, g, b, 255))
        
        # Paste surface using mask
        img.paste(surface, (0, 0), mask)
        
        # Draw border
        draw.rounded_rectangle(rect_box, corner_r, outline=(0, 242, 254, 180), width=max(1, int(3 * s)))
        
        # Subtle top specular
        gloss = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        gloss_draw = ImageDraw.Draw(gloss)
        for y in range(pad, int(canvas_size * 0.45)):
            gt = 1.0 - (y - pad) / (canvas_size * 0.45 - pad)
            alpha = int(32 * gt)
            gloss_draw.line([(pad + int(10 * s), y), (canvas_size - pad - int(10 * s), y)], fill=(255, 255, 255, alpha))
        img.paste(gloss, (0, 0), mask)

    # 2. Ambient Nebula Glow
    cx, cy = int(256 * s), int(256 * s)
    nebula = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    neb_draw = ImageDraw.Draw(nebula)
    step_neb1 = max(1, int(4 * s))
    for r in range(max(1, int(220 * s)), 0, -step_neb1):
        t = r / (220.0 * s)
        alpha = int(45 * (1.0 - t))
        neb_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 242, 254, alpha))
    step_neb2 = max(1, int(3 * s))
    for r in range(max(1, int(160 * s)), 0, -step_neb2):
        t = r / (160.0 * s)
        alpha = int(50 * (1.0 - t))
        neb_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(121, 40, 202, alpha))
    img.alpha_composite(nebula)

    # 3. Outer Guide Circles
    draw.ellipse([cx - int(210 * s), cy - int(210 * s), cx + int(210 * s), cy + int(210 * s)],
                 outline=(79, 172, 254, 80), width=max(1, int(2 * s)))
    draw.ellipse([cx - int(180 * s), cy - int(180 * s), cx + int(180 * s), cy + int(180 * s)],
                 outline=(121, 40, 202, 60), width=max(1, int(1.5 * s)))

    # 4. Transverse Crossed Orbit (Teal / Violet)
    cross_pts = []
    # Parametric curve for the dynamic cross orbit
    for i in range(120):
        t = i / 119.0
        angle = t * math.pi * 1.6 - 0.4
        rx = 160 * s * (1.0 + 0.15 * math.cos(angle * 2))
        ry = 130 * s * (1.0 - 0.1 * math.sin(angle))
        # Rotate 42 degrees
        rot = math.radians(42)
        px = cx + rx * math.cos(angle) * math.cos(rot) - ry * math.sin(angle) * math.sin(rot)
        py = cy + rx * math.cos(angle) * math.sin(rot) + ry * math.sin(angle) * math.cos(rot)
        cross_pts.append((px, py))

    orbit_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    ol_draw = ImageDraw.Draw(orbit_layer)
    for i in range(len(cross_pts) - 1):
        t = i / float(len(cross_pts))
        r = int(56 * (1 - t) + 155 * t)
        g = int(239 * (1 - t) + 81 * t)
        b = int(125 * (1 - t) + 224 * t)
        ol_draw.line([cross_pts[i], cross_pts[i+1]], fill=(r, g, b, 210), width=max(2, int(8 * s)))

    # 5. Major Primary Orbit (The Conjunction Sweep Arc 'C')
    major_pts = []
    for i in range(160):
        t = i / 159.0
        angle = 0.5 + t * (math.pi * 1.65)
        rad = 175 * s + 18 * s * math.sin(angle * 2)
        px = cx + rad * math.cos(angle)
        py = cy + rad * math.sin(angle)
        major_pts.append((px, py))

    for i in range(len(major_pts) - 1):
        t = i / float(len(major_pts))
        # Cyan -> Blue -> Purple -> Magenta gradient
        if t < 0.4:
            local_t = t / 0.4
            r = int(0 * (1 - local_t) + 79 * local_t)
            g = int(242 * (1 - local_t) + 172 * local_t)
            b = int(254 * (1 - local_t) + 254 * local_t)
        elif t < 0.75:
            local_t = (t - 0.4) / 0.35
            r = int(79 * (1 - local_t) + 111 * local_t)
            g = int(172 * (1 - local_t) + 66 * local_t)
            b = int(254 * (1 - local_t) + 193 * local_t)
        else:
            local_t = (t - 0.75) / 0.25
            r = int(111 * (1 - local_t) + 255 * local_t)
            g = int(66 * (1 - local_t) + 0 * local_t)
            b = int(193 * (1 - local_t) + 127 * local_t)
        ol_draw.line([major_pts[i], major_pts[i+1]], fill=(r, g, b, 240), width=max(3, int(14 * s)))

    # Blur orbit slightly for soft outer bloom
    glow_orbit = orbit_layer.filter(ImageFilter.GaussianBlur(radius=max(1, int(4 * s))))
    img.alpha_composite(glow_orbit)
    img.alpha_composite(orbit_layer)

    # 6. Alignment Ray
    p1 = (int(195 * s), int(305 * s))
    p2 = (int(330 * s), int(175 * s))
    draw.line([p1, p2], fill=(255, 255, 255, 140), width=max(1, int(2 * s)))

    # 7. Primary Celestial Orb (Azure Planet)
    p1_x, p1_y = p1
    p1_r = int(46 * s)
    # 3D sphere gradient
    for r in range(p1_r, 0, -1):
        t = r / float(p1_r)
        off_x = int(p1_x - (p1_r - r) * 0.35)
        off_y = int(p1_y - (p1_r - r) * 0.35)
        red = int(255 * (1 - t)**2 + 0 * t)
        grn = int(240 * (1 - t) + 62 * t)
        blu = int(255 * (1 - t) + 138 * t)
        draw.ellipse([off_x - r, off_y - r, off_x + r, off_y + r], fill=(red, grn, blu, 255))

    # Planetary Ring across Sphere 1
    ring_w = int(64 * s)
    ring_h = int(18 * s)
    ring_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    rl_draw = ImageDraw.Draw(ring_layer)
    rl_draw.ellipse([p1_x - ring_w, p1_y - ring_h, p1_x + ring_w, p1_y + ring_h],
                    outline=(0, 242, 254, 220), width=max(2, int(4 * s)))
    ring_rot = ring_layer.rotate(-28, center=(p1_x, p1_y))
    img.alpha_composite(ring_rot)

    # 8. Secondary Companion Orb (Cosmic Violet Planet)
    p2_x, p2_y = p2
    p2_r = int(30 * s)
    for r in range(p2_r, 0, -1):
        t = r / float(p2_r)
        off_x = int(p2_x - (p2_r - r) * 0.3)
        off_y = int(p2_y - (p2_r - r) * 0.3)
        red = int(255 * (1 - t) + 74 * t)
        grn = int(220 * (1 - t) + 20 * t)
        blu = int(255 * (1 - t) + 140 * t)
        draw.ellipse([off_x - r, off_y - r, off_x + r, off_y + r], fill=(red, grn, blu, 255))
    draw.ellipse([p2_x + int(34 * s), p2_y - int(12 * s), p2_x + int(42 * s), p2_y - int(4 * s)], fill=(0, 242, 254, 255))

    # 9. The Conjunction Starburst / Divine Singularity
    star_x, star_y = int(262 * s), int(240 * s)
    star_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sl_draw = ImageDraw.Draw(star_layer)

    # Ambient flare
    flare_r = int(55 * s)
    for r in range(flare_r, 0, -max(1, int(2 * s))):
        t = r / float(flare_r)
        alpha = int(140 * (1.0 - t)**1.5)
        sl_draw.ellipse([star_x - r, star_y - r, star_x + r, star_y + r], fill=(0, 242, 254, alpha))

    # Primary 4 Spikes (Vertical & Horizontal diamond spikes)
    spike_len = int(50 * s)
    spike_w = max(2, int(8 * s))
    poly_v = [
        (star_x, star_y - spike_len),
        (star_x + spike_w, star_y),
        (star_x, star_y + spike_len),
        (star_x - spike_w, star_y)
    ]
    poly_h = [
        (star_x - spike_len, star_y),
        (star_x, star_y + spike_w),
        (star_x + spike_len, star_y),
        (star_x, star_y - spike_w)
    ]
    sl_draw.polygon(poly_v, fill=(255, 255, 255, 255))
    sl_draw.polygon(poly_h, fill=(255, 255, 255, 255))

    # Diagonal 4 Spikes
    diag_len = int(28 * s)
    diag_w = max(1, int(5 * s))
    poly_d1 = [
        (star_x - diag_len, star_y - diag_len),
        (star_x + diag_w, star_y - diag_w),
        (star_x + diag_len, star_y + diag_len),
        (star_x - diag_w, star_y + diag_w)
    ]
    poly_d2 = [
        (star_x + diag_len, star_y - diag_len),
        (star_x + diag_w, star_y + diag_w),
        (star_x - diag_len, star_y + diag_len),
        (star_x - diag_w, star_y - diag_w)
    ]
    sl_draw.polygon(poly_d1, fill=(0, 242, 254, 210))
    sl_draw.polygon(poly_d2, fill=(0, 242, 254, 210))

    # Star singularity dot
    core_r = max(2, int(6 * s))
    sl_draw.ellipse([star_x - core_r, star_y - core_r, star_x + core_r, star_y + core_r], fill=(255, 255, 255, 255))

    # Composite star flare with glow
    star_glow = star_layer.filter(ImageFilter.GaussianBlur(radius=max(1, int(3 * s))))
    img.alpha_composite(star_glow)
    img.alpha_composite(star_layer)

    # Downsample super-sampled image with Lanczos for crystal-clear antialiasing
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    final_img.save(output_path, "PNG")
    return True

def export_all_brand_assets(target_base_dir: str) -> Dict[str, str]:
    """
    Exports SVGs and all standard PNG resolutions to the designated target directory.
    Returns mapping of asset names to relative paths.
    """
    base = Path(target_base_dir)
    base.mkdir(parents=True, exist_ok=True)

    # 1. Write SVG vectors
    svg_mark_path = base / "conjunction-mark.svg"
    svg_app_path = base / "conjunction-logo.svg"
    svg_banner_path = base / "conjunction-banner.svg"

    svg_mark_path.write_text(CONJUNCTION_MARK_SVG, encoding="utf-8")
    svg_app_path.write_text(CONJUNCTION_APP_ICON_SVG, encoding="utf-8")
    svg_banner_path.write_text(CONJUNCTION_BRANDED_BANNER_SVG, encoding="utf-8")

    exported = {
        "svg_mark": str(svg_mark_path),
        "svg_logo": str(svg_app_path),
        "svg_banner": str(svg_banner_path),
    }

    # 2. Render PNG resolutions
    sizes = [16, 24, 32, 48, 64, 128, 256, 512]
    icons_dir = base / "icons"
    icons_dir.mkdir(exist_ok=True)

    for sz in sizes:
        png_path = icons_dir / f"conjunction-{sz}.png"
        render_logo_png(str(png_path), size=sz, is_app_icon=True)
        exported[f"png_{sz}"] = str(png_path)

    # Render primary desktop app icon and installer icon
    primary_png = base / "conjunction.png"
    installer_png = base / "conjunction-installer.png"
    welcome_png = base / "conjunction-welcome.png"

    render_logo_png(str(primary_png), size=256, is_app_icon=True)
    render_logo_png(str(installer_png), size=256, is_app_icon=True)
    render_logo_png(str(welcome_png), size=256, is_app_icon=True)

    exported["primary_png"] = str(primary_png)
    exported["installer_png"] = str(installer_png)
    exported["welcome_png"] = str(welcome_png)

    return exported

def install_system_icons(airootfs_dir: str):
    """
    Installs SVG vectors and PNG icons into the airootfs filesystem structure
    under /usr/share/icons/hicolor and /usr/share/pixmaps.
    """
    airootfs = Path(airootfs_dir)
    pixmaps_dir = airootfs / "usr" / "share" / "pixmaps"
    scalable_dir = airootfs / "usr" / "share" / "icons" / "hicolor" / "scalable" / "apps"
    pixmaps_dir.mkdir(parents=True, exist_ok=True)
    scalable_dir.mkdir(parents=True, exist_ok=True)

    # Scalable SVGs
    (scalable_dir / "conjunction.svg").write_text(CONJUNCTION_APP_ICON_SVG, encoding="utf-8")
    (scalable_dir / "conjunction-installer.svg").write_text(CONJUNCTION_APP_ICON_SVG, encoding="utf-8")
    (scalable_dir / "conjunction-welcome.svg").write_text(CONJUNCTION_APP_ICON_SVG, encoding="utf-8")
    (scalable_dir / "conjunction-mark.svg").write_text(CONJUNCTION_MARK_SVG, encoding="utf-8")

    # Pixmaps (standard 256x256)
    render_logo_png(str(pixmaps_dir / "conjunction.png"), size=256, is_app_icon=True)
    render_logo_png(str(pixmaps_dir / "conjunction-installer.png"), size=256, is_app_icon=True)
    render_logo_png(str(pixmaps_dir / "conjunction-welcome.png"), size=256, is_app_icon=True)

    # Resolution hierarchy
    sizes = [16, 24, 32, 48, 64, 128, 256, 512]
    for sz in sizes:
        sz_dir = airootfs / "usr" / "share" / "icons" / "hicolor" / f"{sz}x{sz}" / "apps"
        sz_dir.mkdir(parents=True, exist_ok=True)
        render_logo_png(str(sz_dir / "conjunction.png"), size=sz, is_app_icon=True)
        render_logo_png(str(sz_dir / "conjunction-installer.png"), size=sz, is_app_icon=True)
        render_logo_png(str(sz_dir / "conjunction-welcome.png"), size=sz, is_app_icon=True)

    # Branding directory
    branding_dir = airootfs / "usr" / "share" / "conjunction" / "branding"
    branding_dir.mkdir(parents=True, exist_ok=True)
    (branding_dir / "conjunction-logo.svg").write_text(CONJUNCTION_APP_ICON_SVG, encoding="utf-8")
    (branding_dir / "conjunction-banner.svg").write_text(CONJUNCTION_BRANDED_BANNER_SVG, encoding="utf-8")
    render_logo_png(str(branding_dir / "conjunction-logo-512.png"), size=512, is_app_icon=True)

if __name__ == "__main__":
    import sys
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "./assets"
    print(f"Exporting Conjunction OS brand assets to {out_dir}...")
    assets = export_all_brand_assets(out_dir)
    for k, v in assets.items():
        print(f"  - {k}: {v}")
    
    # If airootfs path is given as second argument, install system icons
    if len(sys.argv) > 2:
        airootfs_arg = sys.argv[2]
        print(f"Installing system icons to {airootfs_arg}...")
        install_system_icons(airootfs_arg)
    print("Conjunction God Logo assets exported successfully.")
