# brand/ – white-label assets

Everything that makes `app-ble.html` look like an **IoME** product lives in
two places, and nowhere else:

1. **This folder** – the image assets and the web app manifest.
2. **The token block** at the top of the `<style>` in `app-ble.html`, marked
   `BRAND TOKENS`: colours, radii and font stacks as CSS custom properties on
   `:root` (light values, then the dark overrides). The Google Fonts `<link>`
   just above it loads the faces the font stacks name.

To re-brand, replace the files here and edit that block. Nothing else in the
page refers to a colour, font or logo directly.

| File | Used as | Notes |
| --- | --- | --- |
| `wordmark.svg` | Logo in the top bar | Pure outlines, no font needed. Any aspect ratio works; it is scaled to the height set by `--wordmark-h`. Colour is baked into the file on purpose (the wordmark's colour is part of the mark), so supply a version that reads on both the light and dark `--paper`. |
| `heart.svg` | "Connected" live dot | Used as a CSS mask and tinted with `--brand`, so its own fill does not matter. Swap in any small silhouette (a dot, a logo mark). |
| `icon.svg`, `icon-512.png`, `icon-192.png` | Favicon, apple-touch-icon, device avatar on the page, home-screen icon | **Placeholder** – a flat bear drawn on the brand ground. Replace with the real product icon, keeping the 512 box, the rounded-square ground and an opaque background (iOS squares it off; Android masks it). |
| `manifest.webmanifest` | Add-to-home-screen name, colours and icons | `name` / `short_name`, `background_color` (splash) and `theme_color` are brand values too. Paths are relative to this folder. |

The source of truth for the IoME assets is the private
[KiranMystery/iome](https://github.com/KiranMystery/iome) repo
(`logo/iome-logo.svg` is `wordmark.svg` here; the heart is the `heart` path
from the same file). Palette from its README: primary `#DB9558`, secondary
`#1C1714`, white `#FFFFFF`; the paper, mute and accent values come from the
iome.uk site styles.

Nothing product-specific is here: the bear's name, the paw control, the UUIDs
and the Bluetooth code stay in `app-ble.html`.
