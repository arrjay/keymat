#!/usr/bin/env bash

# settings
convert_fntopts="-font FreeMono -pointsize 18"
txtwidth="33"

# prereqs
gpg2=""
base64="base64"
split="split"

umask 077

qtype () { type "${@}" > /dev/null 2>&1 ; }

qtype gsplit  && split="gsplit"
qtype gpg2 && gpg2="gpg2"
macgpg2="/usr/local/MacGPG2/bin/gpg2"
[ -f "${macgpg2}" ] && gpg2="${macgpg2}"

# hmm. see if gpg is gpg2.
[ -z "${gpg2}" ] && { gpg --version | grep -q "gpg (GnuPG) 2" && gpg2="gpg" ; }

qtype gbase64 && base64="gbase64"
qtype gsplit  && split="gsplit"

qtype convert  || { echo "install ImageMagick" 1>&2 ; exit 1; }
qtype paperkey || { echo "install paperkey" 1>&2 ; exit 1; }

# we can do apg or pwgen, but I need _one_
qtype apg   && { mkpw () { apg -M SNCL -m 32 -x 32|head -n1; } ; }
qtype pwgen && { mkpw () { pwgen -s1 32 1; } ; }

qtype mkpw || { echo "Install apg or pwgen" 1>&2 ; exit 1; }

qtype qrencode || { echo "Install qrencode" 1>&2 ; exit 1; }

# directory handling
ttmpdir=$(mktemp -d)
export TMPDIR="${ttmpdir}"
OUTPUT="$(pwd)"
export OUTPUT

shred="rm -P"
# replace shred with os-specific rm call if needed
qtype shred && { shred="shred" ; }

# clean out all files zeroizing first, then rm dirs
clean_tmpdir () {
  cd / || exit 250
  if [ ! -z "${ttmpdir}" ] ; then
    find "${ttmpdir}" -type f -exec $shred {} \;
    rm -rf "${ttmpdir}"
  fi
}
trap clean_tmpdir EXIT SIGINT SIGTERM

# I want to get the current checkout data so run before cd
key_mail="zero.$(git rev-parse --short HEAD).$(date +%s)@gpg.arrjay.net"

# okay let's go drive gpg
cd "${ttmpdir}" || exit 250

mkdir .gnupg
export GNUPGHOME="${ttmpdir}/.gnupg"
{
  printf '%s\n' 'allow-loopback-pinentry'
} > "${GNUPGHOME}/gpg-agent.conf"

gpgpass=$(mkpw)

"${gpg2}" --gen-key --batch << _EOF_
Key-Type: eddsa
Key-Curve: Ed25519
Key-Usage: sign
Subkey-type: ecdh
Subkey-Curve: Curve25519
Subkey-Usage: encrypt
Name-Real: Store
Name-Email: ${key_mail}
Expire-Date: 0
Preferences: SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
Passphrase: ${gpgpass}
%commit
_EOF_

qrencode_pages () {
  local inputfile pagen qrpg file spacect
  inputfile="${1}"
  pagen=1
  spacect=$((txtwidth - 2))

  "${split}" "${inputfile}" -n 14 page_ < /dev/null
  cat - > page_zz
  for file in page_* ; do
    qrpg=$(mktemp)
    pagen=$((pagen + 1))
    printf '%02d:%s' "${pagen}" "$(<"${file}")" | qrencode -s 5 -l H -8 -o "${qrpg}"
    # shellcheck disable=SC2086
    convert "${qrpg}" -background white ${convert_fntopts} \
     label:"$(fold -w${txtwidth} < "${file}") $(printf '\n\n%-'${spacect}'s%02d\n' '' ${pagen})" \
     -gravity center -append "leaf/$(printf '%02d' "${pagen}").png"
    $shred "${file}"
  done

}

rot () {
  convert -set label '' -label '' -rotate "${@}"
}

