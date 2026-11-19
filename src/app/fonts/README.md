# Fonts

Self-hosted with `next/font/local` (see `src/app/layout.tsx`), so visitors'
browsers never contact Google and builds don't need to reach Google Fonts.

| File | Font | Used for | Licence |
|---|---|---|---|
| `baloo-2-latin-700-normal.woff2`, `baloo-2-latin-800-normal.woff2` | Baloo 2 | Logo text, page titles, headings | SIL OFL 1.1 (`OFL-Baloo2.txt`) |
| `inter-latin-wght-normal.woff2` | Inter (variable, 100–900) | Body text and UI | SIL OFL 1.1 (`OFL-Inter.txt`) |

Files come from the Fontsource npm packages `@fontsource/baloo-2` and
`@fontsource-variable/inter` (Latin subset only). To update, download a newer
package with `npm pack`, copy the same files over these, and rebuild.
