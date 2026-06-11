---
name: Recuerd0
description: The knowledge base your AI tools deserve — human-curated, version-controlled context.
colors:
  memory-green: "oklch(0.600 0.190 150)"
  memory-green-foreground: "oklch(1.000 0.000 0)"
  secondary: "oklch(0.940 0.045 150)"
  secondary-foreground: "oklch(0.280 0.055 150)"
  background: "oklch(1.000 0.000 0)"
  foreground: "oklch(0.145 0.000 0)"
  muted: "oklch(0.960 0.008 150)"
  muted-foreground: "oklch(0.460 0.010 150)"
  accent: "oklch(0.940 0.025 150)"
  accent-foreground: "oklch(0.280 0.030 150)"
  border: "oklch(0.900 0.010 150)"
  sidebar: "oklch(0.975 0.006 150)"
  destructive: "oklch(0.580 0.237 28.43)"
  success: "oklch(0.940 0.035 150)"
  warning: "oklch(0.940 0.030 85)"
  info: "oklch(0.940 0.035 230)"
typography:
  display:
    fontFamily: "Jura, system-ui, sans-serif"
    fontSize: "clamp(2.25rem, 4vw, 3.5rem)"
    fontWeight: 500
    lineHeight: 1.05
    letterSpacing: "-0.01em"
  headline:
    fontFamily: "Jura, system-ui, sans-serif"
    fontSize: "1.75rem"
    fontWeight: 500
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  title:
    fontFamily: "Jura, system-ui, sans-serif"
    fontSize: "1.6rem"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "-0.01em"
  body:
    fontFamily: "Instrument Sans, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.6
    letterSpacing: "normal"
  label:
    fontFamily: "Geist Mono, ui-monospace, monospace"
    fontSize: "0.625rem"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "0.15em"
rounded:
  sm: "4px"
  md: "6px"
  lg: "8px"
  xl: "12px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "40px"
components:
  button-primary:
    backgroundColor: "{colors.memory-green}"
    textColor: "{colors.memory-green-foreground}"
    rounded: "{rounded.lg}"
    padding: "8px 16px"
    height: "36px"
  button-primary-hover:
    backgroundColor: "oklch(0.555 0.185 150)"
    textColor: "{colors.memory-green-foreground}"
  button-secondary:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.secondary-foreground}"
    rounded: "{rounded.lg}"
    padding: "8px 16px"
    height: "36px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.foreground}"
    rounded: "{rounded.lg}"
    padding: "8px 16px"
  input:
    backgroundColor: "{colors.background}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.lg}"
    padding: "8px 12px"
    height: "36px"
  card:
    backgroundColor: "{colors.background}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.xl}"
    padding: "24px"
  badge:
    backgroundColor: "{colors.muted}"
    textColor: "{colors.muted-foreground}"
    rounded: "{rounded.sm}"
    padding: "2px 8px"
    typography: "{typography.label}"
  toast:
    backgroundColor: "oklch(1 0 0 / 0.82)"
    textColor: "{colors.foreground}"
    rounded: "{rounded.xl}"
    padding: "16px"
---

# Design System: Recuerd0

## 1. Overview

**Creative North Star: "The Layered Archive"**

Recuerd0's interface is a place where knowledge accumulates in legible strata. The
logomark — three rounded rectangles stacked at increasing opacity — is not decoration;
it is the whole system's thesis. Each layer is a version, a decision, a preserved
thought, and the design treats the screen the same way: clean planes of one calm green
hue, depth built from transparency and tonal layering rather than noise. It is the
visual form of "like Git for context" — structure you can read at a glance, history you
can trust.

The personality is **precise, human, and quietly confident** — a developer tool built
by people who care about craft. Density is moderate and breathing: generous whitespace,
a single restrained accent, type that does the talking. Authority comes from clarity,
not volume. The marketing surface is proof of the product's own philosophy ("simple
tools, used well, beat complex ones"), so every element must earn its place; if a screen
could be quieter and still say the same thing, it is not finished.

