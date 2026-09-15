#!/bin/bash
# Typst counterpart of build_pandoc.sh. Same interface, same input files,
# same output name -- only the rendering engine differs.
#
# The intermediate .typ is kept next to the Markdown on purpose: it is the
# only way to debug a layout problem, and `typst compile --watch` on it
# gives a sub-second edit loop. Add *.typ to .gitignore if you don't want
# it versioned.
VERSION="1.0.0"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR="."
TEMPLATE="$SCRIPT_DIR/typst/isc_lab.typ"
LOGO="$SCRIPT_DIR/figs/ISC Logo inline black v3.pdf"
KEEP_TYP=true
PANDOC_EXTRA=()

BOLD="\033[1m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"
printf "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}║  ISC Documents Toolchain -- Typst    ║${RESET}\n"
printf "${BOLD}${CYAN}║  Version ${RED}%-28s${CYAN}║${RESET}\n" "${VERSION}"
printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}\n"

usage() {
   cat <<EOF
Usage: $(basename "$0") [options] [file.md]

  -i FILE            input markdown file (or give it as a positional argument)
  -n DIR             working directory (default: .)
  -o DEST            copy the resulting PDF to DEST
  -c                 remove the intermediate .typ file after compiling
  -h                 this help

Any other option is forwarded as-is to pandoc.
EOF
}

while [ $# -gt 0 ]; do
   case "$1" in
      -i) input="$2"; shift 2 ;;
      -i*) input="${1#-i}"; shift ;;
      -n) DIR="$2"; shift 2 ;;
      -n*) DIR="${1#-n}"; shift ;;
      -o) DEST_PDF="$2"; shift 2 ;;
      -o*) DEST_PDF="${1#-o}"; shift ;;
      -c) KEEP_TYP=false; shift ;;
      -h|--help) usage; exit 0 ;;
      --) shift; while [ $# -gt 0 ]; do PANDOC_EXTRA+=("$1"); shift; done ;;
      -*) PANDOC_EXTRA+=("$1"); shift ;;
      *) if [ -z "$input" ]; then input="$1"; else PANDOC_EXTRA+=("$1"); fi
         shift ;;
   esac
done

command -v typst > /dev/null 2>&1 || {
   printf "${RED}- Error: typst not found in PATH.${RESET}\n"
   exit 1
}

if [ -z "$input" ]; then
   file=("$DIR"/*.md)
   input=${file[0]}
fi

if [ -z "$input" ]; then
    echo "No .md file found in $DIR"
    exit 1
fi

if [ ! -f "$input" ] && [ ! -f "$DIR/$input" ]; then
    echo "Input file '$input' not found"
    exit 1
fi

if [ "$DIR" = "." ] && [ "$(dirname "$input")" != "." ]; then
   DIR=$(dirname "$input")
fi

echo "- Compiling file '${input}'"
input=$(basename "$input")
intermediate=${input/'.md'/'.typ'}
output=${input/'.md'/'.pdf'}

pushd "$DIR" > /dev/null || exit

# 1. Markdown -> Typst. The two filters do the parts the writer cannot:
#    callouts.lua emits the ISC boxes, typst-compat.lua rescues the raw
#    LaTeX (\newpage, \label, \ref) the sources contain.
pandoc "${input}" -o "${intermediate}" --to typst --standalone \
   --from markdown+tex_math_dollars+raw_tex \
   --template="$TEMPLATE" \
   --lua-filter="$SCRIPT_DIR/lua_filters/callouts.lua" \
   --lua-filter="$SCRIPT_DIR/lua_filters/typst-compat.lua" \
   --number-sections \
   --variable=logo:"$LOGO" \
   --variable=TOOLCHAINPATH:"$SCRIPT_DIR" \
   --metadata=DRAFT:false \
   --metadata=GENERATORVERSION:"$VERSION" "${PANDOC_EXTRA[@]}"
status=$?

if [ $status -ne 0 ]; then
   printf "${RED}- Markdown to Typst conversion failed (pandoc exit code %s)${RESET}\n" "$status"
   popd > /dev/null || exit
   exit $status
fi

# 2. Typst -> PDF. --root / is required because the logo is referenced by
#    an absolute path inside the toolchain directory.
typst compile --root / "${intermediate}" "${output}"
status=$?

if [ "$KEEP_TYP" = false ]; then
   rm -f "${intermediate}"
fi

if [ $status -ne 0 ]; then
   printf "${RED}- Compilation failed (typst exit code %s)${RESET}\n" "$status"
   popd > /dev/null || exit
   exit $status
fi

if [ -n "$DEST_PDF" ]; then
   echo "- Output generated in ${output} and copied to PDF directory ${DEST_PDF}"
   cp "${output}" "${DEST_PDF}"
else
   echo "- Output generated in ${output}"
fi

popd > /dev/null || exit
