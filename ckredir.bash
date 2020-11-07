#!/bin/bash
# ckredir.bash -- check redirects

function get_redirs() {
  LOCS=$(curl -LISs --retry-max-time 9 "$1" | \
    grep -i ^Location: | perl -pe 's,^Location:.,,gi' | \
    tr -d \\r)
  echo $LOCS | tr ' ' '\n' | tail -n 1
}

function normalize_url() {
  URL=$(echo $1 | tr -d \\r)
  echo $URL | grep -q -s :// || URL=http://"$URL"
  PATHETC=$(echo $URL | sed -e 's,.*://,,g')
  echo $PATHETC | grep -q -s / || URL="$URL"/
  echo $URL
}

function check_match() {
  ONE="$1"
  TWO="$2"
  [ "$ONE" == "$TWO" ] && echo MATCH && return

  ONE_SEC=$(echo $ONE | sed -e 's,^http://,https://,g')
  TWO_SEC=$(echo $TWO | sed -e 's,^http://,https://,g')
  [ "$ONE_SEC" == "$TWO_SEC" ] && echo HTTPS && return

  # FIXME: add support for multiple locations (matching redir 2 of 3, etc.)
  echo NO_MAT
}

function strip_to_path() {
  URL=$(echo $1 | sed -e 's,^http://,,' | sed -e 's,https://,,g')
  echo $URL | grep -q -s ^/ && echo $URL && return

  # Assume that e.g. 'blog' (no dot) is a path (/blog), not a hostname.
  echo $URL | grep -q -s -v '\.' && echo /$URL && return

  # Strip hostname.
  URL=$(echo $URL | sed -e 's,^[a-z0-9.-]*,,')

  # Add leading /, if needed.
  echo $URL | grep -q -s ^/ || echo -n /

  echo $URL
}

function check_redirs() {
  ACTUAL=$(get_redirs "$FROM")
  TO=$(normalize_url "$TO")
  MATCH=$(check_match "$TO" "$ACTUAL")
  echo $MATCH: $FROM '=>' $TO \(actual: $ACTUAL\)
}

function check_redirs_post() {
  # TODO: tally different match kinds.
  cat
}

function generate_redirs() {
  FROM=$(strip_to_path "$FROM")
  TO=$(normalize_url "$TO")
  echo Redirect 301 $FROM $TO
}

function generate_redirs_post() {
  sort -sr -k 3,3
}

function show_help() {
  echo $1: need -g \(generate redirs\) or -c \(check redirs\) >&2
  echo usage: $1 \[-g\|-c\] \< /path/to/redirs.csv >&2
}

function main() {
  COUNT=0
  IFS="$IFS,"
  while read FROM TO garbage; do
    echo "$FROM" | grep -q -s ^$ && continue
    "$1" "$FROM" "$TO"
    ((COUNT++))

    if [ "$COUNT" -gt "$HI_COUNT" ]; then
      exit 0
    fi
  done
}

HI_COUNT=10000
OP=

[ "$1" == "-g" ] && OP=generate_redirs
[ "$1" == "-c" ] && OP=check_redirs

[ "$OP" == "" ] && show_help "$(basename $0)" && exit 0

main "$OP" | "$OP"_post

