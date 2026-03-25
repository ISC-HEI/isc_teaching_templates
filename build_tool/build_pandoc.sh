#!/bin/bash
VERSION="1.0.2"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR="."
TEMPLATE="isc_lab.tex"

BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"
printf "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}║  ISC Documents Toolchain             ║${RESET}\n"
printf "${BOLD}${CYAN}║  Version ${YELLOW}%-28s${CYAN}║${RESET}\n" "${VERSION}"
printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}\n"

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":i:n:tho:" option; do
   case $option in
      i) # Input file
         input="$OPTARG"         
         ;;
      n) # Working directory
         DIR="$OPTARG"
         ;;
      t) # ORAL EXAM TEMPLATE
         echo "- Using oral exam template"
         TEMPLATE="isc_oral_exam.tex"
         ;;
      h) # not yet implemented         
         echo "For building an oral exam using the specific template switch, -t"
         exit
         ;;
      o) # Destination of PDF file        
         DEST_PDF="$OPTARG"
         ;;
      \?) # Invalid option
         echo "Error: invalid option"
         exit;;
   esac
done

if ([ -z "$input" ]); then
   file=("$DIR"/*.md)
   input=${file[0]}       
fi

if [ -z "$input" ]; then
    echo "No .md file found in $DIR"
    exit 1
fi

echo "- Compiling file '${input}'"
input=$(basename "$input")
output=${input/'.md'/'.pdf'}

pushd "$DIR" || exit

# Creating the document, using XeTex as engine
# We also pass the current script directory path for pandoc to find the template. We also require to pass the toolchain directory for including the image once. For this reason, we pass the location of the directory as a variable (which is not escaped by pandoc, and not as a metadata (which is the same as the values given in the YAML header of the .md))
pandoc "${input}" -o "${output}" --pdf-engine=xelatex --from markdown+tex_math_dollars+raw_tex --template="$SCRIPT_DIR/$TEMPLATE" --listings -V colorlinks --number-sections --variable=TOOLCHAINPATH:"$SCRIPT_DIR" --metadata=DRAFT:false --metadata=GENERATORVERSION:"$VERSION" #--verbose

if [ -n "$DEST_PDF" ]; then    
   echo "- Output generated in ${output} and copied to PDF directory ${DEST_PDF}"   
   cp "${output}" "${DEST_PDF}"
else 
   echo "- Output generated in ${output}"
fi

popd || exit