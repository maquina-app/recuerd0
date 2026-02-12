# Requirements: Marketing Pages Mobile Responsive

## Date
2026-02-12

## Summary
Make all marketing pages (landing, pricing, legal, API docs, CLI, Agents) fully responsive on mobile devices. Currently multiple UI issues exist at narrow viewports.

## Problems Identified

### 1. Marketing nav disappears on mobile
- At `max-width: 900px`, `.nav-links { display: none; }` hides all navigation links
- No hamburger menu or alternative navigation exists
- Users on mobile cannot navigate between pages at all
- Affects: landing page, pricing page, terms, privacy, license

### 2. Marketing footer not responsive
- `.footer-inner` uses `display: flex; justify-content: space-between` with no wrap
- `.footer-links` has 9 links in a horizontal row with `gap: 2rem`
- On narrow screens links overflow or get crammed
- Affects: landing page, pricing page

### 3. Doc footer not responsive
- Same horizontal layout issue as marketing footer
- `.doc-footer-inner` is flex row, `.doc-footer-links` has 9 links at `gap: 1.5rem`
- Affects: API docs, CLI, Agents pages

### 4. Doc header "Get Started" CTA oversized on mobile
- At 900px breakpoint, `.header-link` is hidden but `.header-cta` remains visible
- The hamburger button + brand + divider + section name + CTA all compete for narrow space
- User reports elements appearing "really really big" on doc pages

### 5. Doc sidebar drawer doesn't close on outside click
- No backdrop overlay behind the open sidebar
- No click-outside handler in the Stimulus controller
- Sidebar stays open until user explicitly clicks a sidebar link
- Poor mobile UX — users expect tap-outside-to-dismiss

## Decisions

### Q1: Marketing nav mobile pattern?
**Answer: Full-screen overlay**
- Dark overlay covering the full viewport with centered navigation links
- Hamburger button in the nav bar triggers open/close
- Animated transition (fade in)

### Q2: Doc sidebar close behavior?
**Answer: Click-anywhere close (no visible overlay)**
- No semi-transparent backdrop overlay
- Clicking anywhere outside the sidebar closes it
- Subtle but clean — matches the minimal aesthetic

### Q3: Mobile footer layout?
**Answer: Stacked center-aligned**
- Logo centered on top
- Links in a wrapped grid (2-3 columns)
- Maquina attribution centered below
- Clean and balanced

### Q4: Doc header CTA on mobile?
**Answer: Keep in header**
- CTA stays visible in the header for easy access
- It's the primary conversion action
- Size should be reasonable (not oversized)

## Files Affected

### CSS
- `app/assets/tailwind/marketing.css` — responsive section + new mobile styles

### JavaScript (Stimulus)
- `app/javascript/controllers/marketing_nav_controller.js` — add hamburger toggle + overlay behavior
- `app/javascript/controllers/marketing_sidebar_controller.js` — add click-outside-to-close

### Templates
- `app/views/pages/_marketing_nav.html.erb` — add hamburger button + overlay markup
- `app/views/pages/_marketing_footer.html.erb` — no HTML changes needed (CSS only)
- `app/views/pages/_doc_footer.html.erb` — no HTML changes needed (CSS only)
- `app/views/pages/_doc_header.html.erb` — possibly adjust CTA sizing

### No new files needed
All changes are to existing files.
