#!/bin/sh

# Reusable script that gets named arguments from the command line
# Args format is --key=value
# Source this script at the top of other scripts:
# . /path/to/this/script/parse-args.sh "$@"

for ARGUMENT in "$@";
do
  key=$(echo "$ARGUMENT" | cut -f1 -d= )
  key_length=$(echo "$key" | awk '{print length}')
  key=$(echo "$key" | cut -d'-' -f3)
  value=$(echo "$ARGUMENT" | cut -c$((key_length + 2))-)
  export "$key"="$value"
done