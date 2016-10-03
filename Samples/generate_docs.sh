#!/bin/bash

`jazzy --no-skip-undocumented`

filenames=`find ./docs/Classes -type f`
for filename in $filenames ; do  
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
while read nextLine ; do
  if [[ "$nextLine" == *"Undocumented"* ]] ; then
    `echo "$currentLine" >> newUndocumented.txt`
    if [[ ! `grep "$currentLine" undocumented.txt` ]];then
      foundNewFunction=true
      echo "$currentLine"
    fi
  fi 
  currentLine="$nextLine"
done < $filename
rm rawUndocumented.txt

if $foundNewFunction ;then
  while $foundNewFunction; do
    printf "\n"
    read -p "Keep the new undocumented functions? (y/n) " yn
    case $yn in
        [Yy]* )
          mv newUndocumented.txt undocumented.txt;
          foundNewFunction=false;;
        [Nn]* )
          rm newUndocumented.txt;
          exit;;
        * )
          echo "Please answer yes or no.";;
    esac
  done
else
  echo "No new functions found!"
  rm newUndocumented.txt
fi

`jazzy`
