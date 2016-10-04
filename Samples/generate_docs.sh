#!/bin/bash

# Run Jazzy, allowing undocumented functions to be "Undocumented."
`jazzy --no-skip-undocumented`

# For each file documented in the docs folder...
filenames=`find ./docs/Classes -type f`
# Create a file that is either a function name with context, or a tag containing the text
# "Undocumented." Cut these lines down so the function names are (more) human-readable, and less
# HTML tags with irrelevant auto-generated names.
for filename in $filenames; do
  `grep 'a class.*Blockly\|Undocumented' $filename |
    sed -- 's/<a class.*\/s://g' |
    sed -- 's/^.*Blockly/Blockly/g' |
    sed -- 's/ //g' |
    sed -- 's/[0-9]/ /g' |
    sed -- 's/[A-Z][A-Z].*[ _]/ /g' |
    sed -- 's/">//g' |
    sed -- 's/<\/a>//g' >> rawUndocumented.txt`
done

filename="rawUndocumented.txt"
list=""
foundNewFunction=false
printf "\n\nThe following new functions have been found:\n\n"
# Run through the list of function names/undocumented tags.
while read nextLine; do
  # If the next line is followed by "Undocumented," then it's an undocumented function.
  if [[ "$nextLine" == *"Undocumented"* ]]; then
    # Save the name & context of the current function to a new file.
    `echo "$currentLine" >> newUndocumented.txt`
    # If the function is new, then print it to the user, and mark that a newly-undocumented function
    # has been found.
    if [[ ! `grep "$currentLine" undocumented.txt` ]]; then
      foundNewFunction=true
      echo "$currentLine"
    fi
  fi 
  currentLine="$nextLine"
done < $filename
rm rawUndocumented.txt

# If a newly-undocumented function was found, ask whether we want to acknowledge that, and keep the
# new list of undocumented functions, or abort (hopefully to fix them.)
if $foundNewFunction; then
  while $foundNewFunction; do
    printf "\n"
    read -p "Keep the new undocumented functions? (y/n) " yn
    case $yn in
        [Yy]* )
          mv newUndocumented.txt undocumented.txt
          foundNewFunction=false;;
        [Nn]* )
          rm newUndocumented.txt
          exit;;
        * )
          echo "Please answer yes or no.";;
    esac
  done
else
  echo "No new functions found!"
  rm newUndocumented.txt
fi

# If newly-undocumented functions were accepted, or weren't found, regenerate the docs without
# undocumented functions.
`jazzy`
