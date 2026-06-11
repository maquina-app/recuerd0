---
target: app/views/home (marketing landing)
total_score: 31
p0_count: 0
p1_count: 3
timestamp: 2026-06-11T17-00-42Z
slug: app-views-home-landing-html-erb
---
# Critique: app/views/home/_landing.html.erb (marketing landing)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Static page; code tabs have active states. |
| 2 | Match System / Real World | 4 | Copy is excellent — developer-native, honest, on-voice. |
| 3 | User Control and Freedom | 3 | Standard links; external rel=noopener. |
| 4 | Consistency and Standards | 2 | Three different greens; Jura weight diverges from DESIGN.md. |
| 5 | Error Prevention | 3 | No forms on this surface. |
| 6 | Recognition Rather Than Recall | 3 | Clear labels, anchor nav, no icon-only nav. |
| 7 | Flexibility and Efficiency | 3 | Anchor nav; authenticated users get "Go to App". |
| 8 | Aesthetic and Minimalist Design | 3 | Per-section eyebrows + 7-card grid + inline-style clutter. |
| 9 | Error Recovery | 3 | n/a (static). |
| 10 | Help and Documentation | 4 | Strong — API/CLI/agent doc links + real code samples. |
| Total | | 31/40 | Good — solid foundation, a few fixable issues |

## Anti-Patterns Verdict
Not generic AI slop at a glance (custom hero memory-layers visual, real code samples, on-voice copy, committed green). One loud exception: tiny uppercase tracked mono eyebrow (.section-label) above every section (problem, how, api, features, cta) — explicitly banned in the project's own DESIGN.md. Detector found 3x overused-font (Geist Mono) — FALSE POSITIVES (committed brand identity). Detector missed the eyebrow (class-driven). No browser overlay this run (no automation/dev server); source + CLI only.

## Priority Issues
- [P1] Per-section eyebrow labels (.section-label) — AI-grammar tell + violates own DESIGN.md ban. Fix: drop repeated label, let Jura titles carry sections. Cmd: /impeccable typeset or /impeccable quieter.
- [P1] All content below hero ships blank without JS — .reveal { opacity:0 } gated on .visible class from marketing-reveal controller. Breaks on JS failure, background tabs, headless/crawler/AI renderers. Fix: default visible, treat reveal as enhancement. Cmd: /impeccable animate or /impeccable harden.
- [P1] Zero prefers-reduced-motion (none in marketing.css or application.css) + contrast below AAA target. --m-text-dim oklch(0.550 0.015 150) on #f8f9f8 ~4:1 used on small text. Fix: reduced-motion fallbacks; darken dim/secondary text. Cmd: /impeccable audit.
- [P2] Coarse responsive — single @media (max-width:900px) in 1555 lines; hero-visual display:none on mobile removes signature brand image; code tabs shrink to 0.62rem. Fix: add small-phone breakpoint, keep scaled hero visual. Cmd: /impeccable adapt.
- [P2] Three divergent greens — meta #009D39, marketing --m-primary oklch(0.480 0.190 150), DESIGN.md Memory Green oklch(0.600 0.190 150). Fix: pick canonical, align or document variant. Cmd: /impeccable colorize.

## Persona Red Flags
- Riley (Stress Tester): JS-off / crawler render → everything below hero is opacity:0, blank. Background-tab load may never fire reveal.
- Casey (Mobile): hero visual display:none on phones (loses brand image); one coarse breakpoint; 0.62rem code tabs.
- Privacy-Conscious Senior Engineer (project persona): self-host messaging lands, but reduced-motion ignored reads as "didn't sweat the details" on a craft-selling page.

## Minor Observations
- Dead markup: <span style="display:none;">—</span> inside two .section-labels.
- Heavy inline style="" throughout; bypasses token system.
- 7 near-identical feature-cards in 2-col grid.
- m-section-title is Jura 300 vs DESIGN.md's Jura 500 for headings; reconcile.

## Questions to Consider
- Would Jura titles alone carry sections more confidently than eyebrows?
- Should the hero visual shrink on mobile instead of disappearing?
- Is "blank until JavaScript" the opposite of what an AI-crawler audience needs?
