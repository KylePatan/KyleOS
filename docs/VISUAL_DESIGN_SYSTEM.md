# Kyle OS Visual Design System

**Resolves Decision Gate C** (`docs/PHASE_DECISION_REGISTER.md`). Given directly by Kyle,
2026-08-15, as the authoritative visual direction for Kyle OS going forward. This document is
the source of truth — treat it the way `KYLE_OS_MASTER_PRD_v1.3.md` is treated for product
behavior.

---

# 1. Core Visual Concept

Kyle OS should look like a **modern creative operating system designed through the visual
language of Windows 95/98 and the early web**.

The goal is not to recreate Windows 95 literally.

Instead, Claude should treat the visual direction as:

**Windows 95 structure + late-90s/early-2000s web personality + modern application smoothness.**

The interface should feel nostalgic immediately, but it should never feel slow, clunky,
confusing, or intentionally difficult to use.

A good mental model is:

> What would productivity software look like if the visual design of 1998 continued evolving
> for another 25 years instead of being replaced by minimalist floating-card interfaces?

The application should feel like a **real operating environment**, not a collection of modern
web cards wearing a retro skin.

---

# 2. Overall Page Structure

Kyle OS should strongly favor **top-to-bottom organization**.

Most screens should begin immediately beneath the primary navigation/header and build downward.

Avoid vertically centering the primary content.

Avoid layouts where a small content card sits in the middle of an otherwise empty screen.

The general structure should resemble:

```text
┌─────────────────────────────────────────────────────────────────┐
│ KYLE OS                                      Date / Status / ⚙  │
├─────────────────────────────────────────────────────────────────┤
│ HOME   WRITING   STAND UP   CLIPS   SKETCHES   CALENDAR ...    │
├─────────────────────────────────────────────────────────────────┤
│ Page Title                        Controls / Add / Filter        │
├─────────────────────────────────────────────────────────────────┤
│ Section / Toolbar / Information                                 │
├─────────────────────────────────────────────────────────────────┤
│ Content                                                         │
│ Content                                                         │
│ Content                                                         │
│ Content                                                         │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ Optional status / sync / autosave information                   │
└─────────────────────────────────────────────────────────────────┘
```

The user should feel like they are working **inside a program**, not browsing a marketing
website.

---

# 3. Use the Full Screen

Claude should make intentional use of the available desktop window.

The application should generally have relatively small outer margins.

Content should not be restricted to an arbitrary narrow `max-width` such as 900–1200px unless
the content itself requires it.

For dashboard, scheduling, calendar, project management, joke organization, and similar
screens:

**use the width of the window.**

A reasonable default content padding would be approximately:

* 12–20px around primary application sections
* 6–12px between closely related controls
* 16–24px between major sections

Avoid modern layouts with 60–100px gaps between every section.

Whitespace should communicate organization, not luxury.

---

# 4. Visual Density

The application should have **medium-to-high information density**.

The user should be able to see a large portion of their schedule, project, jokes, scenes,
clips, tasks, etc. without excessive scrolling.

For example, a task row should generally resemble:

```text
┌─────────────────────────────────────────────────────────────────┐
│ □  Write Act 2 Scene 4        SCREENPLAY     Due Aug 21   60%  │
└─────────────────────────────────────────────────────────────────┘
```

rather than:

```text



            ┌──────────────────────────┐
            │                          │
            │   Write Act 2 Scene 4    │
            │                          │
            │      SCREENPLAY          │
            │                          │
            │       Due Aug 21         │
            │                          │
            └──────────────────────────┘



```

Kyle OS should prefer **rows, lists, tables, panels, toolbars, tabs, and compact modules** over
giant cards.

---

# 5. Primary Application Chrome

The outer application should have a subtle feeling of classic desktop software.

Use clearly defined structural areas.

Potential hierarchy:

```text
Application Header
↓
Primary Module Navigation
↓
Page Header / Toolbar
↓
Working Area
↓
Status Bar
```

The different areas should be separated using visible borders rather than relying exclusively
on whitespace.

For example:

