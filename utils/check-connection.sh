#!/bin/sh

# Get named arguments
. utils/parse-args.sh "$@"

# Check required args
if [ ! "$url" ]; then
  echo "Missing required args. Usage: ./utils/check-connection.sh --url=localhost:8080"
  exit 1
else
  url=$(eval echo "$url")
fi

# Set interval and max retries, if given.
if [ "$interval" ]; then
  INTERVAL=$interval
else
  INTERVAL=5
fi
if [ "$max_retries" ]; then
  MAX_RETRIES=$max_retries
else
  MAX_RETRIES=20
fi

# Use insecure connection, if --insecure=true
if [ "$insecure" ] && [ "$insecure" = "true" ]; then
  INSECURE='--insecure'
else
  INSECURE=''
fi

# Check connection
i=0
while [ $i -lt $MAX_RETRIES ]; do
  if curl -s $INSECURE "$url" > /dev/null; then
    echo "Connection successfully established at $url!"
    exit 0
  fi
  echo "Waiting for connection at $url ..."
  sleep $INTERVAL
  i=$(( i + 1 ))
done
echo "Failed to establish connection at $url!"
exit 1