layout_impositions () {
  mkdir ss ds
  rot 180 leaf/01.png ss/p1s1f03.png
  rot 180 leaf/02.png ss/p1s1f02.png
  rot 180 leaf/03.png ss/p1s1f01.png
  cp      leaf/04.png ss/p1s1f05.png
  cp      leaf/05.png ss/p1s1f06.png
  rot 180 leaf/06.png ss/p1s1f10.png
  rot 180 leaf/07.png ss/p1s1f09.png
  cp      leaf/08.png ss/p1s1f13.png
  cp      leaf/09.png ss/p1s1f14.png
  cp      leaf/10.png ss/p1s1f15.png
  cp      leaf/11.png ss/p1s1f16.png
  rot 180 leaf/12.png ss/p1s1f12.png
  rot 180 leaf/13.png ss/p1s1f11.png
  cp      leaf/14.png ss/p1s1f07.png
  cp      leaf/15.png ss/p1s1f08.png
  rot 180 leaf/16.png ss/p1s1f04.png

  rot  90 leaf/01.png ds/p1s2f7.png
  rot 270 leaf/02.png ds/p1s1f8.png
  rot 270 leaf/03.png ds/p1s1f2.png
  rot  90 leaf/04.png ds/p1s2f1.png
  rot 270 leaf/05.png ds/p1s2f2.png
  rot  90 leaf/06.png ds/p1s1f1.png
  rot  90 leaf/07.png ds/p1s1f7.png
  rot 270 leaf/08.png ds/p1s2f8.png
  rot 270 leaf/09.png ds/p1s2f6.png
  rot  90 leaf/10.png ds/p1s1f5.png
  rot  90 leaf/11.png ds/p1s1f3.png
  rot 270 leaf/12.png ds/p1s2f4.png
  rot  90 leaf/13.png ds/p1s2f3.png
  rot 270 leaf/14.png ds/p1s1f4.png
  rot 270 leaf/15.png ds/p1s1f6.png
  rot  90 leaf/16.png ds/p1s2f5.png

  montage ss/p1s1f*.png -tile 4x4 -geometry '425x578>+4+3' -set label '' -label '' ss.pdf

  montage ds/p1s1f*.png -tile 2x4 -geometry '578x452>+4+3' -set label '' -label '' ds/p1s1.png
  montage ds/p1s2f*.png -tile 2x4 -geometry '578x452>+4+3' -set label '' -label '' ds/p1s2.png

  convert ds/p1s?.png -quality 100 ds.pdf
}

makebook () {
  local t2

  t2=$(mktemp -d)

  pushd "${t2}" >/dev/null || exit 250

  "${gpg2}" --batch --passphrase-fd 0 --pinentry-mode loopback --export-secret-key "${key_mail}" <<<"${gpgpass}" | paperkey --output-type raw | "${base64}" -w0 > "sekrit"
  "${gpg2}" --export "${key_mail}"                                                                               | "${base64}" -w0 > "public"

  mkdir -p "sec/leaf" "pub/leaf"

  # shellcheck disable=SC2086
  convert -background white ${convert_fntopts} label:"$("${gpg2}" --keyid-format 0xLONG --list-keys --fingerprint "${key_mail}" | sed 's/ = /\n/' | fold -s -w50)" "page01.png"
  cp "page01.png" "sec/leaf/01.png"
  cp "page01.png" "pub/leaf/01.png"

  pushd sec >/dev/null || exit 250
  "${gpg2}" --batch --passphrase-fd 0 --pinentry-mode loopback --export-secret-key "${key_mail}" <<<"${gpgpass}" | paperkey --output-type raw | "${base64}" -w0 > "data"
  echo "${gpgpass}"                                                                                              | qrencode_pages "data"

  layout_impositions

  # validate qrencode worked
  zbarimg ss.pdf |sed -e '/^$/d' |sort > "decoded.qrc"
  sed -e '/^QR-Code:16:.*/d' -e 's/^QR-Code:[[:digit:]][[:digit:]]://' decoded.qrc | tr -d '\n' > decoded.data
  diff -q "data" "decoded.data"
  echo "private-key data follows: item 16 is the key's password"
  sed -e 's/^QR-Code://' decoded.qrc

  # now zap those files
  $shred "data"
  $shred "decoded.qrc"

  cp ss.pdf "${OUTPUT}/private-ss.pdf"
  cp ds.pdf "${OUTPUT}/private-ds.pdf"

  popd > /dev/null || exit 250

  pushd pub > /dev/null || exit 250
  "${gpg2}" --export "${key_mail}"                                         | "${base64}" -w0 > "data"
  echo "https://github.com/arrjay/keymat"                                  | qrencode_pages "data"

  layout_impositions

  # validate qrencode worked
  zbarimg ss.pdf |sed -e '/^$/d' -e '/^QR-Code:16:.*/d' |sort > "decoded.qrc"
  sed -e 's/^QR-Code:[[:digit:]][[:digit:]]://' decoded.qrc | tr -d '\n' > decoded.data
  diff -q "data" "decoded.data"
  echo "public key data"
  sed -e 's/^QR-Code://' decoded.qrc

  # now zap those files
  $shred "data"
  $shred "decoded.qrc"

  cp ss.pdf "${OUTPUT}/public-ss.pdf"
  cp ds.pdf "${OUTPUT}/public-ds.pdf"
}

makebook
