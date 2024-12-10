#!/bin/sh

# Get named arguments
. utils/parse_args.sh "$@"

# Check required args
if [ ! "$url" ]; then
  echo "Missing required args. Usage: ./utils/check_connection.sh --url=localhost:8080"
  exit 1
else
  url=$(eval echo "$url")
fi

# Check connection
for i in {1..20}; do
  if curl -s "$url" > /dev/null; then
    echo "Connection successfully established at $url!"
    exit 0
  fi
  echo "Waiting for connection at $url ..."
  sleep 1
done
echo "Failed to establish connection at $url!"
exit 1