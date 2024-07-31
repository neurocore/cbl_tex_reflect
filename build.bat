@echo off
setlocal enabledelayedexpansion

set "src_folder=source"
set "exe_name=cbl_tex_reflect"
set "files="
set "short="

for %%i in (%src_folder%/*.d) do (
    set "files=!files!%src_folder%/%%i "
    set "short=!short!%%i "
)

echo building '%src_folder%' -^> %exe_name%_debug.exe (!short:~0,-1!)...
dmd %files% -mixin=mixins.txt -color -debug -of=%exe_name%_debug.exe
rem ldc2 %files% -d-debug -of=%exe_name%_debug.exe

if %ERRORLEVEL% NEQ 1 (
    echo done
    echo.
    %exe_name%_debug.exe lumps/sprites lumps/textures
)