* 1px darker borders
* raised/inset section edges
* subtle highlights
* title strips
* header bars

The interface should have **edges**.

Modern UI often removes almost every border.

Kyle OS should intentionally bring borders back.

---

# 6. Window Design

Pop-up windows are a major part of the aesthetic.

When the user opens something like:

* Add Task
* Edit Task
* Add Joke
* Joke Details
* Scene Details
* Project Details
* Event Details
* Session Details
* Settings
* Scheduling Conflict
* Export
* Confirmation
* Project Information

it should resemble a classic desktop application window.

Basic structure:

```text
╔══════════════════════════════════════════╗
║ Edit Task                         _ □ X  ║
╠══════════════════════════════════════════╣
║                                          ║
║ Task Name                                ║
║ ┌──────────────────────────────────────┐ ║
║ │ Rewrite opening scene                │ ║
║ └──────────────────────────────────────┘ ║
║                                          ║
║ Due Date        Priority                 ║
║ [ Aug 21 ▼ ]    [ High ▼ ]              ║
║                                          ║
║                    [ Cancel ] [ Save ]   ║
╚══════════════════════════════════════════╝
```

### Window Characteristics

Windows should have:

* A clearly visible title bar
* Strong outer border
* Slight depth or shadow
* Compact title text
* Window controls
* Defined content region
* Bottom action area when appropriate

The title bar may use a stronger accent colour than the rest of the interface.

Do not make modal windows look like rounded mobile cards.

They should look like **windows**.

---

# 7. Window Corners

Avoid excessive rounded corners.

The primary retro style should use:

* Square corners
* Near-square corners
* Extremely small radius where technically needed

Suggested range:

`0px – 4px`

Do not default to modern `12px`, `16px`, or `24px` rounded cards everywhere.

A large rounded rectangle immediately makes the design feel more like a contemporary SaaS
dashboard.

Kyle OS should instead feel **structured, mechanical, and desktop-like**.

---

# 8. Borders and Depth

Use classic UI depth cues carefully.

Buttons and panels can use combinations of:

* light top/left edge
* darker bottom/right edge
* 1px borders
* inset input fields
* raised buttons

This can reference the classic Windows beveled appearance without becoming cartoonish.

Example conceptual button:

```text
┌──────────────┐
│ + Add Project│
└──────────────┘
```

Default:

slightly raised

Pressed:

slightly inset

Hover:

subtle highlight

The physical response of the interface should help communicate what can be clicked.

---

# 9. Buttons

Buttons should generally be compact.

Avoid huge pill-shaped buttons.

Preferred button types:

### Standard

```text
[ Save ]
```

### Add

```text
[ + Add Task ]
```

### Toolbar

```text
[ New ] [ Edit ] [ Duplicate ] [ Delete ]
```

### Toggle

```text
[ Day ] [ Week ] [ Month ]
```

Buttons should visually resemble **controls**, not marketing calls-to-action.

Primary actions can use accent colours, but most application controls should remain relatively
neutral.

---

# 10. Inputs

Form inputs should feel slightly inset into the interface.

Example:

```text
Project Name
┌───────────────────────────────────────┐
│ Comedy Pilot                         │
└───────────────────────────────────────┘
```

Inputs should have clearly visible boundaries.

Avoid floating labels.

Avoid giant inputs.

Avoid extremely rounded fields.

Checkboxes, radio buttons, dropdowns, number steppers, and date fields can deliberately
reference classic desktop controls.

---

# 11. Tabs

Tabs are encouraged throughout Kyle OS.

For example:

```text
┌──────────┬──────────┬──────────┬──────────┐
│ Overview │ Outline  │ Draft    │ Sessions │
└──────────┴──────────┴──────────┴──────────┘
```

The active tab should appear physically connected to the content underneath it.

This is preferable to modern navigation where tabs are just words floating above empty space.

Potential uses:

* Writing project sections
* Joke categories
* Project details
* Settings
* Reports
* Calendar views
* Clip stages

---

# 12. Toolbars

Toolbars are strongly encouraged.

Example:

