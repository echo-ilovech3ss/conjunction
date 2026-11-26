# Conjunction asset choices

Conjunction matches the macOS 27 layout, motion and Liquid Glass material through
`SPEC.md`. Artwork and font files are not copied. Each Apple asset is replaced by the
closest open option, or by something new in the same style.

| Role | macOS uses | Conjunction uses | License |
|---|---|---|---|
| UI font | SF Pro Text / Display | **Inter** (text) and **Inter Display** (sizes ≥ 20px), tracking tuned to the values in SPEC.md | OFL-1.1 |
| Monospace | SF Mono | **JetBrains Mono** | OFL-1.1 |
| Symbols | SF Symbols | **Material Symbols Rounded** variable font. Its weight and optical-size axes keep icon weight matched to text weight the way SF Symbols does. Use **Phosphor** to fill gaps. | Apache-2.0 / MIT |
| App and folder icons | Apple icons | **MacTahoe icon theme** (vinceliuice) as the base. Replace any icon that reproduces an Apple app icon or logo (Finder face, Safari compass, Apple logo, etc.) with an original design. | GPL-3.0-or-later (check the LICENSE file before shipping) |
| Conjunction app icons | — | Original. Same canvas and squircle mask from SPEC.md, with layered glass (foreground/background depth) | Project |
| GTK apps | — | **MacTahoe GTK theme**, recoloured to the Conjunction tokens | GPL-3.0 |
| Wallpapers | Apple wallpapers | Original procedural gradients and abstract glass shapes made for Conjunction, in light and dark pairs | Project |
| Cursor | macOS cursor | Original cursor set or **Bibata Modern**. Don't use themes that trace Apple's cursors. | GPL-3.0 |
| System sounds | Apple sounds | **freedesktop/ocean** sound theme, plus original short sounds where needed | CC-BY-SA / project |
| Logo, menu bar "system" menu | Apple logo | The Conjunction mark from `assets/conjunction-mark.svg` | Project |

Rules for anyone working on the rebuild:
- Never import files from `/System`, `/Library` or any Apple app bundle, and never trace or redraw them.
- Inspired-by is fine. Same proportions, mask shapes, material, motion and layout are the goal.
- Record any new third-party asset in this table, with its license.