This system **explicitly rejects** the saturated defaults of AI-tool marketing: no
hero-metric template (big number + gradient accent), no identical icon-heading-text card
grids, no tiny uppercase tracked eyebrow above every section, no `01 / 02 / 03` scaffold
by reflex, no chatbot/"AI-powered magic" framing, no enterprise clutter, no
consumer-flashy over-animation, no glassmorphism-as-decoration, no gradient text. The
human is the hero; the machine is the instrument.

**Key Characteristics:**
- One hue, hue 150 (green), carries the entire identity — light and dark.
- Flat by default; depth from transparency and tonal layers, not heavy shadow.
- Three-font system: Jura (display), Instrument Sans (body), Geist Mono (labels/code).
- The accent is rare and load-bearing, never a wash.
- Lowercase brand, always: `recuerd0`.

## 2. Colors

A monochromatic green system anchored on OKLCH hue 150, with true-neutral text and a
small set of semantic signals. Restraint is the strategy: the surface is near-white,
the green appears only where it means something.

### Primary
- **Memory Green** (`oklch(0.600 0.190 150)`): The single brand accent. Primary
  buttons, links, focus rings, the wordmark's terminal "0", active sidebar items,
  chart series. Mid-tone — bright enough to signal, dark enough to read on white. It is
  load-bearing, never a background wash.

### Secondary
- **Tint Green** (`oklch(0.940 0.045 150)`): Subtle filled backgrounds for secondary
  buttons and quiet emphasis. Pairs with **Secondary Ink** (`oklch(0.280 0.055 150)`)
  for text on tint.

### Neutral
- **Paper** (`oklch(1.000 0.000 0)`): Page, card, and popover background. A true white
  (chroma 0), not a warm cream — warmth is carried by type and the green, never by a
  tinted body.
- **Ink** (`oklch(0.145 0.000 0)`): Primary text. Near-black, true neutral.
- **Muted Surface** (`oklch(0.960 0.008 150)`): Faintly green-tinted fills for code
  blocks, inactive zones, badges.
- **Muted Ink** (`oklch(0.460 0.010 150)`): Secondary text, metadata, placeholders.
  Held at a real contrast — never a faint elegance-gray.
- **Border** (`oklch(0.900 0.010 150)`): Hairline dividers, input strokes, card edges.
- **Sidebar** (`oklch(0.975 0.006 150)`): The app shell's left rail, a half-step off
  Paper so the workspace reads as the focal plane.

### Semantic
- **Destructive** (`oklch(0.580 0.237 28.43)`): Deletions, errors. The only warm hue
  in the system; its rarity is the alarm.
- **Success / Warning / Info** (`oklch(0.940 0.035 150)` / `oklch(0.940 0.030 85)` /
  `oklch(0.940 0.035 230)`): Tonal status fills, each with a darker same-hue foreground.
  Status is always color **plus** text or icon — never hue alone (color-blind safe).

### Named Rules
**The One Green Rule.** Memory Green is the only chromatic accent in the product palette.
It appears on roughly ≤10% of any screen. If two things on a screen are green, one of
them is wrong. Its scarcity is what makes it mean "this matters / this is live."

**The True-Neutral Rule.** Backgrounds are chroma-0 Paper or near-zero tinted neutrals.
The cream/sand/beige warm-near-white is forbidden — warmth comes from Jura and the
green, not from the body color.

**The Dark-Mode Lift Rule.** In dark mode the hue holds; lightness inverts around
`oklch(0.170 0.010 150)` surfaces with `oklch(0.580 0.180 150)` accent. Never invert by
desaturating to gray — the green identity survives the switch.

## 3. Typography

**Display Font:** Jura (with system-ui, sans-serif)
**Body Font:** Instrument Sans (with system-ui, sans-serif)
**Label/Mono Font:** Geist Mono (with ui-monospace, monospace)

**Character:** A deliberate three-way pairing on a contrast axis, not three lookalikes.
Jura is a geometric, slightly technical display sans with open counters — calm, precise,
a touch architectural. Instrument Sans is a warm, highly legible humanist body face that
keeps long prose human. Geist Mono supplies the engineering register for labels, tags,
and code. Together: precise where it counts, warm where you read, technical where it's
honest about being a developer tool.

### Hierarchy
- **Display** (Jura 500, `clamp(2.25rem, 4vw, 3.5rem)`, line-height 1.05, -0.01em):
  Marketing hero and page headings. Ceiling held well under 6rem — the page designs,
  it does not shout. Use `text-wrap: balance`.
