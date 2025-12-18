#!/usr/bin/env bash
set -euo pipefail

echo "Running tests..."
roc test package/DatabaseUrl.roc
