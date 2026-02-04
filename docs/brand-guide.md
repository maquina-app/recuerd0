# Recuerd0 — Brand Guide v1.0

> LLM Context Management Platform

---

## 01 — Overview

Recuerd0 is a platform that preserves, versions, and organizes knowledge from conversations with AI. The brand identity reflects this purpose: clean, precise, and quietly confident — a developer tool that treats memory preservation as both science and craft.

**Brand personality:** Clean & minimal, developer-tool precision, the quiet confidence of software built by people who care deeply about craft.

**Name origin:** "Recuerdo" is Spanish for "memory." The terminal "o" is replaced with "0" — bridging the warmth of human memory with digital identity (binary, code, systems).

---

## 02 — Logomark: Memory Layers

The logomark consists of three cascading rounded rectangles at varying opacities. Each layer represents a conversation, a document, a preserved thought — building depth through accumulation.

### Concept

The mark captures three core product concepts:

- **Versioning** — layers stacking over time, each building on the last
- **Depth** — transparency creates visual depth, suggesting accumulated knowledge
- **Structure** — consistent geometry communicates the precision of a developer tool

### Construction

```
ViewBox: 0 0 52 56

Back layer:   x="16" y="2"  width="32" height="38" rx="7"
Middle layer: x="8"  y="10" width="32" height="38" rx="7"
Front layer:  x="0"  y="18" width="32" height="38" rx="7"

Diagonal offset: 8px per layer (both x and y)
Corner radius: 7 (at viewBox scale)
```

### Opacity Values

| Layer  | Light Background | Dark Background |
|--------|-----------------|-----------------|
| Back   | 15%             | 20%             |
| Middle | 40%             | 50%             |
| Front  | 100%            | 100%            |

> On dark backgrounds, the back layers use slightly higher opacity to maintain visibility.

### SVG Code

**Primary (light background):**

```svg
<svg viewBox="0 0 52 56" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="16" y="2" width="32" height="38" rx="7" fill="oklch(0.600 0.190 150)" opacity="0.15"/>
  <rect x="8" y="10" width="32" height="38" rx="7" fill="oklch(0.600 0.190 150)" opacity="0.40"/>
  <rect x="0" y="18" width="32" height="38" rx="7" fill="oklch(0.600 0.190 150)"/>
</svg>
```

**Primary (dark background):**

```svg
<svg viewBox="0 0 52 56" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="16" y="2" width="32" height="38" rx="7" fill="oklch(0.600 0.190 150)" opacity="0.20"/>
  <rect x="8" y="10" width="32" height="38" rx="7" fill="oklch(0.600 0.190 150)" opacity="0.50"/>
  <rect x="0" y="18" width="32" height="38" rx="7" fill="oklch(0.600 0.190 150)"/>
</svg>
```

**Monochrome (black):**

```svg
<svg viewBox="0 0 52 56" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="16" y="2" width="32" height="38" rx="7" fill="#1a1a1a" opacity="0.10"/>
  <rect x="8" y="10" width="32" height="38" rx="7" fill="#1a1a1a" opacity="0.30"/>
  <rect x="0" y="18" width="32" height="38" rx="7" fill="#1a1a1a"/>
</svg>
```

**Monochrome (white, for dark backgrounds):**

```svg
<svg viewBox="0 0 52 56" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="16" y="2" width="32" height="38" rx="7" fill="#ffffff" opacity="0.12"/>
  <rect x="8" y="10" width="32" height="38" rx="7" fill="#ffffff" opacity="0.35"/>
  <rect x="0" y="18" width="32" height="38" rx="7" fill="#ffffff"/>
</svg>
```

### Clear Space

Maintain minimum clear space equal to 1× the layer offset (8 units at viewBox scale) around all sides of the logomark. This ensures the layering effect reads cleanly without interference from surrounding elements.

### Minimum Size

The logomark should not be rendered smaller than **16px** in height. At this size, the front layer still carries the identity while the transparency layers add subtle depth.

---

## 03 — Wordmark

The wordmark spells "recuerd0" in all lowercase using Jura Light (300 weight). The terminal "0" is set in Jura Medium (500 weight) and colored in the primary green.

### Specifications

| Property        | Value              |
|-----------------|--------------------|
| Font            | Jura Light (300)   |
| Zero font       | Jura Medium (500)  |
| Zero color      | `--primary`        |
| Letter spacing  | +1px (at 48px)     |
| Case            | All lowercase      |

### Usage Rules

- The "0" is always colored in `--primary` in the full-color version
- In monochrome contexts, the "0" matches the rest of the text but retains medium weight
- The wordmark is always set in lowercase — never capitalize
- Maintain letter spacing proportionally when scaling

---

## 04 — Lockups

The logomark and wordmark combine into a horizontal lockup. This is the primary brand mark for most applications.