- **Headline** (Jura 500, ~1.75rem / 28px, line-height 1.2): Section headings on
  marketing and in-app section titles.
- **Title** (Jura 500, ~1.6rem / 26px, line-height 1.4, -0.01em): Card titles and the
  borderless `form-title` document input. Line-height 1.4 deliberately avoids Jura's
  descender clipping.
- **Body** (Instrument Sans 400, 1rem / 0.9375rem in dense UI, line-height 1.6): All
  prose and UI text. Cap measure at 65–75ch. Use `text-wrap: pretty` on long prose.
- **Label** (Geist Mono 400, 0.625rem / 10px, letter-spacing 0.15em): Tags, badges,
  technical metadata, code-adjacent chrome. The mono + wide tracking is the system's
  one "technical" tell — used on small chrome, never on headings.

### Named Rules
**The Jura-Headlines Rule.** Every heading is Jura 500. Body is never Jura; labels are
never Instrument Sans. The three faces stay in their lanes so the contrast axis reads.

**The Lowercase Wordmark Rule.** The brand is always `recuerd0`, lowercase, with the
terminal "0" in Memory Green at a heavier weight. Never capitalize, never recolor.

## 4. Elevation

Flat by default. Depth is built from **transparency and tonal layering** — Paper vs
Muted vs Sidebar planes, and color-mix overlays — not from a shadow stack. Shadow is a
*response to state*, not a resting property: the workhorse is a single hairline
`--shadow-xs` (`0 1px 2px 0 rgb(0 0 0 / 0.05)`) on inputs and pressed segmented
controls. There is exactly one deliberate exception (see below).

### Shadow Vocabulary
- **Hairline** (`box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05)`): Inputs at rest, checked
  segmented-control items. Barely-there separation.
- **Focus Ring** (`box-shadow: var(--shadow-xs), 0 0 0 3px color-mix(in oklch, var(--ring) 50%, transparent)`):
  The universal focus treatment. A 3px Memory-Green halo at 50% mix. Every focusable
  control uses this exact formula — consistency is the accessibility guarantee.
- **Frosted Float** (`box-shadow: 0 8px 32px rgb(0 0 0 / 0.08), 0 2px 8px rgb(0 0 0 / 0.05)`
  + `backdrop-filter: blur(16px) saturate(1.4)`): Toasts only.

### Named Rules
**The Flat-By-Default Rule.** Surfaces are flat at rest. Shadow appears only as a
response to state — focus, the pressed segment, a floating toast. If a card has a
resting drop-shadow, it is wrong; separate with a border or a tonal plane instead.

**The One-Frost Rule.** Backdrop-blur glass exists in exactly one place: the toast. It
floats above the app, so it earns the frost. Glassmorphism anywhere else — cards, nav,
hero panels — is forbidden.

## 5. Components

Components are styled by the `maquina_components` gem via `[data-component]` and
`[data-form-part]` selectors. Lead with the feel, then the spec.

### Buttons
Precise and quietly confident — solid, compact, no gloss.
- **Shape:** Gently rounded (`var(--radius)`, 8px / `rounded.lg`).
- **Primary:** Memory Green fill, white text, `8px 16px` padding, ~36px tall. Hover
  darkens the green by ~one step; no lift, no glow.
- **Secondary:** Tint Green fill with Secondary Ink text. **Ghost:** transparent with
  Ink text, Muted hover fill.
- **Hover / Focus:** Background shift on hover (150ms); focus uses the universal Focus
  Ring formula. Never a transform bounce.

### Chips / Tags
- **Style:** Muted Surface fill, Muted Ink text, Geist Mono label type at 10px with
  0.15em tracking, small radius (4px). Removable chips carry a muted `×` that goes Ink
  on hover.
- **State:** Selected filter chips lift to Tint Green; unselected stay Muted.

### Cards / Containers
- **Corner Style:** `rounded.xl` (12px) for content cards.
- **Background:** Paper, on a Paper or Sidebar page — separation by border or plane,
  not shadow.
