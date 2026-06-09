#!/bin/bash
set -u

cd "$(dirname "$0")" || exit 1
PROJECT_DIR="$(pwd)"
CONFIG_FILE="$PROJECT_DIR/config.xlsx"

echo "============================================================"
echo "Spectre Cytometry Pipeline"
echo "============================================================"
echo "Project: $PROJECT_DIR"
echo "Config : $CONFIG_FILE"
echo

if command -v Rscript >/dev/null 2>&1; then
  RSCRIPT="$(command -v Rscript)"
elif [ -x "/Library/Frameworks/R.framework/Resources/bin/Rscript" ]; then
  RSCRIPT="/Library/Frameworks/R.framework/Resources/bin/Rscript"
else
  echo "ERROR: Rscript was not found."
  echo "Please install R 4.x from https://cloud.r-project.org/"
  echo
  read -r -n 1 -p "Press any key to close..."
  echo
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: config.xlsx was not found next to RUN_MAC.command."
  echo
  read -r -n 1 -p "Press any key to close..."
  echo
  exit 1
fi

echo "Using Rscript:"
echo "$RSCRIPT"
echo

"$RSCRIPT" --vanilla "$PROJECT_DIR/scripts/run_from_config.R" "$CONFIG_FILE"
STATUS=$?

echo
if [ "$STATUS" -eq 0 ]; then
  echo "Spectre run completed successfully."
else
  echo "Spectre run failed. Please read the message above."
fi
echo
read -r -n 1 -p "Press any key to close..."
echo
exit "$STATUS"
