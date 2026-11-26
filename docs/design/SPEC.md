# Conjunction Desktop Environment Specification

**Target Platform:** Fedora Atomic, KDE Plasma 6 (Plasma 6.3+, Wayland), `x86_64` & `aarch64`  
**Design Baseline:** Liquid Glass desktop compositor, spatial windowing shell, typography, motion, and filesystem UX  
**Units:** Logical points (`pt`, 1x composited layout space = Qt `dp` / CSS `px` at 100% scale; rasterized `2x` on Retina/HiDPI displays unless explicitly noted in `px`). Colors are specified in **sRGB IEC61966-2.1** (with Display P3 equivalents noted where wide gamut applies).

---

## 1. Liquid Glass Material System

The desktop chrome uses a multi-stage composited lens pipeline (**Liquid Glass**) rather than flat translucent frosted acrylic. All primary color transforms (`FaceColorMatrix`, `FaceFill`, `vibrantColorMatrix`) operate in **gamma-encoded sRGB `[0.0, 1.0]` space** (empirically verified: sRGB-space model fits measured ramps within `0.0008` MAE vs `0.086–0.102` MAE in linearized space).

### 1.1 Layer Order & Compositing Pipeline

Evaluate per glass surface bounds with signed distance $d(p) \ge 0$ inward from the continuous superellipse boundary (outer shadow outside $d < 0$):

1. **Outer Drop Shadow** (under glass boundary; see Section 2.5).
2. **Backdrop Capture & Downsampled Gaussian Blur**: Sample screen region behind the glass shape (expanded by refraction capture margin) and apply separable Gaussian blur with standard deviation $\sigma_{\text{pt}}$ and optional secondary `BlurFill` pass.
3. **SDR Highlight Clamping (`MaxLumaSDR`)**: Clamp incoming blurred RGB channels $C_{\text{blur}}$ component-wise *before* applying the face color matrix (preserving headroom and forcing bright backgrounds under dark chrome into legibility):
   $$C_{\text{clamp}} = \min(C_{\text{blur}}, L_{\max}(m))$$
   where $m = \min(w, h)$ is the smaller surface dimension in `pt`.
4. **Radial Edge Refraction**: Warp backdrop UV sampling inward along the negative signed-distance normal $\hat{n} = \nabla d / \|\nabla d\|$:
   $$p_{\text{sample}} = p - \Delta r(d)\,\hat{n}$$
   with empirically measured exponential edge falloff over inner refraction depth $H = 20\text{ pt}$:
   $$\Delta r(d) = \begin{cases} 45.21 \cdot \exp(-d / 6.79)\text{ pt}, & d \in [0, 24]\text{ pt (Clear)} \\ 0, & d > 24\text{ pt} \end{cases}$$
   In **Regular** glass, un-refracted secondary `BlurFill` (`NormalOpacity = 0.5`) blends with refracted layer, yielding effective surface displacement $\Delta r_{\text{eff}}(0) \approx 31.5\text{ pt}$.
5. **Saturation Boost + Black/White Lift Matrix + Face Fill**:
   - Compute Rec. 709 luma $Y = 0.2126 R + 0.7152 G + 0.0722 B$ in sRGB.
   - Apply saturation matrix: $C_{\text{sat}} = Y + S \cdot (C_{\text{clamp}} - Y)$.
   - Remap `[0, 1]` range to `[Black, White]`:
     $$C_{\text{face}} = \text{Black} + (\text{White} - \text{Black}) \cdot C_{\text{sat}}$$
   - Alpha-over `FaceFillColor`: $C_{\text{out}} = C_{\text{face}} \cdot (1 - \alpha_{\text{fill}}) + C_{\text{fill}} \cdot \alpha_{\text{fill}}$.
6. **Secondary Fill & Bleed (`Regular` variant only)**:
   - Secondary blur (`BlurFillBlurRadius = 8 pt`) composited via `Lighten` (Light) or `Darken` (Dark) at opacity `0.9`, plus `Normal` at `0.5`.
   - `Bleed` pass with radius/height `0.35 * m` lifting edges cleanly toward neutral luminance when `BlurFill` is active (`Clear` sets `Bleed = 0`, `BlurFill = 0`).
7. **Tint Overlay (Glass Tint Property)**:
   - Mask over signed-distance stops `[-1, 0, 10] pt` premultiplied.
   - **Regular variant:** Enforces a **monochrome** luminance-preserving contrast tint (`S = 0.70`, `[0.7638, 0.2145, 0.0217]` weighted luminance + bias `±0.10`), resisting saturated hue washes on structural bars.
   - **Clear variant:** Preserves full chroma via luminance-coupled `colorMatrix` blending (`C_tint * (k_luma * Y + (1 - k_luma))`).
8. **Directional Key-Fill Specular Rim Highlight**:
   - Highlight vector angle $\theta = \pi/2$ (top-down `90°`), spread `120°` (`Regular`) or `75°` (`Clear`), band thickness `0.5 pt`, offset `-0.5 pt`, intensity `0.5` (`Regular`) / `0.4` (`Clear`), color bias `-0.1875` (`Regular`) / `-0.25` (`Clear`).
   - Top/bottom specular boost: Light multiplies by `0.3125 * C - 0.25` (additive lift `~+0.05..0.12` along top arc); Dark multiplies by `0.3125 * C + 0.9375` (crisp pale rim `~0.49` over `0.45` face white, subtle `0.27–0.33` dark hairline on side 0°/180° tangents).

### 1.2 Variant Parameter Table (`Regular` vs `Clear`, Light vs Dark)

Where $m = \min(w, h)$ in `pt` and $\text{clamp}(x,0,1)$ bounds `[0,1]`:

| Parameter | Regular Light | Regular Dark | Clear Light | Clear Dark |
|---|---|---|---|---|
| **Primary Blur $\sigma_{\text{pt}}$** | `14.0 pt` (effective w/ BlurFill) | `10.5 pt` (effective w/ BlurFill) | `2 * (5 + 5 * clamp((m - 48)/72))` (`20.0 pt` for $m \ge 120$) | `2 * (5 + 5 * clamp((m - 48)/72))` (`20.0 pt` for $m \ge 120$) |
| **`BlurOpacity` (base)** | `0.4 + 0.4 * clamp((m - 64)/96)` | `0.4 + 0.4 * clamp((m - 64)/96)` | `1.0` | `1.0` |
| **`MaxLumaSDR` ($L_{\max}$)** | `0.94` | `0.60 - 0.25 * clamp((m - 64)/40)` (`0.60` $\le64$, `0.35` $\ge104$) | `1.00` | `1.00` |
| **`FaceSaturation` ($S$)** | `1.20` | `1.30` | `1.00` | `1.00` |
| **`FaceBlack` / `FaceWhite`** | `0.40` / `0.96` | `0.08` / `1.125` | `0.20` / `0.95` | `0.05` / `0.80` |
| **`FaceFillColor` (sRGB α)** | `(1.0, 1.0, 1.0, 0.20)` | `(0.0, 0.0, 0.0, 0.00)` | `(1.0, 1.0, 1.0, 0.10)` | `(1.0, 1.0, 1.0, 0.05)` |
| **Transfer Check (`0 / 0.5 / 1.0` bg)** | `0.520 / 0.737 / 0.941` | `0.080 / 0.602 / 0.447` ($m=140$) | `0.280 / 0.618 / 0.955` | `0.098 / 0.455 / 0.810` |
| **`BlurFill` Radius & Blend** | `8 pt`, Lighten `0.9` + Normal `0.5` | `8 pt`, Darken `0.9` + Normal `0.5` | Disabled (`0`) | Disabled (`0`) |
| **`BleedAmount` / `Height`** | `0.35 * m` | `0.35 * m` | Disabled (`0`) | Disabled (`0`) |
| **Rim Thickness / Spread** | `0.5 pt` / `120°` | `0.5 pt` / `120°` | `0.5 pt` / `75°` | `0.5 pt` / `75°` |

**Adaptive Background Behavior:** Because `MaxLumaSDR` clamps high luminance before matrix expansion (`0.35` for large Dark Regular containers), placing a bright white window beneath Dark Regular glass clamps the refracted glass interior at `0.08 + 1.045 * 0.35 ≈ 0.447` (preventing blinding white blow-through while keeping foreground white labels at >= 4.5:1 contrast). Conversely, Light Regular lifts pure black `0.0` backdrops to `0.520`, preserving black label contrast.

### 1.3 Scroll-Edge Pocket (`ScrollPocket` Transition)

Scrolled content under floating toolbars and sidebars transitions cleanly rather than clipping sharply:
- **Soft Pocket (Default):** Three-layer stack anchored to the bar edge (`52–54 pt` height):
  1. Variable-blur backdrop + HDR-clamped color matrix masked by a vertical linear alpha gradient (`opacity 1.0 -> 0.0` over pocket height).
  2. Tinted/adaptable glass fill backdrop (`opacity = 0.8245`).
  3. Subtle chroma-adaptive overlay (`opacity = 0.10`).
- **Hard Pocket (Scrolled dense lists/tables):** Full-opacity backdrop (`0.85`) plus a bottom `0.5 pt` hairline separator (`rgba(255,255,255,0.07)` Dark / `rgba(0,0,0,0.098)` Light).

### 1.4 Glass Morphing Containers

Sibling glass pills/circles within an `EffectContainer` (default `spacing = 24 pt`) fuse via a smooth metaball/smin union field as edge gap decreases:
- For `56 pt` circles/capsules (`r = 28 pt`) at container `spacing = 24 pt`:
  - `gap = 0 pt`: fused bridge neck vertical height `34.0 pt` (`60.7%` of pill height)
  - `gap = 4 pt`: fused bridge neck height `30.5 pt`
  - `gap = 10 pt`: fused bridge neck height `15.0 pt`
  - `gap >= 20 pt`: cleanly separated (`neck <= 1 pt`)
- Smooth union polynomial blending factor: $k = \text{spacing} \cdot 0.60 \approx 14.4\text{ pt}$ via quadratic polynomial smooth-min:
  $$h = \max(k - |d_1 - d_2|, 0) / k, \quad d_{\text{union}} = \min(d_1, d_2) - \frac{1}{4} h^2 k$$

