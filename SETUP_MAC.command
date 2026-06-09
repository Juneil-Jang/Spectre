#!/bin/bash
set -u

cd "$(dirname "$0")" || exit 1
PROJECT_DIR="$(pwd)"

echo "============================================================"
echo "Spectre Environment Setup"
echo "============================================================"
echo "Project: $PROJECT_DIR"
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

echo "Using Rscript:"
echo "$RSCRIPT"
echo
echo "This can take a while the first time."
echo

"$RSCRIPT" --vanilla "$PROJECT_DIR/scripts/setup_renv_core.R"
if [ "$?" -ne 0 ]; then
  echo
  echo "Setup failed. Please read the message above."
  echo
  read -r -n 1 -p "Press any key to close..."
  echo
  exit 1
fi

"$RSCRIPT" --vanilla "$PROJECT_DIR/scripts/check_renv_core.R"
if [ "$?" -ne 0 ]; then
  echo
  echo "Package check failed. Please read the message above."
  echo
  read -r -n 1 -p "Press any key to close..."
  echo
  exit 1
fi

echo
echo "Setup completed successfully."
echo "You can now double-click RUN_MAC.command."
echo
read -r -n 1 -p "Press any key to close..."
echo