- **Shadow Strategy:** None at rest (see The Flat-By-Default Rule).
- **Border:** 1px Border hairline.
- **Internal Padding:** 24px (`spacing.lg`). Never nest a card inside a card.

### Inputs / Fields
- **Style:** Paper background, 1px Border/Input stroke, `var(--radius)` corners,
  `--shadow-xs` hairline at rest, ~36px tall.
- **Focus:** Border shifts to Memory Green and the Focus Ring halo appears — the exact
  `box-shadow: var(--shadow-xs), 0 0 0 3px color-mix(in oklch, var(--ring) 50%, transparent)`.
- **Error:** Inline error text uses `text-destructive`; `[data-form-part="error"]` is
  near-white on filled destructive surfaces. **Placeholder:** Muted Ink at 0.75 opacity,
  held to body-text contrast — never a faint gray.

### Navigation (Sidebar app shell)
- **Style:** Left rail on the Sidebar plane (`oklch(0.975 0.006 150)`), collapsible to a
  3rem icon rail (`--sidebar-width` 16rem ↔ `--sidebar-width-icon` 3rem). Cookie
  `recuerd0_sidebar_state` persists the choice.
- **States:** Active item uses `sidebar-accent` fill with Memory-Green primary marker;
  hover is a quiet tonal fill. Dropdown menus with nav items use `auto_close: true`.

### Signature: The Memory-Layers Logomark
Three rounded rectangles (rx 7 at viewBox scale), offset 8px diagonally, at 15% / 40% /
100% opacity on light (20% / 50% / 100% on dark), all Memory Green. Minimum height 16px;
clear space = 1× the 8px layer offset. Never reorder the layers, recolor, skew, or add
effects. This mark is the north star made literal.

### Signature: form-title
A borderless, transparent document-title input in Jura 500 at 1.6rem, -0.01em,
line-height 1.4. No box, no chrome — the title reads as the document, prioritizing
content over form. The bordered editor shell owns the focus frame.

## 6. Do's and Don'ts

### Do:
- **Do** keep Memory Green load-bearing and rare — ≤10% of any screen (The One Green Rule).
- **Do** build depth from tonal planes (Paper / Muted / Sidebar) and transparency, not
  from resting shadows (The Flat-By-Default Rule).
- **Do** use the exact Focus Ring formula on every focusable control:
  `var(--shadow-xs), 0 0 0 3px color-mix(in oklch, var(--ring) 50%, transparent)`.
- **Do** keep the three fonts in their lanes: Jura 500 for all headings, Instrument Sans
  for body, Geist Mono for labels/tags/code.
- **Do** hold body and placeholder text to ≥4.5:1 (target 7:1 / AAA where feasible);
  bump Muted Ink toward Ink before shipping faint text.
- **Do** pair every status with text or icon, never hue alone (color-blind safe).
- **Do** write the brand lowercase: `recuerd0`, terminal "0" in Memory Green.
- **Do** show real material — an actual API call, a version diff, a workspace — over
  abstract promises (concrete > abstract).

### Don't:
- **Don't** use a cream / sand / beige / warm-near-white body background. Backgrounds are
  chroma-0 Paper or near-zero tinted neutral (The True-Neutral Rule).
- **Don't** ship the generic SaaS landing: no hero-metric template (big number + small
  label + gradient accent), no identical icon-heading-text card grids repeated down the
  page.
- **Don't** put a tiny uppercase tracked eyebrow above every section, or `01 / 02 / 03`
  numbered markers as default scaffolding. Numbers earn their place only in a real sequence.
- **Don't** frame this as an "AI-powered" / "intelligent" / "magic" product, or use
  chat-bubble UI. The human curates; the machine consumes.
- **Don't** use gradient text (`background-clip: text`), decorative glassmorphism (frost
  is toasts-only), or `border-left`/`border-right` > 1px as a colored stripe accent.
- **Don't** add resting drop-shadows to cards, or transform-bounce/elastic motion on
  buttons. Motion is restrained; ease-out only, with a `prefers-reduced-motion` fallback.
- **Don't** nest a card inside a card.
- **Don't** reach for enterprise buzzwords or hype in UI copy (leverage, unlock,
  supercharge, 10x, seamless, frictionless, disrupt, game-changer, synergy, paradigm).
