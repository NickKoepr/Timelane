# Timelane website

Static site (HTML + CSS, no build step, no dependencies, no external requests) for GitHub Pages.

- **Preview:** `python3 -m http.server -d website 8000` from the repo root, then open http://localhost:8000/.
- **Images:** copies of the raw window captures from `Tools/make-app-store-screenshots.sh` (`build/AppStoreScreenshots/raw/`). To refresh, run from the repo root:

  ```sh
  mkdir -p website/images
  for f in timeline entryForm projects overview trackedApps settings; do
    out=$(echo "$f" | sed -E 's/([A-Z])/-\1/g' | tr '[:upper:]' '[:lower:]')   # entryForm -> entry-form
    sips --resampleWidth 1600 "build/AppStoreScreenshots/raw/$f.png" --out "website/images/$out.png"
  done
  sips --resampleWidth 560 build/AppStoreScreenshots/raw/menuBar.png --out website/images/menu-bar.png
  cp Timelane/Assets.xcassets/AppIcon.appiconset/icon_256.png website/images/icon.png
  ```
  Then update the `width`/`height` attributes in `index.html` if the pixel sizes changed (`sips -g pixelWidth -g pixelHeight <file>`).
- **Deploy:** `.github/workflows/pages.yml` publishes `website/` on pushes to `main` that touch it. It needs a public repo (or a paid plan) and Settings > Pages > Source: GitHub Actions.
- **App Store badge:** Apple's official "Download on the Mac App Store" badge (`images/mac-app-store-black.svg`, `-white.svg` for dark mode; US-UK artwork from Apple's marketing resources). Use it unaltered. Each badge links to `https://apps.apple.com/app/idXXXXXXXXXX`, a placeholder: replace `idXXXXXXXXXX` with the App Store ID (header, hero and footer in `index.html`; header and footer in `privacy.html`).
