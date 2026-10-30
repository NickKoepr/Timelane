# PLAN v1.33 — Product website on GitHub Pages

## Context

Timelane needs a small public website: one page that says what the app is and shows what is in it, in the
app's own style. It is hosted on GitHub Pages from this repository. The repository is still private, so Pages
cannot serve it yet; the deploy workflow is added now and starts working once the repo is public and Pages is
enabled (Settings ▸ Pages ▸ Source: *GitHub Actions*).

The site is fully separate from the app: its own folder `website/`, no build step, no dependencies, nothing in
the Xcode project changes.

## Goals

- **Simple and descriptive**: little text, but after one scroll a visitor knows what the app does and which
  screens it has. Screenshots carry the page; text is captions and one-liners.
- **The app's style**: the logo blue `#2F6BEA` (`backgroundHex` in `Tools/generate-app-icon.swift`) as the
  accent, white clock icon, rounded corners, macOS system font. Light by default with a dark-mode variant.
- **Static** HTML + CSS only (a few lines of JS at most, none required). No frameworks, no CDNs, no web fonts,
  no analytics, no cookies — the app is "private by design", the site should be too.

## Content (English)

Source texts: the App Store copy (subtitle, promotional text, description). Shorten; don't paste the full
description. **Do not claim iCloud *sync*** — the app has an opt-in iCloud *backup* (a snapshot of the database
in the user's own iCloud, restored on request). Say "backup", never "sync".

Page sections, top to bottom:

1. **Header** (thin): icon + "Timelane" on the left; on the right a link "Features" (anchor) and the App Store
   button (see CTA below).
2. **Hero**: app icon (large), `h1` "Timelane", subtitle "Log work hours per project", the promotional text as
   one paragraph:
   > See where your working day went. Choose the apps you work in and Timelane shows them on a timeline, so
   > logging hours per project takes seconds, not guesswork.

   Below it the CTA, a small line "For macOS 26 or later", and the big timeline screenshot (`timeline.png`).
   The hero background may use a soft blue gradient in the logo blue (like the App Store images), the
   screenshot sits on it with a shadow.
3. **Features**: alternating rows (image left/right, text on the other side; stacked on mobile). Each row: a
   short heading (the App Store image titles) + 1–2 sentences.
   | Image (`website/images/`) | Heading | Text |
   |---|---|---|
   | `entry-form.png` | Log your hours in seconds | Drag across the timeline or click an app session, pick a project, done. Made a mistake? Undo it. |
   | `menu-bar.png` | Always at hand in the menu bar | Live tracking status, the same timeline and a Record / Stop timer, without opening the window. |
   | `projects.png` | Monthly totals for every project | Every project with its hours per month. Export a month as a spreadsheet (.xlsx) or JSON for invoices and timesheets. |
   | `overview.png` | Your year at a glance | A heatmap of every day you worked, monthly charts and totals per project. |
   | `tracked-apps.png` | You decide which apps are tracked | Only the apps on your list are recorded. Link an app to a project and its hours log themselves. |
   | `settings.png` | Backed up to your own iCloud | An optional backup of your data in your own iCloud. Off by default. |
4. **Private by design** (small band, 3 short points in a row, stacked on mobile):
   - "Only the apps you choose" — nothing else is recorded.
   - "Stays on your Mac" — all data is stored locally; no account.
   - "No tracking" — no analytics, no ads. (Use the phrase about the app; the site itself also has none.)
5. **Contact**: heading "Contact", one line, a `mailto:` link to nick@koepr.com. Header gets a "Contact" anchor link.
6. **Footer**: CTA again, "© 2026 Nick Kuiper", link to `privacy.html`.

Also add **`privacy.html`**: a short privacy policy (App Store Connect needs a privacy policy URL). Same header
and footer, one text column: Timelane collects no data; everything is stored locally on the Mac; the optional
iCloud backup is stored in the user's own private iCloud database and Timelane's developer cannot read it; the
website uses no cookies or analytics; contact via email (nick@koepr.com). Keep it under ~200 words.

### CTA

Use Apple's official **"Download on the Mac App Store" badge** (SVG from Apple's marketing resources, black on
light, white in dark mode via `<picture>`), unaltered, 48 px high (32 px in the header, hidden there on phones).
The app is not in the App Store yet, so the badge is a `<span>`, not a link, with a small "Coming soon" note.
Put an HTML comment next to each badge saying how to turn it into
`<a href="https://apps.apple.com/app/idXXXXXXXXXX">` and drop the note once the app is live. Apple's rules: only
official artwork, no changes to colour or shape, link it to the app's App Store page.

## Design details

- CSS custom properties on `:root`: `--accent: #2F6BEA`, a darker `--accent-strong` for hover, `--bg`, `--surface`,
  `--fg`, `--muted`, `--line`. Dark mode via `@media (prefers-color-scheme: dark)` redefining the same tokens
  (keep the accent blue; lighten it slightly only for text on dark backgrounds if contrast needs it).
