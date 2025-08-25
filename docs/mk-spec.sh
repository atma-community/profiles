#!/usr/bin/env bash 

pandoc \
  -o build/spec.html \
  -H assets/tufte.html \
  -H assets/mermaid.html \
  -H assets/fontawesome.html \
  -H assets/prism.html \
  --template assets/template.html \
  --lua-filter assets/filters.lua \
  --standalone \
  --number-sections \
  spec.md
