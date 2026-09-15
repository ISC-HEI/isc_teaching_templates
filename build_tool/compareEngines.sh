#!/bin/bash
# Renders the same Markdown source with both engines and puts the two
# results side by side, one PNG per page, so the Typst port can be checked
# against the LaTeX reference page by page.
#
#   ./compareEngines.sh path/to/lab.md [output_dir]
#
# Produces in the output directory (default: ./engine-comparison):
#   latex-NN.png   typst-NN.png   compare-NN.png   (LaTeX left, Typst right)
#
# Requires pdftoppm (poppler-utils) and, for the side-by-side montage,
# ImageMagick. Without ImageMagick the individual PNGs are still produced.
set -u

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DPI=${DPI:-110}

BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

if [ $# -lt 1 ]; then
   echo "Usage: $(basename "$0") path/to/file.md [output_dir]"
   exit 1
fi

INPUT=$1
OUT=${2:-$PWD/engine-comparison}

[ -f "$INPUT" ] || { printf "${RED}Input file '%s' not found${RESET}\n" "$INPUT"; exit 1; }
command -v pdftoppm > /dev/null 2>&1 || { printf "${RED}pdftoppm is required (poppler-utils)${RESET}\n"; exit 1; }

INPUT_DIR=$( cd -- "$( dirname -- "$INPUT" )" && pwd )
BASE=$( basename "$INPUT" .md )
mkdir -p "$OUT"

printf "${BOLD}${CYAN}Comparing engines on %s${RESET}\n" "$BASE"

# The two engines write the same file name, so each render is moved out of
# the way before the next one runs. The original PDF is put back at the end.
BACKUP=""
if [ -f "$INPUT_DIR/$BASE.pdf" ]; then
   BACKUP=$(mktemp)
   cp "$INPUT_DIR/$BASE.pdf" "$BACKUP"
fi

restore () {
   if [ -n "$BACKUP" ]; then
      cp "$BACKUP" "$INPUT_DIR/$BASE.pdf"
      rm -f "$BACKUP"
   fi
}
trap restore EXIT

printf "${YELLOW}- LaTeX${RESET}\n"
"$SCRIPT_DIR/build_pandoc.sh" -i "$INPUT" > "$OUT/latex.log" 2>&1 || {
   printf "${RED}  LaTeX build failed, see %s${RESET}\n" "$OUT/latex.log"; exit 1; }
cp "$INPUT_DIR/$BASE.pdf" "$OUT/latex.pdf"

printf "${YELLOW}- Typst${RESET}\n"
"$SCRIPT_DIR/build_typst.sh" -i "$INPUT" > "$OUT/typst.log" 2>&1 || {
   printf "${RED}  Typst build failed, see %s${RESET}\n" "$OUT/typst.log"; exit 1; }
cp "$INPUT_DIR/$BASE.pdf" "$OUT/typst.pdf"

rm -f "$OUT"/latex-*.png "$OUT"/typst-*.png "$OUT"/compare-*.png
pdftoppm -r "$DPI" -png "$OUT/latex.pdf" "$OUT/latex"
pdftoppm -r "$DPI" -png "$OUT/typst.pdf" "$OUT/typst"

lpages=$(pdfinfo "$OUT/latex.pdf" | awk '/^Pages/ {print $2}')
tpages=$(pdfinfo "$OUT/typst.pdf" | awk '/^Pages/ {print $2}')

printf "${BOLD}Pages: LaTeX %s | Typst %s${RESET}" "$lpages" "$tpages"
if [ "$lpages" = "$tpages" ]; then
   printf "  ${GREEN}(identique)${RESET}\n"
else
   printf "  ${RED}(différent)${RESET}\n"
fi

if command -v magick > /dev/null 2>&1 || command -v montage > /dev/null 2>&1; then
   for f in "$OUT"/latex-*.png; do
      n=$(basename "$f" .png); n=${n#latex-}
      t="$OUT/typst-$n.png"
      [ -f "$t" ] || continue
      if command -v magick > /dev/null 2>&1; then
         magick "$f" "$t" +append -bordercolor gray -border 2 "$OUT/compare-$n.png"
      else
         montage "$f" "$t" -tile 2x1 -geometry +2+2 "$OUT/compare-$n.png"
      fi
   done
   printf "${GREEN}Side-by-side pages in %s/compare-NN.png${RESET}\n" "$OUT"
else
   printf "${YELLOW}ImageMagick absent: pages séparées seulement (latex-NN.png / typst-NN.png)${RESET}\n"
fi
