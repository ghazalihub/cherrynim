#!/bin/bash
set -e

export PATH=/home/jules/.nimble/bin:$PATH

echo "Compiling all tutorials..."
for f in tutorial_nim/tut*.nim; do
  echo "Compiling $f"
  nim c --path:. "$f"
done

function test_url() {
  local url=$1
  local expected=$2
  local name=$3

  fuser -k 8080/tcp || true
  ./tutorial_nim/$name &
  PID=$!
  sleep 3
  RESPONSE=$(curl -s "$url")
  kill $PID
  wait $PID 2>/dev/null || true

  if [[ "$RESPONSE" == *"$expected"* ]]; then
    echo "$name OK"
  else
    echo "$name FAILED: expected '$expected' in '$RESPONSE'"
    exit 1
  fi
}

echo "Verifying tutorials..."
test_url "http://127.0.0.1:8080" "Hello World!" "tut01_helloworld"
test_url "http://127.0.0.1:8080/show_msg" "Hello world!" "tut02_expose_methods"
test_url "http://127.0.0.1:8080/greetUser?name=Jules" "Hello Jules" "tut03_get_and_post"
test_url "http://127.0.0.1:8080/joke/" "Perl file" "tut04_complex_site"
test_url "http://127.0.0.1:8080/remi" "User: remi" "tut06_default_method"

echo "All tests passed successfully!"
