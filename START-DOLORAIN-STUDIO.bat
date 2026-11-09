@echo off
setlocal EnableExtensions
title Dolorain Studio Custom
set "ROOT=C:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable"
set "COMFY=%ROOT%\ComfyUI"
set "EXT=%COMFY%\custom_nodes\dolorain_studio"
set "BASE=https://raw.githubusercontent.com/AmanDolorain/Dolorain-Studio-Custom/main/custom_nodes/dolorain_studio"

if not exist "%ROOT%\python_embeded\python.exe" (
  echo ERROR: ComfyUI portable was not found at:
  echo %ROOT%
  echo Edit ROOT in this file if your installation is elsewhere.
  pause
  exit /b 1
)
if not exist "%EXT%\web" mkdir "%EXT%\web"
if not exist "%EXT%\web" (
  echo ERROR: Cannot create extension directory.
  pause
  exit /b 1
)
echo Checking Dolorain Studio extension updates...
curl.exe -fsSL --connect-timeout 5 --max-time 20 "%BASE%/web/dolorain.js" -o "%TEMP%\dolorain-studio-new.js"
if not errorlevel 1 (
  for %%F in ("%TEMP%\dolorain-studio-new.js") do if %%~zF GTR 100 (
    if exist "%EXT%\web\dolorain.js" (
      copy /Y "%EXT%\web\dolorain.js" "%EXT%\web\dolorain.js.rollback" >nul
    )
    copy /Y "%TEMP%\dolorain-studio-new.js" "%EXT%\web\dolorain.js" >nul
    echo Extension updated.
  )
) else (
  echo Update unavailable. Using installed extension if present.
)
if not exist "%EXT%\__init__.py" (
  curl.exe -fsSL --connect-timeout 5 --max-time 20 "%BASE%/__init__.py" -o "%EXT%\__init__.py"
)
if not exist "%EXT%\__init__.py" (
  echo ERROR: Extension initialization file missing.
  pause
  exit /b 1
)
if not exist "%EXT%\web\dolorain.js" (
  echo ERROR: Extension script missing.
  pause
  exit /b 1
)
del /q "%TEMP%\dolorain-studio-new.js" >nul 2>nul
echo Starting ComfyUI...
start "" "http://127.0.0.1:8188"
cd /d "%ROOT%"
"%ROOT%\python_embeded\python.exe" -s "%COMFY%\main.py" --cpu --windows-standalone-build --enable-manager
echo ComfyUI has stopped.
pause
