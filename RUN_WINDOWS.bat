@echo off
setlocal

cd /d "%~dp0"
set "PROJECT_DIR=%CD%"
set "CONFIG_FILE=%PROJECT_DIR%\config.xlsx"

echo ============================================================
echo Spectre Cytometry Pipeline
echo ============================================================
echo Project: %PROJECT_DIR%
echo Config : %CONFIG_FILE%
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

if not exist "%CONFIG_FILE%" (
  echo ERROR: config.xlsx was not found next to RUN_WINDOWS.bat.
  echo.
  pause
  exit /b 1
)

echo Using Rscript:
echo %RSCRIPT%
echo.

"%RSCRIPT%" --vanilla "%PROJECT_DIR%\scripts\run_from_config.R" "%CONFIG_FILE%"
set "STATUS=%ERRORLEVEL%"

echo.
if "%STATUS%"=="0" (
  echo Spectre run completed successfully.
) else (
  echo Spectre run failed. Please read the message above.
)
echo.
pause
exit /b %STATUS%
