#!/usr/bin/env bash

case "$(uname -o 2>/dev/null)" in
  Android)
cat << _EOF_
This script will read the android clipboard via termux-api and _should_
import a gpg public key for your keyring.
_EOF_

read -n 1 -s -r -p "Press any key to start reading clipboard"
./termux-read-data.sh | base64 -d > paperkey.secret
  ;;
  *)
./zbarimg-read-data.sh private-ss.pdf | base64 -d > paperkey.secret
  ;;
esac

paperkey --pubring pubkey.gpg --secrets paperkey.secret --output seckey.gpg
