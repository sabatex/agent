#!/bin/bash

set -e

AGENT="node $(pwd)/index.js"
DATA=$(pwd)/node_modules/jkurwa/test/data
FILTER="$1"

key() {
  if [ "$1" = "" ]; then
    echo ""
  else
    echo --key "$DATA/$1"
  fi
}

decrypt () {
  $AGENT --decrypt $@
}

unwrap () {
  $AGENT --decrypt $@
}

assert () {
  echo FAIL. $@
  exit 1
}

testcase () {
  cd $DATA
  TEST="$1"; shift
  EXPECT_OUT="$1"; shift
  EXPECT_ERR="$1"; shift

  [ "$FILTER" != "" ] && [ "${TEST/#${FILTER}/}" == "$TEST" ] && return

  if diff <($@ 2>&1 1>/dev/null) $EXPECT_ERR ; then
    true
  else
    assert $TEST
  fi

  if diff <($@ 2>/dev/null) "$EXPECT_OUT"; then
    true
  else
    assert $TEST
  fi

  echo PASS. $TEST

  cd - > /dev/null
}

testcase \
  "Decrypt p7s message" \
  <(echo -n 123) \
  <(echo Encrypted) \
  "decrypt --input enc_message.p7 --key Key40A0.cer --cert SELF_SIGNED_ENC_40A0.cer --cert SELF_SIGNED_ENC_6929.cer"

testcase \
  "Decryption error when own cert is not supplied" \
  <(true) \
  <(echo Error occured during unwrap: ENOKEY) \
  "decrypt --input enc_message.p7 --key Key40A0.cer --cert SELF_SIGNED_ENC_6929.cer"

testcase \
  "Decryption error when sender cert is not supplied" \
  <(true) \
<(cat <<EOF
Encrypted
Error occured during unwrap: ENOCERT
EOF
) \
  "decrypt --input enc_message.p7 --key Key40A0.cer --cert SELF_SIGNED_ENC_40A0.cer"

testcase \
  "Decrypt transport message without sender ceritifcate" \
  <(echo -n 123) \
  <(echo Encrypted) \
  "decrypt --input enc_message.transport --key Key40A0.cer --cert SELF_SIGNED_ENC_40A0.cer"

testcase \
  "Decryption error when own cert is not supplied" \
  <(true) \
  <(echo Error occured during unwrap: ENOKEY) \
  "decrypt --input enc_message.transport --key Key40A0.cer"

testcase \
  "Unwrap signed message" \
  <(echo -n 123) \
  <(echo Signed-By: Very Much CA) \
  "unwrap --input message.p7"

testcase \
  "Unwrap signed transport message" \
  <(echo -n 123) \
  <(cat <<EOF
Sent-By-EDRPOU: 1234567891
Signed-By: Very Much CA
EOF
) \
  "unwrap --input message.transport"
