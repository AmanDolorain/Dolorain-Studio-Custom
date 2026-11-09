@echo off
setlocal
set "COMFY=C:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\ComfyUI"
if not exist "%COMFY%\custom_nodes" (
 echo ComfyUI custom_nodes directory not found: %COMFY%\custom_nodes
 pause
 exit /b 1
)
if exist "%COMFY%\custom_nodes\dolorain_studio" (
 echo Dolorain extension already exists. No overwrite performed.
 pause
 exit /b 1
)
xcopy "%~dp0custom_nodes\dolorain_studio" "%COMFY%\custom_nodes\dolorain_studio\" /E /I /Q
if errorlevel 1 (echo Installation copy failed. & pause & exit /b 1)
echo Dolorain extension copied. Restart ComfyUI and refresh Edge.
pause
