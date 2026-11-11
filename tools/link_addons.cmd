@echo off
rem Links the family's addons into the game with directory junctions, so edits show after /reload.
rem   link_addons.cmd          create the links that are missing
rem   link_addons.cmd unlink   remove the links (only the links: the repository's folders stay)
rem   link_addons.cmd relink   remove them, then link this repository's folders (after moving it)
rem The game's folder is KALI_GAME's when set, as for the Python tools.
setlocal
set "REPO=%~dp0.."
if defined KALI_GAME (set "DST=%KALI_GAME%\Interface\AddOns") else set "DST=c:\devel\World of Warcraft\_forever_\Interface\AddOns"
if /i "%1"=="relink" (
    call "%~f0" unlink
    call "%~f0"
    exit /b 0
)
for %%A in (KaLiQuest KaLiQuest_Tests KaLiQuest_Probe) do call :one %%A "%REPO%\quest\addon" %1
for %%A in (KaLiRecipe KaLiRecipe_Tests KaLiRecipe_Probe) do call :one %%A "%REPO%\recipe\addon" %1
exit /b 0

:one
if /i "%3"=="unlink" (
    rem rmdir without /s removes a junction, never what it points to, and refuses a real folder that isn't empty.
    if exist "%DST%\%1" rmdir "%DST%\%1" && echo removed link %1
    exit /b 0
)
if exist "%DST%\%1" (
    echo %1 already exists in AddOns, left as it is
    exit /b 0
)
mklink /J "%DST%\%1" "%~2\%1"
exit /b 0