### 1.5 Accessibility Material Fallbacks

- **Reduce Transparency (`shouldReduceTransparency = true`):** Disable backdrop refraction and multi-pass blur. Replace glass fills with crisp chrome solids:
  - Light Chrome: background `#EDEDED` / Darken `0.75` luma blend + saturation `0.8` + brightness `+0.10`; Window chrome `#ECECEC`, Popover `#F4F4F4@1.0`, Menu/Selection `#D2D2D2@1.0` (`#004080` active text selection).
  - Dark Chrome: background `#282828` (`0.1569` sRGB `@0.90–1.0`); luma blend `0.85` + brightness `-0.10`, Active selection `#226BB9@1.0`.
- **Increase Contrast (`shouldIncreaseContrast = true`):** Replace translucent separator alphas with high-opacity strokes (`separator = 0.65` menu/divider alpha vs `0.12`/`0.30`), add continuous `1.0 pt` high-contrast perimeter borders (`white@0.45` Dark / `black@0.45` Light) around all glass pills, pushbuttons, sidebars, and cards, and lock text primaries to pure `#000000` (Light) / `#FFFFFF` (Dark) with secondary at `#A3A3A3` (`0.64`) / `#595959` (`0.35`).

### 1.6 Reference GLSL Fragment Shader (`KWin::OffscreenEffect` / Qt6 `ShaderEffect`)

```glsl
#version 330 core
uniform sampler2D u_backdropBlur;  // Pre-blurred screen texture behind surface (sigma = u_sigma)
uniform sampler2D u_backdropSharp; // Crisp or micro-blurred backdrop for refraction edge
uniform vec2  u_sizePt;            // Surface width, height in logical pt
uniform vec2  u_texelPerPt;        // 1.0 / backdropTextureSizePt
uniform float u_cornerRadius;      // Effective continuous corner radius (pt)
uniform int   u_variant;           // 0 = Regular, 1 = Clear
uniform int   u_darkMode;          // 0 = Light, 1 = Dark
uniform int   u_reduceTransparency;
uniform int   u_highContrast;
uniform vec4  u_tintColor;         // sRGB tint (a = 0 if untinted)

in vec2 v_uv;                      // [0..1] inside padded bounding quad
out vec4 fragColor;

// Continuous superellipse SDF (signed distance > 0 INSIDE box)
// Uses corner extension factor 1.528665 and squircle shoulder blending
float continuousRectSDF(vec2 p, vec2 halfSize, float r) {
    float effR = min(r, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + vec2(effR);
    // Superellipse exponent n ~ 4.4 approximates continuous curvature squircle shoulder
    vec2 k = max(q, 0.0);
    float cornerDist = pow(pow(k.x, 2.35) + pow(k.y, 2.35), 1.0 / 2.35);
    return -(min(max(q.x, q.y), 0.0) + cornerDist - effR); // >0 inside, <0 outside
}

vec2 continuousGrad(vec2 p, vec2 halfSize, float r) {
    const float eps = 0.25;
    float dx = continuousRectSDF(p + vec2(eps, 0.0), halfSize, r) - continuousRectSDF(p - vec2(eps, 0.0), halfSize, r);
    float dy = continuousRectSDF(p + vec2(0.0, eps), halfSize, r) - continuousRectSDF(p - vec2(0.0, eps), halfSize, r);
    vec2 g = vec2(dx, dy);
    float l = length(g);
    return l > 1e-5 ? g / l : vec2(0.0, 1.0);
}

void main() {
    vec2 halfSize = 0.5 * u_sizePt;
    vec2 p = (v_uv - 0.5) * u_sizePt;
    float d = continuousRectSDF(p, halfSize, u_cornerRadius);
    float aa = clamp(d + 0.5, 0.0, 1.0);
    if (aa <= 0.0) discard;

    if (u_reduceTransparency == 1) {
        vec3 opaqueBg = (u_darkMode == 1) ? vec3(0.1569) : vec3(0.9490);
        if (u_highContrast == 1 && d < 1.0) {
            opaqueBg = (u_darkMode == 1) ? vec3(0.70) : vec3(0.18);
        }
        fragColor = vec4(opaqueBg * aa, aa);
        return;
    }

    float m = min(u_sizePt.x, u_sizePt.y);

    // 1. Inward radial refraction displacement dr(d)
    vec2 normal = continuousGrad(p, halfSize, u_cornerRadius); // points inward
    float refrAmp = (u_variant == 0) ? 31.5 : 45.21;
    float dr = (d < 24.0) ? refrAmp * exp(-max(d, 0.0) / 6.79) : 0.0;
    vec2 uvRefr = clamp((gl_FragCoord.xy - normal * dr) * u_texelPerPt, 0.001, 0.999);
    vec3 blurRGB = texture(u_backdropBlur, uvRefr).rgb;

    // 2. SDR Highlight Clamp
    float maxLuma = 1.0;
    if (u_variant == 0) {
        maxLuma = (u_darkMode == 1)
            ? (0.60 - 0.25 * clamp((m - 64.0) / 40.0, 0.0, 1.0))
            : 0.94;
    }
    vec3 clamped = min(blurRGB, vec3(maxLuma));

    // 3. Saturation + Face Tone Transfer (sRGB)
    float Y = dot(clamped, vec3(0.2126, 0.7152, 0.0722));
    float sat = (u_variant == 1) ? 1.0 : ((u_darkMode == 1) ? 1.30 : 1.20);
    float blackLvl = (u_variant == 1) ? ((u_darkMode == 1) ? 0.05 : 0.20)
                                      : ((u_darkMode == 1) ? 0.08 : 0.40);
    float whiteLvl = (u_variant == 1) ? ((u_darkMode == 1) ? 0.80 : 0.95)
                                      : ((u_darkMode == 1) ? 1.125 : 0.96);
    vec3 satRGB = vec3(Y) + sat * (clamped - vec3(Y));
    vec3 face = clamp(mix(vec3(blackLvl), vec3(whiteLvl), satRGB), 0.0, 1.0);

    // 4. FaceFill overlay
    vec4 faceFill = (u_variant == 1)
        ? ((u_darkMode == 1) ? vec4(1.0, 1.0, 1.0, 0.05) : vec4(1.0, 1.0, 1.0, 0.10))
        : ((u_darkMode == 1) ? vec4(0.0, 0.0, 0.0, 0.00) : vec4(1.0, 1.0, 1.0, 0.20));
    face = mix(face, faceFill.rgb, faceFill.a);

    // 5. Optional Tint
    if (u_tintColor.a > 0.001) {
        if (u_variant == 0) {
            float lumaM = dot(face, vec3(0.7638, 0.2145, 0.0217)) + ((u_darkMode == 1) ? 0.10 : -0.10);
            face = mix(face, vec3(clamp(lumaM, 0.0, 1.0)), u_tintColor.a * 0.70);
        } else {
            vec3 tinted = u_tintColor.rgb * mix(1.0, Y + 0.35, 0.45);
            face = mix(face, clamp(tinted, 0.0, 1.0), u_tintColor.a);
        }
    }

    // 6. Specular Key-Fill Rim Highlight (90 deg top vector, 0.5-1.0 pt rim)
    float rimMask = 1.0 - smoothstep(0.0, 1.25, max(d, 0.0));
    float dirDot = -normal.y; // +1 at top edge, -1 at bottom, 0 at sides
    float specTop = smoothstep(0.0, (u_variant == 0) ? 0.86 : 0.50, abs(dirDot));
    float sideShade = 1.0 - smoothstep(0.3, 0.9, 1.0 - abs(dirDot));
    vec3 rimColor = (u_darkMode == 1)
        ? mix(vec3(0.29), vec3(0.3125 * face + 0.9375) * 0.55, specTop)
        : mix(vec3(0.73), vec3(1.0), specTop);
    float rimAmt = (u_variant == 0) ? 0.50 : 0.40;
    face = mix(face, clamp(rimColor, 0.0, 1.0), rimMask * rimAmt * (0.45 + 0.55 * max(specTop, sideShade)));

    if (u_highContrast == 1 && d < 1.0) {
        face = (u_darkMode == 1) ? vec3(0.58) : vec3(0.28);
    }

    fragColor = vec4(face * aa, aa);
}
```

---

## 2. Design Tokens & Open Substitute Alignment

All open assets follow `docs/design/ASSETS.md`. Proprietary brand glyphs, system font files, or trademarked app icons are strictly omitted.

### 2.1 Corner Radii & Concentric Nesting Rule

All rounded containers use **continuous curvature squircles** (`cornerCurve = continuous`; tangent extends `1.528665 * r` from the corner vertex along each straight edge, visually equivalent to ~60% corner smoothing).

**Concentric Formula:**
$$R_{\text{inner}} = \max\!\bigl(R_{\min},\; R_{\text{outer}} - \text{padding}\bigr), \qquad R_{\min} = 4\text{ pt}$$

| Surface / Component | Corner Radius (`pt`) | Notes |
|---|---|---|
| Standard Document Window (`Toolbar` / `Plain`) | `16.0` | `1.528665 * 16 = 24.46 pt` continuous tangent start |
| Window Inset Sidebar Container Padding | `0.0` (flush) / `10.0` (inset pill row margin) | Sidebar rows inset `10 pt` -> `10 pt` pill radius |
| Sheet / Modal Dialog | `16.0` (standard), `26.0` (large glass sheet) | Concentric with footer `14 pt` alert pills at `12 pt` bottom margin |
| Popover / Floating Menu | `14.0` (popover), `12.0` (context/pull-down menu) | Menu hover highlight item inset `4 pt` -> `8 pt` inner radius |
| Control Center Module Tile (`2x2` / `4x1` / `2x1` / `1x1`) | `h / 2` (`32.0` capsule for `64 pt` rows), `24.0` (`2x2` `140x140`) | `12 pt` inter-module gutter |
| Dock Background Pill | `h / 2` (full capsule `~36.5–54 pt`) or `24.0` fixed cap | `5.5 pt` margin from bottom screen edge |
| Quick Search Capsule | `h / 2` (`32.75 pt` for `65.5 pt` bar) | Quick action circles `h / 2` (`32.0 pt`) |
| Push Button (Regular `32 pt`, Pill `28 pt`) | `h / 2` (capsule) or `8.0` (classic) | Liquid Glass toolbar buttons are `h / 2 = 18.0 pt` circles/capsules |
| Segmented Control (`Toolbar 25 pt` / `Regular 24 pt`) | `h / 2` (outer track), `(h - 4)/2` (active thumb) | `2 pt` internal inset |
| Sidebar Selection Pill (`Files` / `Settings`) | `10.0` | Concentric inside `10 pt` sidebar inset (`20 pt` effective corner) |
| App Icon Mask (`512x512` Master Grid) | `22.37%` of width (`~114.5 px` @ `512 px`) | Continuous squircle, 22% safe inner glyph zone |
| Checkbox (`14 pt`) / TextField / Alert Menu Row | `4.5–5.0` (checkbox), `8.0` (textfield/search), `6.0` (row) | — |

