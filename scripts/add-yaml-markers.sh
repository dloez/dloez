#!/bin/bash

# Script to add YAML document start markers (---) to files that don't have them
# Usage: ./scripts/add-yaml-markers.sh [--dry-run] [directory]

set -e

# Default values
DRY_RUN=false
TARGET_DIR="homelab"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

echo "Checking YAML files in: $TARGET_DIR"
if [ "$DRY_RUN" = true ]; then
  echo "Running in dry-run mode - no files will be modified"
fi

yaml_files=$(find "$TARGET_DIR" -name "*.yaml" -o -name "*.yml" 2>/dev/null | \
  grep -v "flux-system/" | \
  grep -v "talos/" | \
  grep -v "terraform/" || true)

if [ -z "$yaml_files" ]; then
  echo "No YAML files found in $TARGET_DIR"
  exit 0
fi

modified_count=0
checked_count=0

while IFS= read -r file; do
  if [ -f "$file" ] && [ -s "$file" ]; then
    checked_count=$((checked_count + 1))
    first_content_line=$(grep -n '^[^#]' "$file" | head -1 | cut -d: -f2 | sed 's/^[[:space:]]*//' 2>/dev/null || echo "")
    
    if [ "$first_content_line" != "---" ]; then
      echo "Processing: $file"
      
      insert_line=1
      while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
          insert_line=$((insert_line + 1))
        else
          break
        fi
      done < "$file"
      
      if [ "$DRY_RUN" = true ]; then
        echo "  → Would add --- at line $insert_line"
      else
        if [ $insert_line -eq 1 ]; then
          sed -i '1i---' "$file"
        else
          sed -i "${insert_line}i---" "$file"
        fi
        echo "  ✓ Added --- to $file"
      fi
      
      modified_count=$((modified_count + 1))
    fi
  fi
done <<< "$yaml_files"

echo ""
echo "Summary:"
echo "  Files checked: $checked_count"
if [ "$DRY_RUN" = true ]; then
  echo "  Files that would be modified: $modified_count"
else
  echo "  Files modified: $modified_count"
fi
