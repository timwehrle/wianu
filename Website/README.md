# Wianu website

Run `pnpm dev` from this directory. The site uses the TMDB token in `.env` for movie search and metadata.

To regenerate favicons from `Wianu/WianuLogo.icon`, install the SVG renderer once
with `brew install librsvg`, then run `python3 Scripts/export-logo.py` from the
repository root. This exports a light/dark SVG favicon, 16/32/48-pixel PNGs, a
multi-size `favicon.ico`, a 180-pixel Apple touch icon, and the GitHub logo assets.
The exports use the Icon Composer artwork, scale, position, and background colors;
Apple's rendered glass and shadow effects remain specific to the app icon.
