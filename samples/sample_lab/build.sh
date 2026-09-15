#!/bin/bash
# Builds this sample. Arguments are handed over to the toolchain, so
#   ./build.sh            renders with LaTeX
#   ./build.sh --typst    renders with Typst (preview)
if [ -z "$ISC_TOOLCHAIN" ]; then echo "ISC_TOOLCHAIN variable not set up. It must point to a valid ISC template repository. Exiting."; exit 1; fi

$ISC_TOOLCHAIN/build_pandoc.sh "$@"
