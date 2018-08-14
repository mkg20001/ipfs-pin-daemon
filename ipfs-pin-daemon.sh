#!/bin/bash

set -e

DOMAIN_LIST="$1"
[ -z "$DOMAIN_LIST" ] && echo "Usage: $0 <domain-list> [<db-file>]"
DB_FILE="$2"
[ -z "$DB_LIST" ] && DB_FILE="$1.db"

DOMAINS=$(cat "$DOMAIN_LIST")

loop() {
  newhashes=()
  for domain in $DOMAINS; do
    newhashes+=("$(ipfs dns $domain)")
  done

  if [ -e "$DB_FILE" ]; then
    curhashes=($(cat "$DB_FILE"))
  else
    curhashes=()
  fi
  delhashes=()
  addhashes=()

  for curhash in "${curhashes[@]}"; do # make list of hashes to delete
    hasMatch=false
    for newhash in "${newhashes[@]}"; do
      if [ "$newhash" == "$curhash" ]; then
        hasMatch=true
      fi
    done
    if ! $hasMatch; then
      delhashes+=("$curhash")
    fi
  done

  for newhash in "${newhashes[@]}"; do # make a list of hashes to add
    hasMatch=false
    for curhash in "${curhashes[@]}"; do
      if [ "$curhash" == "$newhash" ]; then
        hasMatch=true
      fi
    done
    if ! $hasMatch; then
      addhashes+=("$newhash")
    fi
  done

  echo "Hashes: ${newhashes[*]}"
  echo "Remove: ${delhashes[*]}"
  echo "Add: ${addhashes[*]}"

  for del in "${delhashes[@]}"; do
    echo "Unpin $del..."
    ipfs pin rm -r "$del"
  done

  newpinnedhashes=()

  if [ ! -z "${delhashes[*]}" ]; then
    for add in "${newhashes[@]}"; do # we need to re-pin EVERY hash as unpin might have recursivly removed some
    echo "Pin $add..."
    (ipfs pin add -r --progress "$add" && newpinnedhashes+=("$add")) || echo "Pinning of $add failed! Re-trying later..."
    done
  elif [ ! -z "${addhashes[*]}" ]; then
    for add in "${addhashes[@]}"; do
      echo "Pin $add..."
      (ipfs pin add -r --progress "$add" && newpinnedhashes+=("$add")) || echo "Pinning of $add failed! Re-trying later..."
    done
  fi

  echo "${newpinnedhashes[*]}" > "$DB_FILE"

  echo "Done!"
}

while true; do
  loop
  echo "Sleeping for 1m..."
  sleep 1m
done
