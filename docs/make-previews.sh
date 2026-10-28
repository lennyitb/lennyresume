#!/bin/sh
# Render resume.tex in every palette to docs/<palette>.png for the README,
# plus a larger walnut docs/preview.png and close-ups of its mosaic and term bar.
# Needs LuaLaTeX and pdftoppm (poppler). Run from the repository root.
set -e
tmp=$(mktemp -d)
for p in walnut harbor forest plum graphite; do
  lualatex -interaction=batchmode -output-directory="$tmp" -jobname="$p" \
    "\AddToHook{begindocument/before}{\usepalette{$p}}\input{resume}" >/dev/null
  pdftoppm -r 200 -png -singlefile "$tmp/$p.pdf" "docs/$p"
done
pdftoppm -r 300 -png -singlefile "$tmp/walnut.pdf" docs/preview

# inset <left> <top> <right> <bottom> <name>: a region of the page, in points
# from the top left, at 600 dpi. Move these if the chart moves.
inset() {
  pdftoppm -r 600 -png -singlefile \
    -x $(($1 * 600 / 72)) -y $(($2 * 600 / 72)) \
    -W $((($3 - $1) * 600 / 72)) -H $((($4 - $2) * 600 / 72)) \
    "$tmp/walnut.pdf" "docs/$5"
}
inset 48 149 324 259 inset-mosaic
inset 46 260 322 312 inset-terms
rm -rf "$tmp"
