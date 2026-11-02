#!/bin/bash
# Fails the job if app/main.c does not match .clang-format (Google style) in the repo root.
# CLANG_FORMAT lets CI pin a version: formatting output can differ between clang-format releases.
set -euo pipefail

CLANG_FORMAT="${CLANG_FORMAT:-clang-format}"
"$CLANG_FORMAT" --version
"$CLANG_FORMAT" --dry-run --Werror app/main.c
echo "Code style OK"