### 2.2 Spacing Grid

- **Base Grid:** `4 pt` primary unit (`8 pt` rhythm for layouts; `2 pt` half-step strictly for icon-text hair gaps and control insets).
- **Standard Margins & Gutters:**
  - `2 pt`: Segmented thumb inset, focus-border hairline offset, slider knob edge gap.
  - `4 pt`: Menu item padding (`4 pt` horizontal from menu edge), tight inline glyph-to-label gap (`4–6 pt`).
  - `8 pt`: Standard inline button spacing, form row inter-control gap, stacked text gap.
  - `10 pt`: Sidebar horizontal pill inset, Settings card group vertical gap.
  - `12 pt`: Control Center grid gutter, Dock icon inner margin, dialog action spacing.
  - `16 pt`: Sheet edge margin, card internal horizontal padding, Notification Center right screen gap (`16 pt`).
  - `20 pt`: Window body content outer margin, section spacing between major preference panes.
  - `24 pt`: `EffectContainer` glass morphing neighborhood radius.

### 2.3 Control Size Scale

Exact layout bounding sizes measured from native control sizing (`mini`, `small`, `regular`, `large`, `extraLarge`):

| Control | `.mini` | `.small` | `.regular` | `.large` | `.extraLarge` |
|---|---|---|---|---|---|
| **Push Button Height** | `16 pt` | `27 pt` | `32 pt` | `40 pt` | `40 pt` |
| **Alert / Sheet Pill Button** | — | — | `28 pt` (`cr=14`) | — | — |
| **Toolbar Icon Circle / Pill** | — | `28 pt` | `36 pt` (`cr=18`) | `36 pt` | — |
| **Segmented Control Height** | `16 pt` | `21 pt` | `24 pt` | `40 pt` | `40 pt` |
| **Toolbar Segmented Height** | `18 pt` | `21 pt` | `25 pt` | `40 pt` | `40 pt` |
| **TextField Height** | `16 pt` | `19 pt` | `24 pt` | `28 pt` | `36 pt` |
| **SearchField Height** | `16 pt` | `19 pt` | `24 pt` | `28 pt` | `36 pt` |
| **PopUpButton Height** | `16 pt` | `21 pt` | `24 pt` | `28 pt` | `36 pt` |
| **ComboBox Height** | `16 pt` | `21 pt` | `24 pt` | `28 pt` | `28 pt` |
| **Switch (`Width x Height`)** | `26 x 15` | `32 x 18` | `42 x 25` | `42 x 25` | — |
| **CheckBox (`Box / Fitting`)** | `14 / 15` | `16 / 17` | `18 / 20` | `20 / 22` | — |
| **Radio (`Circle / Fitting`)** | `14 / 15` | `16 / 17` | `18 / 20` | `20 / 22` | — |
| **Slider Track / Circular Knob** | `3 pt` track | `4 pt` track | `4 pt` track / `20 x 28` pill | `4 pt` / `24 x 28` pill | — |
| **Stepper (`W x H`)** | `15 x 18` | `17 x 21` | `19 x 24` | `19 x 28` | `19 x 28` |
| **Overlay Scrollbar Track (`idle -> hover`)** | — | `10 -> 14 pt` | `12 -> 16 pt` | — | — |

### 2.4 Typography Scale & Open Substitute Tuning

Substitute families per `docs/design/ASSETS.md`:
- **UI Sans (`< 20 pt`):** `Inter` (Text / variable optical size clamped `10..17`).
- **UI Display (`>= 20 pt`):** `Inter Display` (or `Inter` variable `opsz >= 20`).
- **Monospace:** `JetBrains Mono` (Regular/Medium/Bold, `1000 UPM`, `0.600 em` fixed advance).
- **UI Symbols:** `Material Symbols Rounded` variable font (`FILL`, `wght`, `GRAD`, `opsz`), using `Phosphor` (`Regular`/`Bold` SVG strokes) for desktop glyphs missing from Material Symbols.

#### Measured Target Ratios vs Substitute Font Calibration

| Metric Ratio | Desktop Target (`13 pt`) | `Inter` (2048 UPM, Text) | `Inter Display` (2048 UPM) | `JetBrains Mono` (1000 UPM) |
|---|---|---|---|---|
| **Cap Height / `em`** | `0.70462` (`9.160 pt`) | `0.72754` (`1490 / 2048`) | `0.72754` (`1490 / 2048`) | `0.73000` (`730 / 1000`) |
| **x-Height / `em`** | `0.52638` (`6.843 pt`) | `0.54590` (`1118 / 2048`) | `0.51563` (`1056 / 2048`) | `0.55000` (`550 / 1000`) |
| **Ascender / `em`** | `+0.96677` (`+12.568 pt`) | `+0.96875` (`+1984 / 2048`) | `+0.96875` | `+1.02000` (`+1020`) |
| **Descender / `em`** | `-0.21092` (`-2.742 pt`) | `-0.24121` (`-494 / 2048`) | `-0.24121` | `-0.30000` (`-300`) |
| **Cap-Parity Scale Factor** | `1.0000x` | **`0.9685x`** (`12.59 pt` @ `13` slot) | **`0.9685x`** | **`0.9652x`** |

