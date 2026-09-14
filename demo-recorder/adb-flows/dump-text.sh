#!/usr/bin/env bash
source lib/adb-ui.sh
f=$(ui_dump)
grep -o '<node[^>]*text="[^"]*"[^>]*>' "$f" | sed -E 's/.*text="([^"]*)".*bounds="([^"]*)".*/\1 --> \2/'
