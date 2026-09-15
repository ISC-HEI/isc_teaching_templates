#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Same --typst / -y switch as build_pandoc.sh, applied to the whole batch.
ENGINE=""
for a in "$@"; do
  case "$a" in
    --typst|-y) ENGINE="--typst" ;;
  esac
done
BUILD_CMD="./build_pandoc.sh $ENGINE -n"

if parallel --version &> /dev/null; then
  echo "Building all PDF files in parallel..."
  USE_PARALLEL=1
else
  >&2 echo "WARNING: gnu parallel not found"
  echo "Building all PDF files..."
  USE_PARALLEL=0
fi

pushd "$SCRIPT_DIR" || exit 1
dirs=(../???-*)

if [[ USE_PARALLEL -eq 1 ]]; then
  parallel --progress --bar --eta "$BUILD_CMD" ::: "${dirs[@]}"
else
  for d in "${dirs[@]}"
  do
    $BUILD_CMD "$d"
  done
fi

popd || exit 1
