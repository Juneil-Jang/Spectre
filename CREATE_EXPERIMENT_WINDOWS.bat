@echo off
setlocal

cd /d "%~dp0"
set "PIPELINE_DIR=%CD%"

echo ============================================================
echo Create a Portable Spectre Experiment Folder
echo ============================================================
echo Pipeline folder:
echo %PIPELINE_DIR%
echo.
echo Enter the full path for the new experiment folder.
echo Example: C:\Users\YourName\Documents\Experiment_01
echo.
set /p "EXPERIMENT_DIR=Experiment folder path: "

if "%EXPERIMENT_DIR%"=="" (
  echo.
  echo ERROR: No experiment folder path was entered.
  echo.
  pause
  exit /b 1
)

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

echo.
echo Using Rscript:
echo %RSCRIPT%
echo.

"%RSCRIPT%" --vanilla "%PIPELINE_DIR%\scripts\create_experiment_folder.R" "%EXPERIMENT_DIR%"
set "STATUS=%ERRORLEVEL%"

echo.
if "%STATUS%"=="0" (
  echo Experiment folder created successfully.
) else (
  echo Experiment folder creation failed. Please read the message above.
)
echo.
pause
exit /b %STATUS%