### Horizontal Lockup

```
[logomark] — 20px gap — [wordmark]
```

- Logo height matches the x-height of the wordmark
- The gap scales proportionally (approximately 0.4× logo height)
- Use this lockup for navigation bars, headers, and marketing materials

### Lockup Variants

| Variant          | Usage                                      |
|------------------|--------------------------------------------|
| Full color       | Default for all applications               |
| Monochrome black | Print, single-color contexts               |
| Monochrome white | Dark backgrounds, single-color contexts    |

---

## 05 — Color System

The color system is built on **oklch** color space with **hue 150** as the anchor. All colors are defined as CSS custom properties.

### Core Palette

| Token                  | Value                      | Usage                |
|------------------------|---------------------------|----------------------|
| `--primary`            | `oklch(0.600 0.190 150)`  | Brand green, CTAs    |
| `--primary-foreground` | `oklch(1.000 0.000 0)`    | Text on primary      |
| `--secondary`          | `oklch(0.940 0.045 150)`  | Subtle backgrounds   |
| `--secondary-foreground`| `oklch(0.280 0.055 150)` | Text on secondary    |

### Neutral Palette

| Token                  | Value                      | Usage                |
|------------------------|---------------------------|----------------------|
| `--background`         | `oklch(1.000 0.000 0)`    | Page background      |
| `--foreground`         | `oklch(0.145 0.000 0)`    | Primary text         |
| `--muted`              | `oklch(0.960 0.008 150)`  | Subtle surfaces      |
| `--muted-foreground`   | `oklch(0.460 0.010 150)`  | Secondary text       |
| `--card`               | `oklch(1.000 0.000 0)`    | Card backgrounds     |
| `--card-foreground`    | `oklch(0.145 0.000 0)`    | Card text            |
| `--popover`            | `oklch(1.000 0.000 0)`    | Popover backgrounds  |
| `--popover-foreground` | `oklch(0.145 0.000 0)`    | Popover text         |

### Semantic Palette

| Token                      | Value                      | Usage               |
|----------------------------|---------------------------|---------------------|
| `--destructive`            | `oklch(0.580 0.237 28.43)`| Errors, deletions   |
| `--destructive-foreground` | `oklch(0.985 0.010 25)`   | Text on destructive |
| `--success`                | `oklch(0.940 0.035 150)`  | Success states      |
| `--success-foreground`     | `oklch(0.300 0.065 150)`  | Text on success     |
| `--warning`                | `oklch(0.940 0.030 85)`   | Warning states      |
| `--warning-foreground`     | `oklch(0.330 0.055 85)`   | Text on warning     |
| `--info`                   | `oklch(0.940 0.035 230)`  | Info states         |
| `--info-foreground`        | `oklch(0.300 0.065 230)`  | Text on info        |

### UI Palette

| Token       | Value                      | Usage               |
|-------------|---------------------------|---------------------|
| `--border`  | `oklch(0.900 0.010 150)`  | Borders, dividers   |
| `--input`   | `oklch(0.900 0.010 150)`  | Input borders       |
| `--ring`    | `oklch(0.600 0.190 150)`  | Focus rings         |
| `--accent`  | `oklch(0.940 0.025 150)`  | Hover, active states|
| `--accent-foreground` | `oklch(0.280 0.030 150)` | Text on accent |
| `--radius`  | `0.5rem`                   | Default border radius|

### CSS Custom Properties

```css
:root {
  --radius: 0.5rem;
  --background: oklch(1.000 0.000 0);
  --foreground: oklch(0.145 0.000 0);
  --card: oklch(1.000 0.000 0);
  --card-foreground: oklch(0.145 0.000 0);
  --popover: oklch(1.000 0.000 0);
  --popover-foreground: oklch(0.145 0.000 0);
  --primary: oklch(0.600 0.190 150);
  --primary-foreground: oklch(1.000 0.000 0);
  --secondary: oklch(0.940 0.045 150);
  --secondary-foreground: oklch(0.280 0.055 150);
  --muted: oklch(0.960 0.008 150);
  --muted-foreground: oklch(0.460 0.010 150);
  --accent: oklch(0.940 0.025 150);
  --accent-foreground: oklch(0.280 0.030 150);
  --destructive: oklch(0.580 0.237 28.43);
  --destructive-foreground: oklch(0.985 0.010 25);
  --success: oklch(0.940 0.035 150);
  --success-foreground: oklch(0.300 0.065 150);
  --warning: oklch(0.940 0.030 85);
  --warning-foreground: oklch(0.330 0.055 85);
  --info: oklch(0.940 0.035 230);
  --info-foreground: oklch(0.300 0.065 230);
  --border: oklch(0.900 0.010 150);
  --input: oklch(0.900 0.010 150);
  --ring: oklch(0.600 0.190 150);
}
```

