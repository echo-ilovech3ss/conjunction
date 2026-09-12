# Conjunction Design System Foundations

## 1. Purpose & Design Principles

Conjunction adopts modern desktop interaction principles while establishing an independent visual identity for Arch Linux. It is **not** a macOS clone and does not incorporate Apple proprietary assets.

The visual grammar is governed by eleven core principles:
1. **Clarity**: Content precedes chrome. Controls remain understated until interaction is requested.
2. **Hierarchy**: Strong typography and structural surfaces establish natural scanning flow.
3. **Restraint**: Saturated color is reserved strictly for interaction states, selections, and status feedback.
4. **Consistency**: Global semantic tokens govern colors, metrics, and transitions across all Conjunction applications.
5. **High Typography Quality**: Proportional sans-serif letterforms with dedicated monospace roles and dynamic font scaling.
6. **First-Class Focus Behavior**: Clear, unambiguous keyboard focus indicators distinct from mouse hover or selection states.
7. **Predictable Spacing**: Strict alignment against an 8-point base grid ($2, 4, 8, 12, 16, 24, 32$ px).
8. **Subtle Depth**: Clean elevation tiers with low-radius soft boundaries optimized for CPU and GPU rasterization.
9. **Strong Keyboard Usability**: Every interface element is reachable and actionable without pointer input.
10. **High Information Quality**: Clean representation of data without decorative noise.
11. **Low Visual Noise**: Avoid unnecessary container nesting, heavy borders, or gratuitous gradients.

---

## 2. Design Token Architecture

Conjunction interfaces consume design tokens through the `Conjunction.Design` QML module:

```qml
import QtQuick
import Conjunction.Design

Surface {
    elevation: "base"

    Text {
        text: "System Status"
        font: Typography.sectionHeading
        color: Theme.textPrimary
    }
}
```

Components never hardcode raw hex values or pixel metrics directly.

---

## 3. Semantic Color Tokens

### 3.1 Theme Tokens

| Token | Light Theme | Dark Theme | Purpose |
|---|---|---|---|
| `Theme.background` | `#F4F5F8` | `#1A1B20` | Canvas and window root background |
| `Theme.surface` | `#FFFFFF` | `#24262E` | Primary cards and document surfaces |
| `Theme.surfaceElevated` | `#FFFFFF` | `#2D303A` | Popovers, sheets, and dialogs |
| `Theme.surfaceSecondary` | `#EAECEF` | `#1F2026` | Recessed toolbars, sidebars, wells |
| `Theme.textPrimary` | `#15161A` | `#F5F6F8` | High-contrast body text ($>12:1$ WCAG CR) |
| `Theme.textSecondary` | `#5A5D66` | `#9EA2AD` | Secondary metadata and labels ($>4.5:1$ CR) |
| `Theme.textDisabled` | `#9DA0A8` | `#5D6069` | Inactive controls |
| `Theme.separator` | `#D3D6DC` | `#373A44` | Dividing lines and subtle surface borders |
| `Theme.selection` | `#DBEAFE` | `#1E3A5F` | Active item selection highlight |
| `Theme.selectionText` | `#15161A` | `#F5F6F8` | Text within selection highlights |
| `Theme.focusRing` | `#2563EB` | `#60A5FA` | Keyboard focus indicator ring |
| `Theme.destructive` | `#DC2626` | `#EF4444` | Dangerous or destructive actions |
| `Theme.warning` | `#D97706` | `#F59E0B` | Cautionary notices |
| `Theme.success` | `#059669` | `#10B981` | Affirmative completions |

### 3.2 Accent Palette
Applications access the active accent via `Theme.accent`, `Theme.accentHover`, and `Theme.accentPressed`. Available user choices:
* **Blue** (Default): Light `#1D4ED8`, Dark `#2563EB`
* **Teal**: Light `#0D7D6C`, Dark `#1A9988`
* **Amber**: Light `#B45309`, Dark `#D97706`
* **Violet**: Light `#6D28D9`, Dark `#8B5CF6`
* **Graphite**: Light `#4B5563`, Dark `#9CA3AF`

---

## 4. Typography Hierarchy

Fonts are defined in `Typography.qml` and automatically scale via `Appearance.fontScale`:

| Role | Target Size | Weight | Fallback Family | Usage |
|---|---|---|---|---|
| `Typography.display` | 24pt | Bold (700) | Sans-Serif | Splash headers, prominent titles |
| `Typography.windowTitle` | 16pt | Semi-bold (600) | Sans-Serif | Window headers, sheet titles |
| `Typography.sectionHeading`| 13pt | Semi-bold (600) | Sans-Serif | Group headings, card titles |
| `Typography.body` | 11pt | Regular (400) | Sans-Serif | Main paragraph text, reading views |
| `Typography.secondaryBody` | 10pt | Regular (400) | Sans-Serif | Subtitles, footnotes, descriptions |
| `Typography.caption` | 9pt | Regular (400) | Sans-Serif | Metadata, badge labels, timestamps |
| `Typography.controlLabel` | 11pt | Medium (500) | Sans-Serif | Buttons, toggles, menu entries |
| `Typography.monospace` | 10pt | Regular (400) | Monospace | Hashes, IDs, paths, log text |

Redistributable system font stack: `DejaVu Sans`, `Liberation Sans`, `Noto Sans`, and system font defaults.

---

## 5. Spacing & Geometry

### 5.1 Spacing Scale
* `Spacing.none`: `0px`
* `Spacing.xxs`: `2px`
* `Spacing.xs`: `4px`
* `Spacing.sm`: `8px`
* `Spacing.md`: `12px`
* `Spacing.lg`: `16px`
* `Spacing.xl`: `24px`
* `Spacing.xxl`: `32px`

### 5.2 Geometry Tokens
* **Control Heights**:
  * `Geometry.controlHeightSmall`: `24px` (dense lists, tags)
  * `Geometry.controlHeightMedium`: `32px` (standard buttons, fields)
  * `Geometry.controlHeightLarge`: `40px` (primary action controls)
  * `Geometry.minTargetSize`: `32px` (minimum interactive target)
* **Corner Radii**:
  * `Geometry.radiusSmall`: `4px` (tags, small buttons)
  * `Geometry.radiusMedium`: `8px` (cards, controls, surfaces)
  * `Geometry.radiusLarge`: `12px` (dialogs, elevated popovers)
  * `Geometry.radiusPill`: `999px` (circular chips, pill badges)
* **Lines & Focus**:
  * `Geometry.separatorThickness`: `1px`
  * `Geometry.focusRingThickness`: `2px`
  * `Geometry.focusRingOffset`: `2px`
* **Layout Margins**:
  * `Geometry.windowMargin`: `16px`
  * `Geometry.contentPadding`: `12px`

---

## 6. Depth and Shadows

Conjunction avoids heavy Gaussian blurs or complex drop shadow shaders to preserve performance under software rendering and low-power hardware.

* **Base Surface** (`elevation: "base"`): Flat surface bounded by `Theme.separator`.
* **Raised Surface** (`elevation: "raised"`): 1px offset bounding shadow.
* **Popover Surface** (`elevation: "popover"`): 2px offset bounding shadow for floating menus.
* **Dialog Surface** (`elevation: "dialog"`): 4px offset bounding shadow with `radiusLarge`.

---

## 7. Motion & Reduced Motion

Transitions are short, physical, and interruptible:
* `Motion.instant`: `0ms`
* `Motion.fast`: `100ms` (micro-interactions, button hover)
* `Motion.normal`: `200ms` (card expands, popover reveals)
* `Motion.slow`: `350ms` (scene navigations, large window state changes)

### Reduced Motion Accessibility
When `Appearance.reducedMotion` is `true`:
`Motion.duration(base)` collapses immediately to `Motion.instant (0)`. Animated state transitions complete in a single frame without lingering timers or continuous repainting.

---

## 8. Focus & Input Modality

* Keyboard navigation using `Tab` and `Shift-Tab` moves focus sequentially through interactive items.
* Active focus displays the standard `FocusRing` (`Theme.focusRing`, 2px thickness, 2px offset).
* Focus indicators remain fully distinguishable from mouse hover states and item selection backgrounds.

---

## 9. High DPI, Scaling, and RTL

* All metrics are expressed in logical units (`dp` / `pt`). Qt handles fractional device pixel ratios ($100\%, 125\%, 150\%, 200\%$).
* Interfaces support `Qt.RightToLeft` via `Appearance.isRTL` and Qt's `LayoutMirroring` properties. Text alignment and layout columns invert naturally.

---

## 10. Icon Strategy & Asset Licensing

* Icons are looked up through `Icon.qml` and `Icons.qml` using standard semantic identifiers (`settings`, `search`, `check`, `close`, `warning`, `arrow-left`, `arrow-right`, `refresh`, `copy`).
* All included SVG path definitions are redistributable under permissive open-source licenses (Apache 2.0 / MIT / Public Domain).
* **Apple Assets Policy**: Apple fonts (San Francisco, New York), SF Symbols, and macOS artwork are strictly prohibited.
