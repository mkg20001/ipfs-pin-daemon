#!/bin/bash

set -e

function contains() {
  match="$1"
  shift
  for e in "$@"; do
    if [ "$e" == "$match" ]; then
      return 0
    fi
  done
  return 1
}

DOMAIN_LIST="$1"
[ -z "$DOMAIN_LIST" ] && echo "Usage: $0 <domain-list> [<db-file>]"
DB_FILE="$2"
[ -z "$DB_LIST" ] && DB_FILE="$1.db"

DOMAINS=$(cat "$DOMAIN_LIST")

declare -a newpinnedhashes

do_pin() {
  echo "Pin $add..."
  if ipfs pin add -r --progress "$add"; then
    newpinnedhashes+=("$add")
  else
    echo "Pinning of $add failed! Re-trying later..."
  fi
}

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
    if ! contains "$curhash" "${newhashes[@]}"; then
      delhashes+=("$curhash")
    fi
  done

  for newhash in "${newhashes[@]}"; do # make a list of hashes to add
    if ! contains "$newhash" "${curhashes[@]}"; then
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
      do_pin
    done
  elif [ ! -z "${addhashes[*]}" ]; then
    for add in "${addhashes[@]}"; do
      do_pin
    done
    for hash in "${newhashes[@]}"; do
      if ! contains "$hash" "${addhashes[@]}"; then
        newpinnedhashes+=("$hash")
      fi
    done
  else
    for hash in "${newhashes[@]}"; do
      newpinnedhashes+=("$hash")
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
