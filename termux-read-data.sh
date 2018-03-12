#!/usr/bin/env bash

# number of parts to scan for
num=14

declare -A parts

while [ "${#parts[@]}" -ne "${num}" ] ; do
  new=$(termux-clipboard-get)
  idx="${new%:*}"
  data="${new#*:}"
  if [ ! -z "${idx}" ] && [ ! -z "${data}" ] ; then
    parts["${idx}"]="${data}"
  fi
done

# reassemble for base64 nicely
b64str=""
for ((ct=1 ; ct <= num ; ct++)) ; do
  b64str="${b64str}${parts[$(printf '%02d' "${ct}")]}"
done

echo "${b64str}" | fold -w 76
