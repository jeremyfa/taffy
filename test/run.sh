#!/bin/bash
# Build and run the tests with Node.js.
# Usage: ./run.sh [fixturesDir] [--category <name>] [--filter <substring>] [--verbose] [--failures <file>]
# Set TAFFY_FIXTURES to the tests/xml folder of a taffy checkout to run all the fixtures.
set -e
cd "$(dirname "$0")"
HAXE="${HAXE:-haxe}"
"$HAXE" build.hxml
node bin/test.js "$@"