---

## 06 — Typography

A three-font system designed for clarity across developer tools and marketing contexts.

### Font Stack

| Role     | Font             | Weight(s)   | Usage                           |
|----------|------------------|-------------|----------------------------------|
| Display  | Jura             | 300, 500    | Headings, navigation, wordmark   |
| Body     | Instrument Sans  | 400, 700    | Body text, UI elements           |
| Mono     | Geist Mono       | 400         | Code, labels, technical metadata |

### Type Scale (Suggested)

| Element           | Font             | Size   | Weight | Spacing     |
|-------------------|------------------|--------|--------|-------------|
| Page heading      | Jura             | 36–48px| 300    | -0.5px      |
| Section heading   | Jura             | 24–28px| 500    | -0.5px      |
| Navigation        | Jura             | 16–20px| 300    | +0.5px      |
| Body text         | Instrument Sans  | 15–16px| 400    | normal      |
| UI labels         | Instrument Sans  | 13px   | 400    | normal      |
| Code / metadata   | Geist Mono       | 10–14px| 400    | +0.5–1.5px  |
| Tags / badges     | Geist Mono       | 10px   | 400    | +1.5–2.5px  |

### Font Loading (Web)

```html
<!-- Google Fonts -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Jura:wght@300;500&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Instrument+Sans:wght@400;700&display=swap" rel="stylesheet">
```

```css
/* Fallback stack */
font-family: 'Jura', system-ui, sans-serif;        /* Display */
font-family: 'Instrument Sans', system-ui, sans-serif; /* Body */
font-family: 'Geist Mono', ui-monospace, monospace; /* Code */
```

---

## 07 — Usage Guidelines

### Do

- Use the provided color values and opacity levels exactly as specified
- Maintain clear space (1× layer offset) around the logo
- Use monochrome versions when color isn't available
- Scale the lockup proportionally — logo, gap, and text together
- Adjust back-layer opacities for dark backgrounds (20%/50% instead of 15%/40%)

### Don't

- Recolor the logo with non-brand colors
- Rotate, skew, stretch, or distort the logo
- Add drop shadows, glows, or other effects to the logo
- Reduce overall logo opacity or place on low-contrast backgrounds
- Change the layer order or offset proportions
- Use the wordmark without the "0" differentiation
- Capitalize any letters in the wordmark
- Place the logo on busy or patterned backgrounds

### Logo Selection Guide

| Context                      | Use                           |
|------------------------------|-------------------------------|
| App navigation bar           | Horizontal lockup             |
| Marketing header             | Horizontal lockup             |
| Favicon                      | Logomark only                 |
| Social media avatar          | Logomark only                 |
| Email signature              | Horizontal lockup (small)     |
| Single-color print           | Monochrome logomark or lockup |
| README / documentation       | Horizontal lockup             |
| CLI output                   | Wordmark (text only)          |

### Favicon Specifications

| Size   | Format | Usage                    |
|--------|--------|--------------------------|
| 16×16  | .ico   | Browser tab              |
| 32×32  | .png   | Browser tab (Retina)     |
| 48×48  | .png   | Bookmarks                |
| 180×180| .png   | Apple touch icon         |
| 512×512| .png   | PWA / manifest           |

---

## 08 — File Assets

### Included Files

| File                        | Description                        |
|-----------------------------|------------------------------------|
| `logo-concept-a-layers.svg` | Primary logomark SVG               |
| `recuerdo-brand-guide.html` | Interactive HTML brand guide       |
| `recuerdo-brand-guide.md`   | This document                      |
| `design-philosophy.md`      | Design philosophy / rationale      |

### Asset Naming Convention

```
recuerdo-logo-{variant}-{mode}.{ext}

Variants: primary, mono-black, mono-white
Modes:    light, dark
Extensions: svg, png

Examples:
  recuerdo-logo-primary-light.svg
  recuerdo-logo-mono-black-light.svg
  recuerdo-logo-primary-dark.png
```

---

## 09 — Brand Voice

### Tone

Recuerd0 communicates with the confidence of a well-built tool. The voice is clear, precise, and respectful of the user's time — no marketing fluff, no unnecessary adjectives.

### Writing Principles

- **Direct** — Say what it does, not what it could do
- **Technical but approachable** — Developer audience, but never gatekeeping
- **Lowercase preference** — The brand name is always lowercase: recuerd0
- **Minimal** — Fewer words, more meaning

### Example Copy

| Context     | Copy                                                    |
|-------------|---------------------------------------------------------|
| Tagline     | LLM context management                                 |
| Description | Preserve, version, and organize your AI conversations   |
| CTA         | Start preserving                                        |
| Error       | Memory not found in this workspace                      |
| Success     | Memory saved · v3                                       |

---

*Recuerd0 Brand Guide v1.0 · 2026*