**Calibration Rule (Choose One Consistently Across Shell & Apps):**
- **Option A — Exact Optical Cap-Height Scaling (Recommended):** Set rendered Qt/CSS `pixelSize = targetPt * 0.9685` (`12.6 px` for `13 pt` body, `25.2 px` for `26 pt` largeTitle) with `letter-spacing = targetTrackingEm`, keeping native vertical box sizes (`19 pt` line box, `32 pt` button cap alignment) identical without text vertical clipping.
- **Option B — Nominal `pt` Sizing (`1.0x`):** Keep integer `pt` values directly, shift `Inter` `font.letterSpacing` explicitly to match target tracking (overriding Inter's default `-0.0223 + 0.185*exp(-0.1745*z)` dynamic formula, which is `+0.010em` at `10pt` and `-0.020em` at `26pt`), and rely on the `16 pt` / `19 pt` container line height.

#### Type Scale & Weight Mapping

| Role | Size (`pt`) | Line Height (`pt`) | Weight (`Inter`) | Target Tracking (`em`) | Family | Notes |
|---|---|---|---|---|---|---|
| `largeTitle` | `26` | `39` (`32` tight) | Regular (`400`) | `-0.0034` | `Inter Display` | Window hero headers |
| `title1` | `22` | `33` (`26` tight) | Regular (`400`) | `-0.0024` | `Inter Display` | Settings / sheet title |
| `title2` | `17` | `27` (`22` tight) | Regular (`400`) | `-0.0010` | `Inter` | Alert bold title (`17 Bold`) |
| `title3` | `15` | `24` (`20` tight) | Regular (`400`) | `-0.0010` | `Inter` | Inspector header |
| `headline` | `13` | `19` (`16` compact) | Bold (`700`) / SemiBold (`600`) | `-0.0010` | `Inter` | Emphasized body, sidebar section (`11` bold) |
| `body` / **Control Regular** | `13` | `19` (`16` control box) | Regular (`400`) | `-0.0010` | `Inter` | Buttons, menus (`13`), list items |
| `callout` | `12` | `18` (`15` tight) | Regular (`400`) | `-0.0010` | `Inter` | Secondary table rows |
| `subheadline` / **Small** | `11` | `17` (`14` tight) | Regular (`400`) | `-0.0010` | `Inter` | Status bar (`11` `tnum`), sidebar headers |
| `footnote` / `caption1` | `10` | `16` (`13` tight) | Regular (`400`) | `-0.0010` | `Inter` | Toolbar icon captions (`10`), badges |
| `caption2` | `10` | `16` (`13` tight) | Medium (`500`) | `-0.0010` | `Inter` | Dense metadata tags |
| `miniControl` | `9` | `11` | Regular (`400`) | `-0.0010` | `Inter` | `.mini` controls |
| `codeMono` | `13` (UI) / `12` (term) | `1.25x` | Regular (`400`) | `0.0000` | `JetBrains Mono` | Terminal (`0.965x` if matching cap-height) |

- **Tabular Figures (`font.features: { "tnum": 1 }`):** Mandatory on Status Bar counters, file sizes, timestamps, Files list date/size columns, and Menu Bar clock (`Thu 26 Nov 22:00`).

#### `Material Symbols Rounded` Variable Axis Tuning

| UI Context | `FILL` | `wght` | `GRAD` | `opsz` | Nominal Icon Frame |
|---|---|---|---|---|---|
| Menu Bar Item (`39 pt` bar) | `1` (or `0` strokes) | `500` | `0` (`+25` Dark bg) | `20` | `16–18 pt` (`18 pt` notch clear) |
| Sidebar Row Icon (`28–32 pt` row) | `0` (inactive) / `1` (active tint) | `400` | `0` | `20` | `16–18 pt` |
| Toolbar Glass Button (`36 pt` circle) | `0` | `400` | `0` | `24` | `16–18 pt` glyph |
| Control Center Toggle (`64 pt` tile) | `1` | `500` | `0` | `24` | `18–20 pt` inside `36 pt` inner circle |
| Empty-state / Hero Placeholder | `0` | `300` | `-25` | `48` | `48–64 pt` |

### 2.5 Shadows & Elevation

Measured active window drop shadow alpha falloff curve (in logical `pt` outward from window frame perimeter; Light & Dark use black `#000000` with scaled alpha):

| Edge Direction | Padding (`pt`) | Empirical Alpha Profile vs Outward Distance `d` | Notes |
|---|---|---|---|
| **Bottom (Active)** | `74 pt` | `0.5pt: 0.341`, `2.5pt: 0.157`, `6.5pt: 0.118`, `10.5pt: 0.078`, `16.5pt: 0.027`, `26.5pt: 0.004` | Approximated cleanly in Qt/GLSL by `yOffset = 18 pt`, `blurRadius = 38 pt`, `alpha = 0.34` + tight contact shadow `yOffset = 1 pt, blur = 3 pt, alpha = 0.22` |
| **Left / Right (Active)** | `56 pt` | `0.5pt: 0.286`, `1.5pt: 0.063`, `3.5pt: 0.012` | Sideways bloom tighter than bottom spread |
| **Top (Active)** | `38 pt` | `0.5pt: 0.231`, `1.0pt: 0.031`, `3.5pt: 0.004` | Keeps top perimeter anchored cleanly |
| **Inactive Window** | Same mask bounds | Multiply shadow opacity by `0.52` (`yOffset = 10 pt, blur = 22 pt, alpha = 0.18`) | Clear foreground/background separation |
| **Popover / Menu** | `32 pt` | `yOffset = 8 pt, blur = 20 pt, alpha = 0.24` + `0.5 pt` `black@0.12` rim | Lighter floating elevation |
| **Liquid Glass Pill / Card** | `12 pt` | `yOffset = 2 pt, blur = 8 pt, alpha = 0.14` (ambient separation) | Prevents blending over bright white surfaces |

### 2.6 Separators & Hairlines

- **Structural Standard Separator (`separatorColor`):** Light `#000000` @ `9.8%`, Dark `#FFFFFF` @ `9.8%` (`1.0 pt` logical / `0.5 pt` physical `1 px` Retina hairline on toolbar/table dividers).
- **Menu Separator (`_NSMenuSeparatorColor`):** Light `#000000` @ `12.0%` (`1 pt` line inset `10 pt` horizontally); Dark `#FFFFFF` @ `30.0%` (`1 pt`); **Increased Contrast:** `65.0%` alpha in both themes.
- **Toolbar Pocket Hairline (Scroll Pocket Hard style):** `#FFFFFF` @ `7.0%` (Dark) / `#000000` @ `9.8%` (Light).

### 2.7 Keyboard Focus Rings

Measured around focusable inputs, buttons, checkboxes, segmented groups, and sidebar outlines:
- **Outer Halo:** **`3.5 pt` outward offset**, filled with `keyboardFocusIndicatorColor`:
  - Light: `#0067F4` @ `50.0%` alpha (`P3: (0.046, 0.401, 0.927, 0.50)`).
  - Dark: `#1AA9FF` @ `50.0%` alpha (`P3: (0.147, 0.659, 0.996, 0.50)`).
  - Increased Contrast: same hue @ `75–85%` alpha + crisp `1.0 pt` outer ring.
- **Inner Crisp Line:** `0.5–1.0 pt` stroke along control edge at `90%` accent saturation.
- **Radius:** Outer focus ring uses `R_focus = R_control + 3.5 pt` (pill controls stay capsule; checkboxes `5 + 3.5 = 8.5 pt`).
- **Trigger Policy:** Full keyboard access mode activates focus ring *immediately* on `Tab`, `Shift+Tab`, `F7`, or Space/Enter keyboard triggers; pointer-click focus on buttons does NOT show focus halo unless the target is a text input (`TextField`, `SearchField`, editable combo box).

### 2.8 Semantic & System Color Tokens (sRGB & Display P3)

Measured semantic token resolution across Normal & Accessibility High Contrast:

| Semantic Token | Light Mode (sRGB / α) | Dark Mode (sRGB / α) | P3 Notes / AX High-Contrast |
|---|---|---|---|
| `controlAccentColor` | `#007AFF` (`1.0`) | `#007AFF` (`1.0`) | Base interactive accent |
| `systemBlue` | `#0088FF` (`0, 0.533, 1.0`) | `#0091FF` (`0, 0.569, 1.0`) | AX Light `#0066E8`, AX Dark `#35A8FF` |
| `systemRed` (Destructive) | `#FF383C` | `#FF4245` | Close TL fill `#E2685B` |
| `systemOrange` | `#FF8D28` | `#FF9230` | Tag / warning |
| `systemYellow` | `#FFCC00` | `#FFD600` | Minimize TL fill `#F4C32C` |
| `systemGreen` | `#34C759` | `#30D158` | Zoom TL fill `#62BD2E` |
| `systemMint` | `#00C8B3` | `#00DAC3` | — |
| `systemTeal` | `#00C3D0` | `#00D2E0` | — |
| `systemCyan` | `#00C0E8` | `#3CD3FE` | — |
| `systemIndigo` | `#6155F5` | `#6D7CFF` | — |
| `systemPurple` | `#CB30E0` | `#DB34F2` | — |
| `systemPink` | `#FF2D55` | `#FF375F` | — |
| `systemBrown` | `#AC7F5E` | `#B78A66` | — |
| `systemGray` | `#8E8E93` | `#98989D` | Neutral icon/glyph secondary |
| `labelColor` | `#000000` @ `84.7%` | `#FFFFFF` @ `84.7%` | AX: `#000000`/`#FFFFFF` @ `100%` |
| `secondaryLabelColor` | `#000000` @ `49.8%` | `#FFFFFF` @ `54.9%` | AX: `64%–70%` |
| `tertiaryLabelColor` | `#000000` @ `25.9%` | `#FFFFFF` @ `24.7%` | AX: `48%–50%` |
| `quaternaryLabelColor` | `#000000` @ `9.8%` | `#FFFFFF` @ `9.8%` | Watermarks, subtle grid |
| `windowBackgroundColor` | `#ECECEC` (`0.925`) | `#323232` (`0.196`) | Base frame behind chrome |
| `textBackgroundColor` | `#FFFFFF` (`1.0`) | `#1E1E1E` (`0.118`) | Document/table canvas |
| `controlBackgroundColor` | `#FFFFFF` (`1.0`) | `#1E1E1E` (`0.118`) | Editable control interior |
| `underPageBackgroundColor` | `#C8C8C8` (`0.784`) | `#1A1A1A` (`0.102`) | Gallery/document backdrop |
| `selectedContentBackgroundColor` | `#0067F4` (active) / `#DCDCDC` (unfocused) | `#0067F4` (active) / `#464646` (unfocused) | Active list/sidebar selection pill |
| `unemphasizedSelectedTextBg` | `#DCDCDC` (`0.863`) | `#464646` (`0.275`) | Inactive window list selection |
| `controlFill` / Card Surface | `#000000` @ `5.0%` | `#FFFFFF` @ `7.0%` | Settings group card fill (`~#2C2C2E` Dark) |
| `keyboardFocusIndicatorColor` | `#0067F4` @ `49.8%` | `#1AA9FF` @ `49.8%` | `3.5 pt` focus ring |

### 2.9 Iconography, GTK Theme, Cursors, Audio & Wallpapers (`ASSETS.md`)

1. **System Menu Brand Mark:** `assets/conjunction-mark.svg` (`512x512` viewBox), rendered monochrome template (`labelColor`) at `16 x 16 pt` inside the Menu Bar left pill/slot (replaces any proprietary vendor mark).
2. **Icons (`MacTahoe` Icon Theme + Originals):** Use `MacTahoe` for folders (`Folder`, `Applications`, `Documents`, `Downloads`, `Desktop`, `Trash`), mimetype badges, and third-party apps; strip/replace any proprietary OS logos, browser compasses, or smiling file-manager emblems with Conjunction equivalents (`conjunction-mark.svg`, generic `Files` two-tone glass folder, `Web Browser` globe). Original Conjunction system apps use `512x512` squircle canvas (`22.37%` radius = `114.5 px`) with layered vector/glass gradients.
3. **GTK Alignment:** Package `MacTahoe GTK` theme with `@define-color` overrides mapped verbatim to Section 2.8 (`windowBackgroundColor`, `textBackgroundColor`, `systemBlue`, `separatorColor`, `radius = 16 px / 8 px`).
4. **Cursors, Sound & Wallpaper:** **Bibata Modern** (`24 pt` pointer cursor, classic & dark variants matching screen mode); **freedesktop / ocean** sound theme mapped to `Trash Empty`, `Volume Mount/Eject`, `Alert Ping`, `Screenshot Shutter`; original procedural Light and Dark gradient wallpapers (zero bundled proprietary photos).

---

## 3. Motion System

All motion parameters were empirically captured on Retina `120 Hz` VFR screen recordings (`ffprobe` timestamps + frame RMSE curves). Where spring physics drive transitions, equivalent `stiffness / damping` (`mass = 1.0`) and `cubic-bezier` fallbacks are provided for KWin/QML implementations.

### 3.1 Transition Timing & Spring Table

| Transition | Measured Duration (`ms`) | Curve / Physics Model | Visual & Spatial Behavior |
|---|---|---|---|
| **Window Open** (`Cmd+N`) | `230–250` | Underdamped spring (`mass=1, stiffness=380, damping=32`) | Scale `0.88 -> 1.00`, opacity `0 -> 1` in first `~120 ms` |
| **Window Close** (`Cmd+W`) | `167` | Ease-out (`cubic-bezier(0.22, 0.61, 0.36, 1)`) | Scale `1.00 -> 0.90`, opacity `1 -> 0` smoothly |
| **Minimize (Genie)** | `400–450` (`308` active warp, `625` w/ Dock settle) | `cubic-bezier(0.42, 0.0, 0.58, 1.0)` mesh warp | 2-phase: top corners pinch inward while bottom edge pulls into Dock icon (`y` funnel curves `x(t)` sinusoidally between left/right window edges and target tile bounds) |
| **Unminimize (Genie)** | `~310` active warp | Inverse funnel ease-out | Emerges from Dock tile center (`w_tile -> w_win`), top edge expands last |
| **Minimize (Scale)** | `203` | `cubic-bezier(0.25, 0.1, 0.25, 1.0)` | Uniform scale down + linear translation toward Dock tile, opacity `1 -> 0.6 -> 0` in final `30 ms` |
| **Unminimize (Scale)** | `200` (`125` expand) | `cubic-bezier(0.16, 1.0, 0.3, 1.0)` | Expands linearly from tile rect to window rect |
| **Dock Autohide Slide-In** | `303` | Out-quad / spring (`stiffness=340, damping=34`) | Vertical Y slide from `bottomEdge + dockH + margin` to `bottomEdge - margin` (`5.5 pt`) |
| **Dock Autohide Slide-Out** | `292` | `cubic-bezier(0.4, 0.0, 1.0, 1.0)` (ease-in-out) | Vertical Y slide off-screen after pointer leaves Dock trigger zone (`~100 ms` dwell optional) |
| **Dock Magnification Enter** | `208` | Tight spring (`stiffness=420, damping=34`) | Smooth icon growth + neighbor horizontal push without overshoot |
| **Dock Magnification Exit** | `183` | Fast ease-out | Smoothly collapses magnified pill width back to nominal pitch |
| **Dock Launch Bounce** | `~680` period (`peak1 ~120ms`, `trough1 ~412ms`) | Vertical harmonic gravity bounce (`-sin` half-waves, `amplitude ~ 0.38 * tilesize` decaying gently) | Vertical `-Y` hop up to ~38% tile height, squash/zero bounce past bottom baseline; repeats until window maps (`<= 60s` timeout) |
| **Menu Open** | `50–100` (`~65`) | Snappy ease-out / immediate snap | Opacity `0 -> 1` + optional `2 pt` drop along anchor edge |
| **Menu Close** | `133` | Ease-out (`cubic-bezier(0.22, 1, 0.36, 1)`) | Fast fade out `1 -> 0` (menu highlight flashes `1x` crisp feedback on selected item if activated before fade) |
| **Sheet Open** | `300–350` (`~183` primary slide) | Critically damped spring (`stiffness=280, damping=33`) | Slides downward out of host window titlebar underside while clipping to titlebar bottom line + scrim darken (`0 -> 0.28` alpha) |
| **Sheet Close** | `333` (`44%@100ms, 86%@217ms, 100%@333ms`) | `cubic-bezier(0.25, 0.8, 0.25, 1.0)` | Retracts upward into titlebar clip seam while scrim fades |
| **Popover Open** | `158` | Spring (`stiffness=450, damping=35`) | Scale `0.94 -> 1.00` from anchor arrow, opacity `0 -> 1` |
| **Popover Close** | `150` (`4.3%` tiny spring settle `@92ms`) | Fast spring (`stiffness=480, damping=36`) | Scale `1.00 -> 0.94`, opacity `1 -> 0` |
| **Control Center Open** | `145–150` (`99.2%` @ `142 ms`) | Fast spring (`stiffness=460, damping=36`) | Unfurls from top-right menu item (`scale 0.92 -> 1.0`, opacity `0 -> 1`) |
| **Control Center Close** | `240–280` | Ease-out (`0.22, 1, 0.36, 1`) | Collapses scale slightly + opacity fade `1 -> 0` |
| **Notification Center Open** | `~300` (`250–500` content dependent) | Spring slide from right (`stiffness=300, damping=33`) | Widget stack slides horizontally from `screenW` -> `screenW - cardW - 16pt` |
| **Notification Center Close** | `242` | Ease-out (`cubic-bezier(0.4, 0, 0.2, 1)`) | Slides back right + opacity `1 -> 0` |
| **Quick Search Open** | `~170` | Tight pop spring (`stiffness=440, damping=35`) | Centered bar expands (`0.96 -> 1.00`), opacity `0 -> 1` |
| **Quick Search Close** | `~217` | Smooth ease-out | Opacity `1 -> 0` + slight vertical collapse |
| **Mission Control Enter** | `525` | Crit-damped spring (`stiffness=220, damping=29`) | Windows declutter/scale to non-overlapping grid while top `Spaces Bar` (`~135 pt`) slides down from under Menu Bar and desktop dims (`~0.25` dim + blur) |
| **Mission Control Exit** | `492` | Crit-damped spring (`stiffness=240, damping=31`) | Target space window scales up cleanly to full frame |
| **Spaces Horizontal Swipe** | `~550` (`95%` settle) / `~1000` (asymptotic tail) | Tracked 1:1 on gesture drag; release snaps via overdamped scroll spring (`stiffness=180, damping=28`) | Outgoing workspace translates horizontally `-1.0 * screenW` adjacent to incoming workspace with `~32 pt` inter-space black gap (`gap = 0.018 * screenW`) |
| **Button Hover / Press Feedback** | `<= 25` (`1–2` frames @120Hz) for state flip; `80` optional tint fade | Linear / instant state swap | Hover elevates luminance (`+4%` Dark / `-3%` Light on glass rim); active press dims (`-8%`) with subtle `0.985` micro-scale on pill actions |

### 3.2 Spatial Dock Magnification Curve

For pointer horizontal coordinate $x_p$ over Dock with unmagnified tile size $S_0$, slot pitch $P_0 \approx S_0 + 4\text{ pt}$, and maximum magnified icon size $S_{\max}$ (`largesize`, e.g., `128 pt`):

Empirically fitted against AX element bounds (cosine half-wave gives `RMSE = 0.0205`, outperforming Hann `cos^2` `0.0262` and Gaussian `0.0556`):
$$S(x_i) = S_0 + (S_{\max} - S_0) \cdot \cos\!\left(\frac{\pi}{2}\,\frac{|x_i - x_p|}{R}\right), \qquad |x_i - x_p| \le R$$
where neighborhood half-width $R = 3.0 \cdot P_0$ (~`3` icon slots on each side of the cursor). Total Dock pill width expands symmetrically around cursor center by the sum $\sum_i (S(x_i) - S_0)$ keeping adjacent margins invariant.

### 3.3 Reduced Motion Mode (`reducedMotion`)

Note: live crossfade frame timing was not captured via video recording while toggling System Settings Accessibility UI; the behavioral contract below defines the normative fallback specification:
- Replace **all** spatial scaling, genie mesh warps, spring bounces, sheet drops, horizontal Space slides, and Mission Control zoom animations with **pure opacity cross-dissolves** (`150–200 ms`, `cubic-bezier(0.25, 0.1, 0.25, 1.0)`).
- Suppress Dock Launch Bounce (use steady/pulsing active indicator dot fade only) and suppress Dock hover magnification expansion unless explicitly kept as static zoom.
- Spaces switch performs a `180 ms` desktop crossfade without horizontal translation.

---

## 4. Component & Shell Layouts

Measurements below derive from a `1800 x 1169 pt` Retina display (`notch` safe zone center-top).

### 4.1 Menu Bar (Top Shell Panel)

- **Height:** `39 pt` on notched displays (matches display safe area above notch), `28 pt` on standard un-notched monitors.
- **Backdrop:** Full-width adaptive Liquid Glass overlay (text switches cleanly light/dark per wallpaper luminance via translucent gradient backing / dark-light sampling; **no opaque pill bar across empty center**).
- **Left Cluster (x-aligned, baseline centered vertically in bar):**
  1. **System Brand Button:** `conjunction-mark.svg` (`16 x 16 pt` inside `34 x 28 pt` hover capsule), inset `10–14 pt` from screen left.
  2. **Active App Menu:** `13 pt` Bold (`Inter`, `600/700`), `16–18 pt` horizontal padding inside hover pill (`cr = 6 pt`).
  3. **Application Menu Items (`File`, `Edit`, `View`, ...):** `13 pt` Regular (`Inter`, `400`), `10–12 pt` horizontal padding around labels, `0 pt` gap between hover capsules, `8–12 pt` visual label spacing. Automatically stops at center notch left margin.
- **Right Cluster (right-to-left):**
  - Clock & Date (`Thu 26 Nov 22:00`, `13 pt` Regular `tnum`, `~110 pt` width), `16 pt` right screen padding.
  - Control Center toggle icon (`30–34 pt` slot width, centered icon `~16 pt`), Quick Search icon (`~32 pt` pitch), Voice Assistant, Input Source (`ABC`), Battery/Wi-Fi/Status tray items spaced on `31–38 pt` centers.
  - Clicking **Clock** opens **Notification Center**; clicking **Control Center** opens **Control Center**; clicking **Search** opens **Quick Search**.

### 4.2 Dock

- **Position & Margins:** Bottom-centered horizontal capsule (`bottomMargin = 5.5 pt` from bottom edge of display; vertical autohide hide offset places top edge just below screen bottom).
- **Geometry (Default `tilesize = 105 pt` example; scales proportionally with `tilesize ∈ [16, 128]`):**
  - Unmagnified icon bitmap: `tilesize x tilesize` (`105 x 105 pt`, squircle mask `22.37%` corner radius).
  - Container pill height: `tilesize + 3.5..14 pt` (measured `108.5 pt` total capsule height at `tilesize = 105`; vertical top padding `6 pt`, bottom padding `7 pt` accommodating active indicator dot).
  - Item slot pitch: `tilesize + 4 pt` (`109 pt` @ `105 pt` tile; `~52 pt` @ `48 pt` tile).
  - **Divider:** `1 pt` centered vertical rule (`35%` label opacity, `0.62 * tilesize` tall) centered inside a `23–49 pt` spacer slot separating pinned/running Apps on left from Minimized Windows + **Trash** on right.
  - **Active App Dot:** `4 x 4 pt` solid circular dot (`labelColor` @ `85%`) centered `3 pt` below app icon bottom edge (`y_dot = dockBottom - 4 pt`).
  - **Hovered Label Tooltip:** Floating glass capsule centered above hovered icon (`gap = 12 pt` above magnified icon top edge, height `26 pt`, radius `13 pt`, `13 pt` Medium label + floating pill style).

### 4.3 Control Center

- **Anchor & Placement:** Top-right floating layout directly below Menu Bar (`top = barH + 8 pt = 47 pt`, `rightMargin = 14.5 pt`, shadow-padded strip `~330–440 pt`). Does **not** wrap all tiles inside a single big panel box — every module is an **independent Liquid Glass surface** floating directly over wallpaper inside a `4 x N` coordinate grid:
  - **Base Grid Unit:** **`64 pt`** square module with **`12 pt`** horizontal & vertical gutter.
  - **Grid Sizes:**
    - `1x1` Circle/Square: `64 x 64 pt`, `cr = 32 pt` (Stage Manager, Display Mirroring, Dark Mode, Keyboard Brightness circles).
    - `2x1` Stadium Pill: `140 x 64 pt`, `cr = 32 pt` (`2*64 + 12 = 140 pt`: Wi-Fi, Bluetooth, Nearby Share, Focus; leading `36 pt` circular status glyph badge inset `14 pt` from left -> `#0088FF` filled when active, neutral glass circle when off; `13 pt` Bold title + `11 pt` status subtitle).
    - `2x2` Rich Module: `140 x 140 pt`, `cr = 24 pt` (Now Playing / Media card: `44 x 44 pt` artwork squircle `cr = 10`, title/artist, prev/play/next media buttons).
    - `4x1` Full-Row Slider Capsule: `292 x 64 pt`, `cr = 32 pt` (`4*64 + 3*12 = 292 pt`: Display Brightness, Sound Volume; `13 pt` SemiBold label at top-left, continuous `6 pt` height rounded track inside `20 pt` hit target + `20 x 20 pt` circular thumb and trailing circular Audio Output button `36 pt`).
  - **Footer Pill:** Centered `"Edit Controls"` glass capsule (`~110 x 28 pt`, `cr = 14 pt`).

### 4.4 Notification Center & Desktop Widgets

- **Panel Anchor:** Slides in horizontally to `right = screenW - 16 pt` (`top = barH + 8 pt`, vertical card spacing `12–16 pt`).
- **Card Width:** **`344 pt`** uniform column width (matching `2 x 164 pt` medium/small square widget grid + `16 pt` gutter, `cr = 20–24 pt` Liquid Glass cards).
- **Stacked Notifications:** Grouped notification cards collapse when `> 1` from same source, showing count chip + top card at `cr = 20 pt` and offset rear stack card (`-6 pt` inset, `-4 pt` drop peek). Hover reveals leading `20 pt` circular `x` clear/collapse button.
- **Footer:** Centered `"Edit Widgets"` pill (`h = 28 pt`) + dismiss circle (`28 x 28 pt`) at bottom of scroll area.

### 4.5 Quick Search & App Launcher

- **Quick Search (`Cmd+Space` or Menu Bar Search):**
  - Vertically centered in upper third (`top ~ 280–340 pt` on `1169 pt` height; centered horizontally at `screenW / 2`).
  - **Compact Bar State:** **`357 x 65.5 pt`** Liquid Glass search capsule (`cr = 32.75 pt`, `24 pt` search glyph, `22 pt` `Inter Display` input text) paired horizontally (`10–12 pt` gap) with **4 circular Quick Action glass buttons** (`63.5–64 pt` circles: Applications `Cmd+1`, Files `Cmd+2`, Actions `Cmd+3`, Clipboard `Cmd+4`), total bar envelope **`641 x 65.5 pt`**.
  - **Expanded Results:** Grows downward into `~680 x 430 pt` (`cr = 24 pt`) two-pane or sectioned Liquid Glass list (`Top Hit`, `Applications`, `Documents`, `Settings`) + right-hand Quick Look preview (`180–260 pt`).
- **App Launcher:**
  - Floating Liquid Glass sheet centered at `(478, 297)` on `1800x1169`: **`844 x 584 pt`** (`cr = 26 pt`), hosting integrated top pill SearchField (`w ~ 340 pt, h = 36 pt`), category/recents filter strip, and scrollable multi-column grid of app squircles (`64–72 pt` icons + `12 pt` single-line truncated centered labels). Escape or clicking backdrop dismisses immediately.

### 4.6 Window Chrome & Titlebar Styles (`ToolbarStyle`)

| Style Variant | Header Height (`pt`) | Traffic Light Position `(x, y)` Center | TL Circle Diameter & Pitch | Title Alignment & Notes |
|---|---|---|---|---|
| **Standard Unified (`automatic` / `unified`)** | `52–54` | `(26, 26)` (sidebar/large) or `(20, 20)` | `14 pt` circle, `23 pt` pitch (`x = 26, 49, 72`) | Center or left beside Back/Forward pill (`36 pt` toolbar pills) |
| **Compact Unified (`unifiedCompact`)** | `38` | `(19, 19)` | `12–14 pt` circle, `20–23 pt` pitch | Tight toolbar (`25–28 pt` segmented pills) |
| **Expanded (`expanded`)** | `44` top + `36` bottom row | `(20, 22)` | `14 pt` circle, `23 pt` pitch | Title above separate full-width toolbar row |
| **Preference (`preference`)** | `80` | `(20, 20)` | `14 pt` circle, `23 pt` pitch | Centered icon-tab buttons (`36–44 pt` pitch) |
| **Plain / No Toolbar** | `28` | `(20, 14)` | `12 pt` circle, `20 pt` pitch (`x = 14, 34, 54`) | Classic centered `13 pt` Bold window title |

**Traffic Light States (Measured Hover & Active Captures):**
- **Active Unhovered:** Solid `14 pt` (`7 pt` radius) saturated circles with delicate inner top-arc specular sheen:
  - Close: `#E2685B` (`sRGB (226, 104, 91)` center; `#F5C5BA` top highlight)
  - Minimize: `#F4C32C` (`sRGB (244, 195, 44)` center; `#FFFF7D` top highlight)
  - Fullscreen/Zoom: `#62BD2E` (`sRGB (98, 189, 46)` center; `#B7F697` top highlight)
- **Group Hover (`mouseEntered` anywhere in 3-button hit bounding box):** **All 3 dots simultaneously display dark high-contrast glyphs:**
  - Close: crisp diagonal `×` (`black@0.55` dark crimson overlay over circle)
  - Minimize: horizontal minus `−` (`black@0.55` dark amber overlay over circle)
  - Zoom: **two opposing right-triangles** aligned along TL-BR diagonal (`#005500` dark green measured fill), or `+` when `Alt` key is held for Maximize/Fill instead of Fullscreen.
- **Pressed:** Darkens circle fill `~20%`.
- **Unfocused / Inactive Window:** All 3 circles desaturate to neutral mid-gray (`#4D4D4F` Dark / `#DCDCDC` Light @ `50%` alpha), restoring saturated hues immediately on hover even while unfocused.

### 4.7 Files Window Architecture

Clean window anatomy (`1000 x 688 pt` reference capture):
- **Left Sidebar (`216 pt` default width, min `140`, max `360`):**
  - Full-height Liquid Glass backing (`Regular` material) extending smoothly to top-left and bottom-left `16 pt` outer window corners, separated from content pane by `1 pt` divider.
  - Traffic lights inset at top-left (`26, 26 pt` centers, `14 pt` dia, `23 pt` pitch).
  - Sections (`Favorites`, `Locations`, `Tags`) with `11 pt` Bold (`secondaryLabelColor`) headers; rows `30 pt` height (`10 pt` inset left/right -> `196 pt` pill, `cr = 10 pt`), leading `16 pt` accent/colored icon, active selected row shaded `rgba(255,255,255,0.12)` Dark / `rgba(0,0,0,0.08)` Light when unfocused, `systemBlue` fill when keyboard-focused.
  - Mounted volumes under `Locations` render a right-aligned **`16 pt` circular Eject (`⏏`) button** (`margin-right = 8 pt`).
- **Floating Toolbar (`54 pt` height over `ScrollPocket` fade):**
  - Top-left: `Back / Forward` connected capsule (`73 x 36 pt`, `cr = 18 pt`, centered vertical hairline divider).
  - Current Folder Title (`15 pt` SemiBold, `12 pt` right of Back/Forward pill).
  - Right tool cluster (`8–12 pt` gaps): `View` dropdown capsule (`45–50 x 36 pt`), `Path` dropdown (`49.5 x 36 pt`), `Add Tags` (`36 x 36` circle), `Delete` (`36 x 36`), `Action …` (`36 x 36`), `New Folder` (`36 x 36`), `Eject` (`36 x 36`), Overflow `»` (`36 x 36`), `Search` (`36 x 36`, expands rightward into pill SearchField on click/`Cmd+F`), with centered `10 pt` sub-labels (`secondaryLabelColor`) directly under icons when icon+text mode is enabled (`Icon Only` collapses toolbar to `44 pt`).
- **Four Content Views:**
  1. **Icon View (`Cmd+1`):** Grid spacing `54 pt` default (`gridSize = 64 x 64 pt` icon default, slider range `16–512 pt`), `12 pt` label below icon (`2`-line wrap), `selectedContentBackgroundColor` tight rounded badge (`cr = 5 pt`) behind selected filename + subtle `cr = 10 pt` halo around selected icon thumbnail.
  2. **List View (`Cmd+2`):** Alternating subtle zebra rows (`24 pt` row height, `16 pt` icon, expandable folder disclosure chevron `›`), sortable column header bar (`28 pt` height, `Name | Date Modified | Date Created | Size | Kind`), full-row rounded pill selection (`inset 8 pt`, `cr = 8 pt`).
  3. **Column View (`Cmd+3`):** Horizontal Miller columns (`220 pt` default width per column, draggable `4 px` hit resize grip at column bottom handle & `1 pt` full-height divider), `24 pt` rows (`16 pt` icon + right triangle `›` for directories), final terminal column renders **Preview Inspector** (`thumb <= 200 pt`, filename, Kind/Size, `Information` metadata table, `Show More`, quick actions).
  4. **Gallery View (`Cmd+4`):** Large centered media stage above a bottom horizontal thumbnail filmstrip (`56 pt` height, `48 pt` square thumbs, `8 pt` spacing) + permanent right-hand `260 pt` **Inspector Pane** (Metadata rows + bottom quick action circle row: `Rotate Left`, `Markup`, `More...`).
- **Optional Chrome Bars:**
  - **Path Bar (`Cmd+Opt+P`, `28 pt` height above Status Bar):** Scrollable horizontal breadcrumb `Volume > Folder > File` with `16 pt` miniature file icons (`12 pt` label, double-click navigates).
  - **Status Bar (`Cmd+/`, `28 pt` bottom strip):** Centered `11 pt` `tnum` count (`"1 of 113 selected, 15.97 GB available"`) + right-aligned `Icon Size` slider (`90 pt` wide) when in Icon View.

### 4.8 System Settings Window

- **Dimensions:** Default **`740 x 625 pt`** (fixed/constrained minimum width `~740 pt`, vertically resizable), `16 pt` continuous outer corners.
- **Sidebar (`232 pt` wide, full-height Liquid Glass):**
  - Top SearchField pill (`212 x 32 pt`, `cr = 16 pt` or `8 pt`, centered magnifier + `"Search"`, `10 pt` margin below traffic lights at `(26, 26 pt)`).
  - Account profile banner row + optional notification badge pill (`#FF3B30` red circle `18 pt` with white `tnum` numeral `"1"`).
  - Grouped sections separated by `1 pt` dividers / `12 pt` gaps:
    1. Connectivity (`Wi-Fi`, `Bluetooth`, `Network`, `VPN`, `Battery`)
    2. Core (`General`, `Accessibility`, `Appearance`, `Desktop & Dock`, `Displays`, `Menu Bar`, `Search`, `Wallpaper`, `Notifications`, `Sound`, `Focus`, `Usage & Limits`)
    3. Security & Privacy (`Lock Screen`, `Privacy & Security`, `Biometrics & Password`, `Users & Accounts`, `Online Accounts`, `Credentials & Keys`)
    4. Input & Media (`Keyboard`, `Trackpad`, `Mouse`, `Printers & Scanners`)
  - Row height `32–34 pt`, leading `22 x 22 pt` colorful squircle badge (`cr = 6 pt`, icon inset `14 pt`), active pill `212 pt` wide in `#0067F4` (`systemBlue`) with crisp white text (`cr = 10 pt`).
- **Detail Pane (`508 pt` wide):**
  - `52 pt` header with `Back/Forward` glass pill (`64 x 32 pt`) at top-left + active pane title.
  - Hero summary card (`~146 pt` tall, `cr = 14 pt`, `48 x 48 pt` centered icon, `20–22 pt` Bold title, `13 pt` muted subtitle).
  - Grouped preference cards (`cr = 12 pt`, `fill = controlFill`, `10 pt` vertical gap between groups, internal row height `44–48 pt` separated by `1 pt` hairline inset `16 pt` from left/right, `16 pt` horizontal padding, trailing chevron `›` for sub-pages or right-aligned `Switch`/`PopUp`/`Slider`).

---

## 5. Interaction Model

### 5.1 Essential System & Window Keyboard Shortcuts

Use `Meta` (`Super` / Command-mapped modifier) where `Cmd` denotes Conjunction Primary Command (`Super` or remapped primary modifier) and `Ctrl` denotes Control:

| Action | Binding | Scope & Behavior |
|---|---|---|
| **Quick Search** | `Cmd + Space` | Toggles Quick Search capsule; `Escape` closes (or clears non-empty input first) |
| **App Switcher HUD** | `Cmd + Tab` / `Cmd + Shift + Tab` | Holds center glass row of running apps sorted by MRU; `Q` quits highlighted app, `H` hides |
| **Cycle Windows of Same App** | `Cmd + Backtick` (``Cmd+` ``) | Cycles non-minimized windows on active Workspace |
| **Close Window / Quit App** | `Cmd + W` / `Cmd + Q` | Closes active document window (`167 ms`); quits application completely |
| **Minimize Window** | `Cmd + M` | Triggers Genie/Scale minimize into Dock |
| **New Window / Tab** | `Cmd + N` / `Cmd + T` | Launches new window (`230–250 ms`) or tab |
| **Force Quit Picker** | `Cmd + Opt + Esc` | Opens compact modal process force-quit sheet |
| **Spaces Switch Left / Right** | `Ctrl + Left` / `Ctrl + Right` | Horizontal Spring Slide between Virtual Desktops (`1..N`) |
| **Jump to Space `N`** | `Ctrl + 1..9` | Direct switch to Workspace `N` |
| **Mission Control / Overview** | `Ctrl + Up` (or `F3`) | Enters/exits overview (`525 ms`) showing Spaces Bar + non-overlapping window spread |
| **Application Windows Expose** | `Ctrl + Down` | Exposes all windows of focused app |
| **Files View Modes** | `Cmd + 1` / `2` / `3` / `4` | Icon / List / Column / Gallery view immediately |
| **Files Path Bar / Status Bar** | `Cmd + Opt + P` / `Cmd + /` | Toggles `28 pt` bottom Path Bar / Status Bar |
| **Files Hidden Files** | `Cmd + Shift + .` | Toggles dotfile visibility live in current file pane |
| **Files Quick Look Preview** | `Space` | Instant spring zoom preview overlay for highlighted file/folder without launching host app; arrow keys advance selection live |
| **Files Get Info / Trash / Eject** | `Cmd + I` / `Cmd + Backspace` / `Cmd + E` | Opens floating Info inspector / moves to Trash (or Ejects volume if selected item is removable/disk image) / Ejects mounted volume |
| **Screenshot Toolbar** | `Cmd + Shift + 3/4/5` | Fullscreen / crosshair area+window / recording HUD |

### 5.2 Multi-Touch Trackpad Gestures (Default `libinput` / KWin Parity)

Matches verified default multi-touch trackpad configuration:
- **Tap to Click (`1`-finger):** Enabled by default; **Two-finger tap/click:** Secondary context menu.
- **Natural Inertial Scroll:** Two-finger vertical/horizontal with elastic boundary overscroll rubber-banding.
- **3- or 4-Finger Horizontal Swipe:** Continuous `1:1` finger-tracked Spaces / Fullscreen switch (`Ctrl+Left/Right` snap threshold > `30%` velocity or displacement).
- **3- or 4-Finger Swipe Up:** Interactive Mission Control (`525 ms` full commit).
- **3- or 4-Finger Swipe Down:** Active Application Windows Exposé.
- **Thumb + 3-Finger Pinch-In:** Opens **App Launcher** grid.
- **Thumb + 3-Finger Spread-Out:** Reveals Desktop (pushes all windows off-screen radially).
- **2-Finger Swipe from Right Edge:** Slides in **Notification Center** (`344 pt` widget & notification stack).

### 5.3 Hot Corners (Corner Action Map)

Supported corner actions assignable to `Top-Left`, `Top-Right`, `Bottom-Left`, `Bottom-Right` with optional modifier guard (`0` none, bitmask `Shift/Ctrl/Alt/Cmd`), default bottom-right = **Quick Note (`14`)** or customizable:

| Code | Action | Default Assignment (`Conjunction`) |
|---|---|---|
| `0` / `1` | Disabled (`None`) | `TL=0, TR=0, BL=0` |
| `2` | Mission Control | Optional |
| `3` | Application Windows | Optional |
| `4` | Show Desktop | Optional |
| `5` | Start Screen Saver | Optional |
| `6` | Disable Screen Saver | Optional |
| `10` | Put Display to Sleep | Optional |
| `11` | App Grid Launcher | Optional |
| `12` | Notification Center | Optional |
| `13` | Lock Screen | Optional |
| `14` | Quick Note (Corner trigger) | `BR=14` |

### 5.4 Application Bundle UX & Drag-to-Install Flow

- **Opaque Package Appearance:** Directories ending in `.app` (`.AppDir` on Conjunction) containing a valid manifest (`Contents/Info.plist` or `.desktop`/manifest inside bundle root) are presented in Files, Quick Search, Open/Save dialogs, and Desktop as **atomic single-file application icons** (never showing an expandable disclosure chevron in List View unless inside `Contents`).
- **Primary Activation (`Double-Click` / `Cmd+O` / Enter):** Executes the app's binary/entrypoint cleanly rather than navigating into the directory.
- **Show Package Contents:** Right-click context menu (or Toolbar `Action …` menu) exposes **`Show Package Contents`** strictly when a `.app` package is selected; invoking it opens the bundle root (`Contents/`) in the Files window showing `Info.plist`, `MacOS/` (executable), `Resources/`, `PlugIns/`, etc.
- **Drag-to-Applications Installation:** Dragging an `.app` from Downloads or a mounted Disk Image onto the `/Applications` alias/folder moves or copies the bundle cleanly (showing translucent drag badge + green `+` copy badge across filesystems, replacing existing matching bundle after modal Replace/Keep Both confirmation sheet) and triggers immediate background registration (`conj-appd` / XDG `.desktop` cache update) so it appears instantly in Quick Search and App Launcher.

### 5.5 Disk Image (`.dmg` / `.cdmg`) Lifecycle

1. **Double-Click / Open Image:** Displays compact verification/mount progress sheet -> mounts image read-only (loopback squashfs/EROFS/APFS container via `udisks2` / `conjunction-core/src/cdmg.rs`) under `/run/media/<user>/<VolName>` or `/Volumes/<VolName>`.
2. **Mounted Appearance:** Immediately reveals mounted volume in **Files Sidebar -> Locations** (with trailing `16 pt` circular `⏏` Eject button) and optional Desktop disk icon, and auto-opens the volume window (commonly framed with background art + `.app` -> `Applications` symlink alias for drag-install).
3. **Eject Flows (All Equivalent):**
   - Click `⏏` icon beside volume in Files Sidebar or Toolbar `Eject` button (`36 pt` circle).
   - Select volume -> press `Cmd + E` or right-click `Eject "<VolumeName>"`.
   - Drag mounted disk icon toward **Dock Trash** (Trash icon morphs dynamically into an `⏏` Eject badge during drag!).
   - Cleanly flushes buffers, unmounts filesystem, tears down loopback block device (`udisksctl unmount` + `loop-delete`), removes sidebar entry, and leaves original `.dmg`/`.cdmg` archive untouched on disk.

---

## 6. Mapping onto KDE Plasma 6 / KWin / Qt Quick

| Spec Component | Architectural Role | Conjunction / KDE Plasma 6 Implementation |
|---|---|---|
| **Liquid Glass Shader Engine** | Compositor SDF Backdrop + Refraction + Tone Matrix + Rim | C++ KWin plugin subclassing **`KWin::OffscreenEffect`** + **`KWin::GLShader`** (GLSL 330 core shader in Section 1.6), sampling KWin's background blur pass (`BlurEffect` / cached downsampled FBO) using `QRectF` fractional-DPI geometries (`EffectWindow` properties specify `variant`, `cornerRadius`, `tintColor`, `scrollPocket`, `morphSpacing`). |
| **QML App Surfaces & Scroll Pockets** | Frosted Glass View & Scroll-Edge Pocket | Reusable QtQuick component `GlassSurface.qml` backed by `ShaderEffectSource` + `QtQuick.Effects.MultiEffect` (for QML-internal blur) + custom `ShaderEffect` implementing Section 1.1–1.3 (`ScrollPocket` applies linear alpha gradient mask at `y = 0..54 pt` switching between soft fade and `0.5 pt` hairline on `contentY > 0`). |
| **Window Chrome, Traffic Lights & Shadows** | Unified Titlebar, Toolbar & Drop Shadows | **`KDecoration3::Decoration`** C++ plugin (native `QRectF` / `QMarginsF` HiDPI scaling) rendering `16 pt` continuous clip, `DecorationButton` custom 3-button cluster at `(26,26)` or `(20,19)` (`14 pt`, `23 pt` pitch, simultaneous group hover icons `× − ⤢`), `DecorationShadow` calibrated to Section 2.5 falloff (`74 pt` bottom padding), and integrated `KWindowEffects::enableBlurBehind` + custom X11/Wayland property for sidebar glass transparency. |
| **Desktop Window Bridge & HUDs** | Window Server, Menu Bar, Dock & Overlays | Existing `data/conjunction-kwin-bridge.js` (`workspace.windowAdded/Removed/Activated` over D-Bus `org.conjunction.Shell`) paired with Plasma 6 Wayland layer-shell QML processes (`layer-shell-qt` for `Top` 39pt Menu Bar w/ global AppMenu D-Bus `com.canonical.AppMenu.Registrar`, `Bottom` floating Dock w/ `cos` bell magnification + `Minimize/Unminimize` KWin `MagicLamp`/`Scale` script, right-anchored `Control Center` & `Notification Center` via `conj-notificationd`, centered `Quick Search` / `App Launcher` overlay). |
| **Typography & Symbol Pipeline** | System UI / Mono / Symbol Fonts | `Inter` + `Inter Display` (`font.opticalSizing: Font.PreferOpticalSizing` / explicit cutoff at `20 pt`) + `JetBrains Mono` bundled via `/usr/share/fonts/conjunction/` and `fontconfig` aliases. `Material Symbols Rounded` variable TTF loaded via Qt `FontLoader` + QML helper binding `font.variableAxes: ({ "FILL": fill, "wght": weight, "GRAD": grade, "opsz": opsz })`, falling back to `Phosphor` SVGs for unmatched icons. |
| **Controls & GTK Apps** | Native Control Sizing & Glass Bezels | Custom `QtQuick.Controls` (`Conjunction.Controls`) style implementing exact Section 2.3 sizing (`16/27/32/40 pt`), continuous squircle clipping, `3.5 pt` outer focus ring (`activeFocusReason === Qt.TabFocusReason \|\| Qt.BacktabFocusReason`), plus **`MacTahoe GTK`** theme CSS tokens mapped 1:1 to Section 2.8 (`gtk-3.0`/`gtk-4.0`) + `xdg-desktop-portal-kde` dark/light & high-contrast signals. |
| **Bundles (`.app`) & Disk Images (`.cdmg`)** | Bundle Metadata & Loopback Disk Mount | `conjunction-core/src/bundle.rs` + `cdmg.rs` + `conj-appd` daemon: registers `.app`/`.AppDir` directory metadata cleanly (`inode`/manifest check avoids expanding `.app` as directory in `conjunction-files`), exposes `"Show Package Contents"` context action, and mounts `.cdmg`/`.dmg` read-only images via `UDisks2` loop device with real-time sidebar `⏏` eject & Trash-target eject morphing. |
| **Accessibility State Sync** | Live Accessibility Theme & Motion Sync | D-Bus listener on `org.freedesktop.portal.Desktop` (`org.freedesktop.appearance`: `color-scheme`, `contrast`, `reduced-motion`) + KConfig `kwinrc` updates uniforms (`u_reduceTransparency`, `u_highContrast`) and toggles global `150–200 ms` crossfade animation curve immediately without restart. |

---

## 7. Quantitative Acceptance Checklist

Every shipping build MUST pass automated visual, compositor, motion, and clean-room checks within the stated tolerances:

| Check Category | Target Requirement | Numeric Pass Criterion / Tolerance |
|---|---|---|
| **Shader Space & Face Transfer** | Color matrix & `FaceFill` run in sRGB; `MaxLumaSDR` clamps *before* matrix | `0` (`0.5`, `1.0`) ramp outputs match Table 1.2 within `<= ±0.015` sRGB (e.g., Dark Reg White $m \ge 104$ `= 0.447 ± 0.015`) |
| **Blur Radius $\sigma$** | Clear scale curve `5..10 * 2 pt`; Regular effective blur w/ BlurFill | Measured ERF step-edge fit $\sigma = 20.0 \pm 1.5\text{ pt}$ (Clear $m \ge 120$), `14.0 ± 1.5 pt` (Regular Light), `10.5 ± 1.5 pt` (Regular Dark) |
| **Edge Refraction $\Delta r(d)$** | Exponential inward normal distortion along glass boundary | $\Delta r(0) = 45.2 \pm 3.0\text{ pt}$ (Clear), `31.5 ± 3.0 pt` (Regular), decay constant $6.8 \pm 1.0\text{ pt}$, `0 pt` past `24 pt` |
| **Tint & Specular Rim** | Regular enforces monochrome tint; Clear keeps hue; `90°` top/bottom rim present | Chroma retention under Regular tint `< 0.03`; Top-rim luminance delta `+0.04..+0.08` Dark / subtle white rim Light (`<= 1.5 pt` width) |
| **Morphing Neck Bridge** | Two `56 pt` circles (`spacing = 24 pt`) fuse smoothly when gap `< 20 pt` | Vertical bridge height: `34.0 ± 2.0 pt` (`gap=0`), `30.5 ± 2.0 pt` (`gap=4`), `15.0 ± 2.0 pt` (`gap=10`), `<= 1.0 pt` (`gap>=20`) |
| **Corners & Concentricity** | Continuous superellipse; inner radius obeys $R_{\text{out}} - \text{pad}$ | Window outer `16.0 ± 0.5 pt` (`24 pt` tangent start); zero corners with circular hard kinks or protruding nested pills |
| **Control Sizing** | Controls match Table 2.3 vertical & horizontal dimensions | All `.mini`..`.extraLarge` heights exact within `±0.5 pt` (`Push reg = 32 pt`, `Switch = 42x25 pt`, `Toolbar circle = 36 pt`) |
| **Typography & Substitutes** | `Inter` (`<20 pt`), `Inter Display` (`>=20 pt`), `JetBrains Mono`, `Material Symbols Rounded` + `Phosphor` | Cap-height optical scale error `<= 1.5%`; tracking error `<= ±0.0005 em`; tabular digits enabled in status/date/clock |
| **Focus Ring & Contrast** | Keyboard navigation reveals `3.5 pt` outer halo (`#0067F4`/`#1AA9FF` @ `50%`); pointer clicks on buttons do not | Halo thickness `3.5 ± 0.25 pt`; `Increased Contrast` switches dividers to `65%` and adds `1 pt` borders; `Reduce Transparency` sets `0` backdrop distortion |
| **Shadows & Dark Clamping** | Multi-tier shadow matches active/inactive window curve | Active bottom contact alpha `0.34 ± 0.03`, tail reaches `0` cleanly by `30–74 pt` pad; inactive shadow `0.50–0.55x` active |
| **Motion Durations & Curves** | All Table 3.1 animations hit target windows & curves | Open `230–250 ms`, Close `167 ± 20 ms`, Scale Min `203 ± 20 ms`, Genie Min `400–450 ms`, Dock Slide `290–305 ± 25 ms`, Dock Bounce `~680 ms` period, CC `145–155 ms` open, Popover `150–160 ms`, MC `490–525 ± 35 ms`, Reduce Motion uses crossfade only |
| **Dock Magnification** | Cosine bell spread across `R = 3.0 * slotPitch` | Magnified center height `== largesize ± 1 pt`, neighbor curve `RMSE <= 0.03` vs cosine bell, enter `208 ± 25 ms` |
| **Shell Layouts** | Menu Bar `39/28 pt`, Control Center `64 pt` tiles (`12 pt` gap), Notification Center `344 pt` (`16 pt` gap), Quick Search `357+4x64 pt`, Files `216 pt` sidebar & `28 pt` Path/Status bars, Settings `740x625` (`232 pt` sidebar, `48 pt` cards) | Positional accuracy `<= ±1.5 pt` across all fixed shell chrome regions at `100%`, `150%`, and `200%` display scales |
| **Interactions & Bundles** | Hotkeys, trackpad swipes, hot corners, drag-to-`/Applications`, `Show Package Contents`, `.dmg/.cdmg` mount & eject all functional | `.app` folders appear as single items and launch on double-click; `Show Package Contents` opens `Contents/`; mounted `.dmg/.cdmg` shows Sidebar `⏏` and unmounts cleanly on `Cmd+E` / `⏏` / Trash drag |
| **Clean-Room Compliance** | Zero proprietary vendor binaries, fonts, artwork, paths, or trademarks | `grep` audit confirms zero occurrences of proprietary font names, system icon paths, extracted assets, or uncredited vendor logos; `ASSETS.md` open replacements used everywhere |
