---
target: app/views/home (marketing landing)
total_score: 33
p0_count: 0
p1_count: 0
timestamp: 2026-06-11T17-41-49Z
slug: app-views-home-landing-html-erb
---
# Critique: app/views/home/_landing.html.erb (marketing landing) — re-run

## Design Health Score: 33/40 (Good, upper band) — up from 31

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Static; tabs expose proper state. |
| 2 | Match System / Real World | 4 | Copy excellent, on-voice. |
| 3 | User Control and Freedom | 3 | Tabs fully keyboard-operable now. |
| 4 | Consistency and Standards | 3 | Eyebrows gone, Jura weight matches DESIGN.md; three greens still diverge. |
| 5 | Error Prevention | 3 | No forms. |
| 6 | Recognition Rather Than Recall | 3 | Clear labels, anchor nav. |
| 7 | Flexibility and Efficiency | 3 | Arrow-key tab nav added. |
| 8 | Aesthetic and Minimalist Design | 4 | Eyebrow scaffolding + dead markup removed. |
| 9 | Error Recovery | 3 | n/a. |
| 10 | Help and Documentation | 4 | Strong doc links + code samples. |
| Total | | 33/40 | Good, approaching ship-it |

## Anti-Patterns Verdict
Passes. Per-section eyebrow tell removed. Detector finds only 3 Geist Mono hits = false positives (committed brand identity). No structural slop. Source + CLI review only (no browser automation).

## What's Working
- Progressive enhancement: .reveal visible by default; no-JS/crawler/headless get full page.
- Accessibility now a strength: AAA muted-text contrast, brand-green focus rings, decorative SVGs aria-hidden, reduced-motion fallbacks that keep hero visible, full WAI-ARIA code tabs.
- Eyebrows gone; Jura-500 titles carry sections; green rarer/more meaningful (One Green Rule).

## Priority Issues (all P2, nothing blocking)
- [P2] Coarse responsive + sub-44px mobile touch targets; hero-visual display:none on mobile. -> /impeccable adapt
- [P2] Three divergent greens (#009D39 / --m-primary 0.48 / DESIGN 0.60); holds Consistency at 3. -> /impeccable colorize
- [P2] Seven near-identical feature cards; remaining visual monotony. -> /impeccable layout

## Persona Red Flags
- Riley (Stress): RESOLVED — JS-off/crawler now renders full page.
- Sam (a11y): largely resolved — focus rings, ARIA tabs, aria-hidden SVGs, AAA contrast.
- Casey (Mobile): weakest journey — loses hero visual on phones, one breakpoint, small tab targets.

## Minor Observations
- pages/pricing.html.erb still has 2 eyebrows.
- Heavy inline style="" bypasses token layer.

## Questions to Consider
- Is marketing --m-primary deliberately darker than app Memory Green for contrast? If so, document it in DESIGN.md.
- What does mobile lose by hiding the memory-layers visual; is a simplified version cheap to keep?
