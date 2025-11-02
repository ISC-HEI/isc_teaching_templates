#!/bin/bash
VERSION="1.0.7"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR="."
MATH_ENGINE="katex"
TOC=true
TEMPLATE="GitHub3.html5"

Help()
{
   # Display Help
   echo "Generate an HTML file from an MD file, from the ISC toolchain"
   echo "Version $VERSION, Pierre-André Mudry, 2024"
   echo
   echo "Syntax: build_html.sh [-n input_file] [-h] [-m math_engine] [-t] [-o output_file]"
   echo "options:"
   echo "h     Print this help."
   echo "n     Name of the file to compile."   
   echo "o     Destination directory of the PDF file (default, here)."
   echo "m     Math engine used. Options are mathjax, mathml, katex (default), webtex."
   echo "t     Disable table of contents generation in the HTML output."
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":x:m:o:n:th" option; do
   case ${option} in
      x ) 
         TEMPLATE="$OPTARG"
         echo "Using template $TEMPLATE"
         ;; 
      n ) # Enter a file name
         INPUT_FILE="$OPTARG"
         ;;
      h ) # not yet implemented
         Help
         exit 1
         ;;
      m ) # Math engine used
         MATH_ENGINE=$OPTARG
         echo "Using math engine $MATH_ENGINE"
         ;;         
      t ) # Disable toc generation
         TOC=false         
         ;;
      o ) # Destination directory of PDF file        
         DEST_PDF="$OPTARG"
         ;;
      \? ) # Invalid option
         echo "Error: invalid option -${OPTARG}"
         exit 1;;
   esac
done

shift $((OPTIND -1))

if [ -n "$INPUT_FILE" ]; then
    input="$INPUT_FILE"
    DIR=$(dirname "$input")
    input=$(basename "$input")
else
    file=("$DIR"/*.md)
    input=${file[0]}
    if [ -z "$input" ] || [ ! -f "$input" ]; then
        echo "No .md file found in $DIR"
        exit 1
    fi
fi

echo "Compiling file '${input}'"
output=${input/'.md'/'.html'}

pushd "$DIR" || exit

# --css="$SCRIPT_DIR/html_templates/sakura.css"
# options for maths is mathjax, mathml, katex, webtex
# mathml is fast but ugly. katex is fine

if $TOC; then
    pandoc "${input}" -o "${output}" --from markdown+tex_math_dollars+raw_tex+emoji --"${MATH_ENGINE}" --data-dir="$SCRIPT_DIR/html_templates" --template="${TEMPLATE}" --resource-path=".:$SCRIPT_DIR/html_templates" --toc --toc-depth=2 --embed-resources --standalone --strip-comments
else
    pandoc "${input}" -o "${output}" --from markdown+tex_math_dollars+raw_tex+emoji --"${MATH_ENGINE}" --data-dir="$SCRIPT_DIR/html_templates" --template="${TEMPLATE}" --resource-path=".:$SCRIPT_DIR/html_templates" --embed-resources --standalone --strip-comments
fi

if [ -n "$DEST_PDF" ]; then
   echo "Output generated in ${output} and copied to directory ${DEST_PDF}"   
   mv "${output}" "${DEST_PDF}"
else 
   echo "Output generated in ${output}" 
fi

popd || exit
