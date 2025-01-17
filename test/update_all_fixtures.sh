#!/bin/bash

set -euo pipefail

root="$PWD"

echo "Updating root fixtures"
echo

bazel run --config=cache //test/fixtures:update

for dir in examples/*/ ; do
    cd "$root/$dir"
    if [[ ! -f "WORKSPACE" || ! -d "test/fixtures" ]]; then
      continue
    fi

    echo
    echo "Updating \"${dir%/}\" fixtures"
    echo
    bazel run --config=cache //test/fixtures:update
done
