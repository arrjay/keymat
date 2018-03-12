#!/usr/bin/env bash

cat << _EOF_
This script will read the android clipboard via termux-api and _should_
import a gpg public key for your keyring.
_EOF_

read -n 1 -s -r -p "Press any key to start reading clipboard"
./termux-read-data.sh | base64 -d > pubkey.gpg
gpg2 --import pubkey.gpg
