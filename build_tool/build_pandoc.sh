#!/bin/bash
VERSION="1.3.2"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR="."
TEMPLATE="isc_lab.tex"
ENGINE=""
PANDOC_EXTRA=()

# --typst / -y hands the whole job over to the Typst engine. This is done
# before anything else so that only one banner is printed, and before the
# catch-all below that forwards unknown options to pandoc -- pandoc would
# choke on --typst.
ARGS=()
USE_TYPST=false
for a in "$@"; do
   case "$a" in
      --typst|-y) USE_TYPST=true ;;
      *) ARGS+=("$a") ;;
   esac
done
if [ "$USE_TYPST" = true ]; then
   exec "$SCRIPT_DIR/build_typst.sh" ${ARGS[@]+"${ARGS[@]}"}
fi
set -- ${ARGS[@]+"${ARGS[@]}"}

BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"
printf "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}║  ISC Documents Toolchain             ║${RESET}\n"
printf "${BOLD}${CYAN}║  Version ${YELLOW}%-28s${CYAN}║${RESET}\n" "${VERSION}"
printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}\n"

usage() {
   cat <<EOF
Usage: $(basename "$0") [options] [file.md]

  -i FILE            input markdown file (or give it as a positional argument)
  -n DIR             working directory (default: .)
  -o DEST            copy the resulting PDF to DEST
  -t                 use the oral exam template instead of the lab one
  --typst, -y        build with Typst instead of LaTeX (see build_typst.sh)
  -e ENGINE          LaTeX engine to use (xelatex, lualatex, pdflatex, ...)
  --pdf-engine=ENG   same as -e (long form also accepted as: --pdf-engine ENG)
  -h                 this help

Any other option is forwarded as-is to pandoc.
If no engine is given, xelatex is used when available, otherwise the first
of lualatex / pdflatex found on the system is used.
EOF
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
while [ $# -gt 0 ]; do
   case "$1" in
      -i) input="$2"; shift 2 ;;
      -i*) input="${1#-i}"; shift ;;
      -n) DIR="$2"; shift 2 ;;
      -n*) DIR="${1#-n}"; shift ;;
      -o) DEST_PDF="$2"; shift 2 ;;
      -o*) DEST_PDF="${1#-o}"; shift ;;
      -e) ENGINE="$2"; shift 2 ;;
      -e*) ENGINE="${1#-e}"; shift ;;
      --pdf-engine=*) ENGINE="${1#--pdf-engine=}"; shift ;;
      --pdf-engine) ENGINE="$2"; shift 2 ;;
      -t) echo "- Using oral exam template"; TEMPLATE="isc_oral_exam.tex"; shift ;;
      -h|--help) usage; exit 0 ;;
      --) shift; while [ $# -gt 0 ]; do PANDOC_EXTRA+=("$1"); shift; done ;;
      -*) # unknown option: hand it over to pandoc untouched
         PANDOC_EXTRA+=("$1"); shift ;;
      *) # positional argument: the input file
         if [ -z "$input" ]; then input="$1"; else PANDOC_EXTRA+=("$1"); fi
         shift ;;
   esac
done

############################################################
# Minimum pandoc version                                   #
############################################################
# The typst template targets the writer of pandoc 3.6 and later: 3.6 dropped
# the `definitions.typst` data template that older templates included, and
# changed what the typst writer emits. Older pandocs fail with a confusing
# "Could not find data file" instead, so they are caught here.
PANDOC_MIN="3.9"
command -v pandoc > /dev/null 2>&1 || {
   printf "${RED}- Error: pandoc not found in PATH.${RESET}\n"
   exit 1
}
PANDOC_VERSION=$(pandoc --version | head -1 | awk '{print $2}')
if [ "$(printf '%s\n' "$PANDOC_MIN" "$PANDOC_VERSION" | sort -V | head -1)" != "$PANDOC_MIN" ]; then
   printf "${RED}- Error: pandoc %s is too old, %s or later is required.${RESET}\n" \
      "$PANDOC_VERSION" "$PANDOC_MIN"
   exit 1
fi

############################################################
# Select the LaTeX engine                                  #
############################################################
if [ -n "$ENGINE" ]; then
   if ! command -v "$ENGINE" > /dev/null 2>&1; then
      printf "${RED}- Error: engine '%s' not found in PATH${RESET}\n" "$ENGINE"
      exit 1
   fi
else
   for candidate in xelatex lualatex pdflatex; do
      if command -v "$candidate" > /dev/null 2>&1; then
         ENGINE="$candidate"
         break
      fi
   done
   if [ -z "$ENGINE" ]; then
      printf "${RED}- Error: no LaTeX engine found (tried xelatex, lualatex, pdflatex).${RESET}\n"
      printf "  Install one of them or select it explicitly with -e / --pdf-engine.\n"
      exit 1
   fi
   if [ "$ENGINE" != "xelatex" ]; then
      printf "${YELLOW}- Warning: xelatex not found, falling back to %s${RESET}\n" "$ENGINE"
   fi
fi
echo "- Using engine '${ENGINE}'"

if [ -z "$input" ]; then
   file=("$DIR"/*.md)
   input=${file[0]}
fi

if [ -z "$input" ]; then
    echo "No .md file found in $DIR"
    exit 1
fi

# The input may be given either as a path, or as a name relative to -n DIR
if [ ! -f "$input" ] && [ ! -f "$DIR/$input" ]; then
    echo "Input file '$input' not found"
    exit 1
fi

# If the input was given as a path and no working directory was set, use its
# directory (the compilation happens inside the document directory).
if [ "$DIR" = "." ] && [ "$(dirname "$input")" != "." ]; then
   DIR=$(dirname "$input")
fi

echo "- Compiling file '${input}'"
input=$(basename "$input")
output=${input/'.md'/'.pdf'}

pushd "$DIR" > /dev/null || exit

# Creating the document, using the selected TeX engine.
# We also pass the current script directory path for pandoc to find the template. We also require to pass the toolchain directory for including the image once. For this reason, we pass the location of the directory as a variable (which is not escaped by pandoc, and not as a metadata (which is the same as the values given in the YAML header of the .md))
pandoc "${input}" -o "${output}" --pdf-engine="${ENGINE}" --from markdown+tex_math_dollars+raw_tex --template="$SCRIPT_DIR/$TEMPLATE" --lua-filter="$SCRIPT_DIR/lua_filters/callouts.lua" --listings -V colorlinks --number-sections --variable=TOOLCHAINPATH:"$SCRIPT_DIR" --metadata=DRAFT:false --metadata=GENERATORVERSION:"$VERSION" "${PANDOC_EXTRA[@]}"
status=$?

if [ $status -ne 0 ]; then
   printf "${RED}- Compilation failed (pandoc exit code %s)${RESET}\n" "$status"
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
