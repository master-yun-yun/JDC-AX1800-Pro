#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../wrt"
echo ">>> 回退到 gettext-full host 可正常构建的版本 ac9a97e..."
git reset --hard ac9a97e
echo ">>> 回退完成，当前 HEAD:"
git log -1 --oneline