- Font: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif`.
- Max content width ~1080px, 16px side gutter on phones, no horizontal scroll at 360px width.
- Screenshots: `<img>` with `width`/`height` attributes (no layout shift), `loading="lazy"` except the hero,
  meaningful `alt` text, `max-width: 100%; height: auto`. The window captures already have rounded corners and a
  transparent background; add a `filter: drop-shadow(...)` rather than a box-shadow (a box-shadow would show the
  square corners).
- The menu bar capture is portrait (380 × 600 pt); give its row a narrower image column so it isn't huge.
- Icon: `website/images/icon.png` (copy of `docs/icon.png`, 256 px) for the header/hero and as favicon
  (`<link rel="icon" href="images/icon.png">` plus `apple-touch-icon`).
- `<head>`: `lang="en"`, charset, viewport, `<title>Timelane — Log work hours per project</title>`,
  `meta description` (the promotional text), Open Graph tags (`og:title`, `og:description`, `og:image` =
  `images/timeline.png`, relative URL is acceptable for now).
- Accessibility: one `h1` per page, logical `h2`s, visible focus styles, colour contrast ≥ 4.5:1 for body text.
- Respect `prefers-reduced-motion` if anything animates (prefer no animation at all).

## Images

Source: `build/AppStoreScreenshots/raw/*.png` (Retina window captures with transparent corners, produced by
`Tools/make-app-store-screenshots.sh`; `build/` is git-ignored, so copy them into the site). Resize so the
committed images stay small — total for `website/images/` under ~2.5 MB:

```sh
mkdir -p website/images
for f in timeline entryForm projects overview trackedApps settings; do
  out=$(echo "$f" | sed -E 's/([A-Z])/-\1/g' | tr '[:upper:]' '[:lower:]')   # entryForm -> entry-form
  sips --resampleWidth 1600 "build/AppStoreScreenshots/raw/$f.png" --out "website/images/$out.png"
done
sips --resampleWidth 560 build/AppStoreScreenshots/raw/menuBar.png --out website/images/menu-bar.png
cp docs/icon.png website/images/icon.png
```
Keep PNG (transparency). Use the resulting pixel sizes (`sips -g pixelWidth -g pixelHeight`) for the `<img>`
`width`/`height` attributes. If the screenshots are regenerated later, rerun this block; document it in
`website/README.md`.

## GitHub Actions

### New: `.github/workflows/pages.yml`

```yaml
name: Deploy website

on:
  push:
    branches: [main]
    paths:
      - 'website/**'
      - '.github/workflows/pages.yml'
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: website
      - id: deployment
        uses: actions/deploy-pages@v4
```
Add a comment at the top: Pages needs a public repo (or a paid plan) and *Settings ▸ Pages ▸ Source: GitHub
Actions*; until then this workflow fails at `configure-pages`/`deploy-pages`, which is expected.

### Change: `.github/workflows/tests.yml`

Add `'website/**'` to `paths-ignore` so website-only PRs don't start the (slow, macOS) unit-test job.

## Files

- `website/index.html` — the page.
- `website/privacy.html` — privacy policy.
- `website/styles.css` — shared styles (both pages).
- `website/images/` — `icon.png`, `timeline.png`, `entry-form.png`, `menu-bar.png`, `projects.png`,
  `overview.png`, `tracked-apps.png`, `settings.png`.
- `website/.nojekyll` — empty; serve files as-is.
- `website/README.md` — how to preview locally (`python3 -m http.server -d website 8000`), how to refresh the
  images, how deploy works, how to switch the CTA to the real App Store link. (`README.md` inside `website/` is
  also uploaded to Pages; that's harmless. Alternatively exclude it — not needed.)
- `.github/workflows/pages.yml` — new.
- `.github/workflows/tests.yml` — `paths-ignore` += `website/**`.
- `README.md` — a short "Website" section: lives in `website/`, deployed by `pages.yml` on pushes to `main`.
- `AGENTS.md` — add `website/` to the project layout block (one line).
- `plans/PLAN.md` — one line in the history/roadmap noting v1.33 (website).

## Order of work

1. Copy and resize images (block above); note the pixel sizes.
2. Write `styles.css`, `index.html`, `privacy.html`, `.nojekyll`, `website/README.md`.
3. Preview locally: `python3 -m http.server -d website 8000` and load `http://localhost:8000/` and
   `/privacy.html`; check light + dark and widths 375 / 768 / 1280. Check every image loads (no 404s).
4. Add `pages.yml`, update `tests.yml`.
5. Update `README.md`, `AGENTS.md`, `plans/PLAN.md`.
6. Commit on the branch, push, open a PR to `main`.

## Definition of done

- `website/` opens directly in a browser and via a local static server with no console errors or 404s.
- Page reads well at 375 px (no horizontal scroll), 768 px and 1280 px, in light and dark mode.
- Accent colour is `#2F6BEA`; no external requests (fonts, scripts, analytics) at all.
- No mention of iCloud "sync"; App Store badge with a "Coming soon" note and the comment on how to link it.
- `website/images/` under ~2.5 MB.
- `pages.yml` triggers only on pushes to `main` touching `website/**` (or the workflow itself) plus manual
  dispatch; `tests.yml` ignores `website/**`.
- No changes under `Timelane/`, `TimelaneTests/` or the Xcode project.
