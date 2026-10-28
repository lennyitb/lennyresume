#!/bin/sh
# Render resume.tex in every palette to docs/<palette>.png for the README.
# Needs LuaLaTeX and pdftoppm (poppler). Run from the repository root.
set -e
tmp=$(mktemp -d)
for p in walnut harbor forest plum graphite; do
  lualatex -interaction=batchmode -output-directory="$tmp" -jobname="$p" \
    "\AddToHook{begindocument/before}{\usepalette{$p}}\input{resume}" >/dev/null
  pdftoppm -r 200 -png -singlefile "$tmp/$p.pdf" "docs/$p"
done
rm -rf "$tmp"
