# Specification: Marketing Pages Mobile Responsive

## Goal

Fix all mobile responsiveness issues across marketing pages (landing, pricing, legal, API docs, CLI, Agents) so that navigation, footers, and doc sidebars work correctly on narrow viewports.

## User Stories

- As a mobile visitor, I want to access the navigation menu on marketing pages so that I can browse between pages on my phone
- As a mobile visitor browsing API/CLI/Agents docs, I want the sidebar drawer to close when I tap outside it so that I can return to reading content
- As a mobile visitor, I want footers to be readable and well-organized on narrow screens so that I can find links without horizontal scrolling

## Specific Requirements

**1. Marketing Nav — Full-Screen Mobile Overlay**
- Add a hamburger button (hidden on desktop, visible at `max-width: 900px`) to the marketing nav bar
- Tapping the hamburger opens a full-screen overlay with centered navigation links
- Overlay uses the same backdrop-blur glass effect as the nav bar, fully opaque
- Links are displayed vertically, centered, using Jura font at a larger touch-friendly size
- "Get Started" CTA is displayed as a prominent button at the bottom of the link list
- Tapping a link or the close button (X icon) closes the overlay
- Animated transition: fade in/out with subtle scale
- Hamburger icon animates to X when overlay is open
- Body scroll is locked while overlay is open

**2. Doc Header — Proper Mobile Sizing**
- At `max-width: 900px`, hide the `.header-divider` and `.header-section` text to save space
- Keep the hamburger toggle, brand logo, and "Get Started" CTA at reasonable sizes
- CTA button should use a smaller font size and padding on mobile
- Ensure the header elements don't overflow or wrap awkwardly

**3. Doc Sidebar — Click-Outside-to-Close**
- Add a `mousedown` / `touchstart` listener on the document when the sidebar is open
- If the click/tap target is outside the sidebar element and outside the hamburger toggle, close the sidebar
- Remove the listener when the sidebar closes (no performance impact when closed)
- No visible backdrop overlay — just invisible click-outside detection
- Sidebar should also close on `Escape` key press

**4. Marketing Footer — Responsive Stacked Layout**
- At `max-width: 900px`, switch `.footer-inner` from horizontal flex to vertical stacked layout
- Center the brand (logo + year) on its own line
- Display `.footer-links` as a wrapped flex/grid with `justify-content: center`, roughly 3 columns
- Reduce gap between links for narrow screens
- Keep Maquina attribution centered below
- Adequate vertical spacing between sections

**5. Doc Footer — Responsive Stacked Layout**
- Same responsive treatment as marketing footer
- At `max-width: 900px`, stack `.doc-footer-inner` vertically
- Center the brand, wrap footer links in centered columns
- Keep Maquina attribution centered

**6. Legal Pages Nav — Same Hamburger Treatment**
- Legal pages (terms, privacy, license) already render `_marketing_nav` partial
- The hamburger overlay solution from requirement 1 automatically applies here
- No additional template changes needed for legal pages

## Existing Code to Leverage

**Marketing Nav Controller (`app/javascript/controllers/marketing_nav_controller.js`)**
- Already manages scroll state and smooth scrolling
- Extend with overlay open/close toggle, body scroll lock, and keyboard (Escape) handling
- Already has `teardown()` for Turbo cache cleanup — extend it

**Marketing Sidebar Controller (`app/javascript/controllers/marketing_sidebar_controller.js`)**
- Already has `toggleSidebar()` and `closeSidebar()` methods
- Extend with click-outside detection and Escape key handler
- Already has `teardown()` — extend to clean up new listeners

**Marketing CSS responsive section (`app/assets/tailwind/marketing.css` line 1318)**
- Already has `@media (max-width: 900px)` block
- Extend with new responsive rules for footer, doc header, and nav overlay

**Marketing Nav partial (`app/views/pages/_marketing_nav.html.erb`)**
- Add hamburger button markup and overlay container
- Duplicate the nav links inside the overlay (or restructure so links can serve both contexts)

**Doc Header partial (`app/views/pages/_doc_header.html.erb`)**
- May need minor markup changes for mobile sizing

## Out of Scope

- Dark mode responsive adjustments (existing dark mode is not implemented for marketing)
- Tablet-specific breakpoint (use single 900px breakpoint matching existing code)
- Landscape phone orientation special handling
- Touch gestures (swipe to close sidebar)
- Animating sidebar open/close with spring physics
- Responsive changes to page content sections (hero, features, pricing cards already handled)
- Adding new pages or routes