```text
FILE   EDIT   VIEW

[ + Scene ] [ + Note ] [ Search ] [ Outline ] [ Export ]

──────────────────────────────────────────────────────────
```

Toolbars help create the feeling that Kyle OS is **software**, rather than a website.

They also allow useful actions to remain available without wasting vertical space.

---

# 13. Navigation

Primary navigation should remain visible and compact.

Potential structure:

```text
KYLE OS

HOME | WRITING | STAND UP | CLIPS | SKETCHES | CALENDAR | REPORTS
```

The active module should be obvious.

It may resemble:

* A pressed button
* Selected desktop tab
* Highlighted toolbar item
* Classic menu state

Avoid giant sidebar navigation unless it clearly improves a specific screen.

For the main app, horizontal navigation near the top supports the intended **top-down
architecture**.

Secondary sidebars are acceptable for context-specific navigation such as:

* Writing projects
* Script scenes
* Joke chunks
* Calendar lists

---

# 14. Cards Should Feel Like Panels

When cards are required, Claude should think of them as **panels or windows**, not floating
cards.

Instead of:

```text
     rounded card
     soft shadow
     huge padding
```

prefer:

```text
┌─ TODAY'S CREATIVE SCHEDULE ─────────────────────────────┐
│ 10:00  Rewrite Scene 4                             45m │
│ 11:00  Edit Stand-Up Clip                          30m │
│ 14:30  Work on New Joke Chunk                      45m │
└─────────────────────────────────────────────────────────┘
```

Sections should usually have:

* heading bar
* border
* compact internal spacing
* rows of data

---

# 15. Section Headers

Sections can use retro utility-style title bars.

For example:

```text
┌─ UPCOMING DEADLINES ────────────────────────────────────┐
```

or

```text
┌─────────────────────────────────────────────────────────┐
│ UPCOMING DEADLINES                                      │
├─────────────────────────────────────────────────────────┤
```

This makes sections easy to scan while preserving density.

---

# 16. Scheduling Interface

Scheduling is central to Kyle OS, so it should strongly follow the top-to-bottom metaphor.

A day should visually read downward through time.

For example:

```text
TUESDAY — AUGUST 18

08:00 ───────────────────────────────────────────────────

09:00   [ Work ]

10:00   [ Work ]

11:00   [ Work ]

12:00 ───────────────────────────────────────────────────

13:00   [ Lunch ]

14:00   [ Rewrite Pilot Scene ]          45 min

15:00   [ Edit Comedy Clip ]             60 min

16:00   [ Free ]

17:00 ───────────────────────────────────────────────────
```

The schedule should feel like something being **constructed from the top down**.

Task ordering should reinforce this same idea.

---

# 17. Home Dashboard

The Home screen should feel like a **control panel**.

It should immediately begin providing useful information rather than displaying a welcome
message in the middle of the screen.

Example structure:

```text
TODAY — SATURDAY AUGUST 15
─────────────────────────────────────────────────────────────

NEXT UP
14:30  Work on Pilot Outline                         45 MIN

TODAY'S SCHEDULE
─────────────────────────────────────────────────────────────
10:00 ...
11:00 ...
12:00 ...

TASKS
─────────────────────────────────────────────────────────────

POST IT
─────────────────────────────────────────────────────────────

UPCOMING DEADLINES
─────────────────────────────────────────────────────────────
```

No giant:

> Good Morning, Kyle!

floating in the center of the application.

A greeting can exist, but it should not consume the screen.

---

# 18. Early Web Influence

The early-web inspiration should come through subtly.

Possible elements:

* compact hyperlinks
* underlined text where appropriate
* status text
* small icons
* visible separators
* tiny metadata
* colourful category indicators
* text-heavy layouts
* functional toolbars
* small counters
* simple progress bars
* occasional playful pixel graphics

However, avoid deliberately ugly early-web characteristics such as:

* blinking text
* excessive animated GIFs
* unreadable colour combinations
* tiled backgrounds
* random font sizes
* chaotic layouts

The nostalgia should feel **curated**.

---

# 19. Icons

Icons should be simple and slightly retro.

Potential style:

* 16×16
* 20×20
* pixel-inspired
* simple raster-style visual language
* slightly chunky

Examples:

📁 Project
📄 Script
📝 Notes
📅 Calendar
💾 Save
🗑 Trash
🔍 Search

Do not necessarily use these Unicode emojis directly.

Custom icons should ideally feel like old desktop application icons while remaining clear on
modern high-resolution displays.

---

# 20. Writing Environment

The actual writing surface should visually separate itself from the surrounding application UI.

The interface surrounding the document can remain retro.

The document itself should resemble a **writer's page**.

For screenplay, prose, sketch writing, and joke writing:

* Use a Courier-style typewriter font
* Prefer Courier Prime or an equivalent highly readable typewriter-style font
* Use monospace formatting
* Maintain proper screenplay formatting where relevant
* Keep writing typography relatively neutral and distraction-free

Example:

```text
               INT. APARTMENT - NIGHT

Kyle sits at his desk staring at his laptop.

                    KYLE
          This seemed easier when it
          was just an idea.
```

For joke writing:

```text
AIRPORT SECURITY

Premise:
Airport security treats shampoo like nuclear material.

Setup:
I don't understand why...

Tags:
- ...
- ...
```

The user's writing should feel like **material on a page**, while the tools surrounding it
feel like an operating system.

> **Implementation status (2026-08-15):** done — see `WritingSurfaceFont.swift`. Applied to the
> Script Editor, Prose Editor, Joke text, Chunk notes, Headline Set notes, and prose PDF export.
> Uses macOS's built-in Courier rather than a bundled Courier Prime font file (no
> licensing/bundling question to resolve now); swap in a bundled Courier Prime later from that
> one file if wanted.

---

# 21. Colour Direction — Light Mode

Light mode should be the default.

Primary surfaces should be bright.

Suggested aesthetic direction:

* warm white
* light gray
* classic computer gray
* pale blue-gray
* subtle cream

Accent colours can draw inspiration from classic computing:

* rich blue
* teal
* green
* yellow
* red
* purple

Use strong colour for:

* active windows
* selected items
* categories
* warnings
* progress
* status
* deadlines

Do not make every panel a different colour.

The base interface should remain consistent so colourful information stands out.

---

# 22. Title Bar Accent

Classic application windows can use a stronger title bar.

For example:

```text
████████████████████████████████████████████████
 PROJECT SETTINGS                            X
████████████████████████████████████████████████
```

The title bar could use a strong blue or another Kyle OS accent colour.

Active windows may use stronger colour.

Inactive windows can appear slightly muted.

---

# 23. Dark Mode

Dark mode should feel like **the same operating system at night**.

Do not redesign the interface.

Instead:

Light:

```text
background: light gray
panels: white / pale gray
text: near black
```

Dark:

```text
background: charcoal / dark gray
panels: slightly lighter charcoal
text: off-white
borders: visible gray
```

Accent colours should remain recognizable.

Typewriter writing areas may use:

* dark gray background
* warm white text

rather than pure black and pure white.

Dark Mode lives under:

**Settings → Appearance → Theme**

Options should eventually include:

* Light
* Dark
* System

---

# 24. Shadows

Use shadows sparingly.

Windows and menus can have small, slightly harder shadows.

Avoid giant soft shadows around every element.

The visual language should rely more on:

**borders + layering + contrast**

than floating shadows.

---

# 25. Menus

Dropdown menus and contextual menus can resemble classic desktop menus.

Example:

```text
┌──────────────────────┐
│ New Project          │
│ Duplicate            │
│ ──────────────────── │
│ Export               │
│ Archive              │
│ ──────────────────── │
│ Delete               │
└──────────────────────┘
```

They should appear quickly and feel crisp.

---

# 26. Scrollbars

Where technically practical, custom scrollbars may subtly reference older software.

They should remain usable and modern in behavior.

Scrollbars should not be hidden simply for visual minimalism when knowing the position within a
long document or schedule is useful.

---

# 27. Hover / Selected / Focus States

Every interactive element needs an obvious state.

Claude should explicitly implement:

### Hover

Small visual highlight.

### Active / Pressed

Slight inset or darker state.

### Selected

Clear accent highlight.

### Keyboard Focus

Visible outline.

### Disabled

Lower contrast but still readable.

A retro interface should never mean ambiguous interaction.

---

# 28. Animation Rules

Animation should be **modern, fast, and restrained**.

Recommended transition range:

approximately **100–200ms** for common UI transitions.

Examples:

* modal opening
* dropdown opening
* tab switching
* hover state
* task reorder
* expanding section

The user should never feel like they are waiting for an animation.

Avoid intentionally recreating old computer lag.

---

# 29. Drag and Drop

Dragging should be visually smooth.

When moving:

* tasks
* jokes
* scenes
* clips
* sessions

the original item should visibly lift from the interface.

The destination position should be clearly displayed.

After dropping, nearby items should smoothly reposition.

Retro appearance.

Modern physics.

---

# 30. Responsiveness

Kyle OS is primarily designed as a **desktop application**, so Claude should optimize the UI
for desktop-sized screens first.

Do not compromise the desktop experience simply to make every component mobile-compatible.

Within the desktop window, however, components should adapt gracefully to different window
sizes.

For example:

* side panels can shrink
* columns can resize
* toolbars can wrap or collapse
* horizontal scroll can exist where appropriate

Dense productivity software is allowed to behave like dense productivity software.

---

# 31. Consistent Component System

Claude should build the visual language into reusable components instead of recreating styles
independently on every screen.

Potential core components:

```text
RetroWindow
RetroModal
RetroButton
RetroInput
RetroSelect
RetroCheckbox
RetroRadio
RetroTabs
RetroToolbar
RetroPanel
RetroPanelHeader
RetroStatusBar
RetroMenu
RetroDropdown
RetroProgressBar
RetroTable
RetroListRow
RetroBadge
RetroTooltip
```

Changing the design system later should therefore update the entire application.

---

# 32. Avoid Generic SaaS Styling

Claude should specifically avoid automatically generating the stereotypical modern dashboard
look.

Avoid excessive use of:

* rounded cards
* huge whitespace
* floating glass panels
* gradient backgrounds
* pill-shaped everything
* giant typography
* massive side margins
* centered dashboards
* excessive drop shadows
* translucent glassmorphism
* giant icon cards
* decorative graphs with little information
* enormous buttons

Kyle OS should not look like a startup landing page.

It should look like **software someone actually works inside for hours**.

---

# 33. Personality

The application can occasionally be playful.

Small retro details are encouraged.

Examples:

```text
READY
```

in a bottom status bar.

Or:

```text
✓ Saved
```

Or a tiny disk icon when autosaving.

Or:

```text
3 PROJECTS OPEN
```

in a status area.

These details can make Kyle OS feel like its own little operating system.

However, the novelty should never overwhelm the work itself.

---

# 34. Reference Principle for Claude

When Claude must make an undocumented visual decision, use this priority order:

1. **Does it make the user's work easier?**
2. **Does it use screen space efficiently?**
3. **Does it preserve the top-to-bottom organizational structure?**
4. **Does it resemble desktop productivity software rather than a marketing website?**
5. **Can it incorporate a subtle Windows 95 / early-web visual reference?**
6. **Does it still feel smooth and modern to interact with?**

If a retro design choice harms usability, choose usability.

If a modern design convention creates excessive wasted space, reject the modern convention.

---

# 35. Short Visual Rule

The design can be summarized for implementation as:

> **Dense, bright, rectangular, bordered, top-down, desktop-first, nostalgic and highly
> functional.**

Or more conceptually:

> **Windows 98 grew up, became a creative professional, learned modern UX, and built an
> operating system for writers and comedians.**

---

# Implementation Log

Track major implementation milestones here as they ship, so future sessions know what's been
built against this spec versus still pending.

- **2026-08-15**: §20 (Writing Environment typography) shipped — see `WritingSurfaceFont.swift`.
  Everything else in this document (component system, navigation restructure, color system,
  window chrome, etc.) is not yet built.
