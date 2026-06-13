#!/bin/bash
set -u

cd "$(dirname "$0")" || exit 1
PIPELINE_DIR="$(pwd)"

echo "============================================================"
echo "Create a Portable Spectre Experiment Folder"
echo "============================================================"
echo "Pipeline folder:"
echo "$PIPELINE_DIR"
echo
echo "Enter the full path for the new experiment folder."
echo "Example: /Users/YourName/Documents/Experiment_01"
echo
read -r -p "Experiment folder path: " EXPERIMENT_DIR

if [ -z "$EXPERIMENT_DIR" ]; then
  echo
  echo "ERROR: No experiment folder path was entered."
  echo
  read -r -n 1 -p "Press any key to close..."
  echo
  exit 1
fi

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

echo
echo "Using Rscript:"
echo "$RSCRIPT"
echo

"$RSCRIPT" --vanilla "$PIPELINE_DIR/scripts/create_experiment_folder.R" "$EXPERIMENT_DIR"
STATUS=$?

echo
if [ "$STATUS" -eq 0 ]; then
  echo "Experiment folder created successfully."
else
  echo "Experiment folder creation failed. Please read the message above."
fi
echo
read -r -n 1 -p "Press any key to close..."
echo
exit "$STATUS"
