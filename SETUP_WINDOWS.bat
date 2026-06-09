@echo off
setlocal

cd /d "%~dp0"
set "PROJECT_DIR=%CD%"

echo ============================================================
echo Spectre Environment Setup
echo ============================================================
echo Project: %PROJECT_DIR%
echo.

set "RSCRIPT="
for /f "delims=" %%I in ('where Rscript.exe 2^>nul') do (
  if not defined RSCRIPT set "RSCRIPT=%%I"
)

if not defined RSCRIPT (
  for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$r = Get-ChildItem -Path 'C:\Program Files\R' -Filter Rscript.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName; if ($r) { $r }"`) do (
    set "RSCRIPT=%%I"
  )
)

if not defined RSCRIPT (
  echo ERROR: Rscript.exe was not found.
  echo Please install R 4.x from https://cloud.r-project.org/
  echo.
  pause
  exit /b 1
)

echo Using Rscript:
echo %RSCRIPT%
echo.
echo This can take a while the first time.
echo.

"%RSCRIPT%" --vanilla "%PROJECT_DIR%\scripts\setup_renv_core.R"
if errorlevel 1 (
  echo.
  echo Setup failed. Please read the message above.
  echo.
  pause
  exit /b 1
)

"%RSCRIPT%" --vanilla "%PROJECT_DIR%\scripts\check_renv_core.R"
if errorlevel 1 (
  echo.
  echo Package check failed. Please read the message above.
  echo.
  pause
  exit /b 1
)

echo.
echo Setup completed successfully.
echo You can now double-click RUN_WINDOWS.bat.
echo.
pause
