@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Bibliotheque - Lecteur video + sous-titres

set "script=%~dp0gerer-bibliotheque.ps1"
if not exist "%script%" (
  echo.
  echo Erreur : gerer-bibliotheque.ps1 est introuvable.
  echo Il doit rester dans le meme dossier que ce lanceur.
  pause
  exit /b 1
)

:menu
cls
echo.
echo   LECTEUR VIDEO + SOUS-TITRES - BIBLIOTHEQUE
echo   ==========================================
echo.
echo   1. Ouvrir la bibliotheque dans l'Explorateur
echo   2. Ajouter plusieurs videos (le .srt du meme nom est ajoute automatiquement)
echo   3. Ajouter une video et choisir son fichier .srt
echo   4. Enlever des videos
echo   5. Publier sur GitHub (pour l'iPad et l'iPhone)
echo   0. Fermer
echo.
set "choice="
set /p "choice=Votre choix : "

if "%choice%"=="1" goto openLibrary
if "%choice%"=="2" goto addBatch
if "%choice%"=="3" goto addGuided
if "%choice%"=="4" goto removeBatch
if "%choice%"=="5" goto publish
if "%choice%"=="0" exit /b 0
goto menu

:openLibrary
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" -Action open-library
goto menu

:addBatch
cls
echo.
echo   AJOUTER PLUSIEURS VIDEOS
echo.
echo   Selectionnez les videos .mp4 (Ctrl ou Maj pour en prendre plusieurs).
echo   Le .srt dont le nom commence par celui de la video, dans le meme dossier,
echo   est ajoute automatiquement (exemple : ma-video.mp4 + ma-video.fr.srt).
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" -Action add-batch
echo.
pause
goto menu

:addGuided
cls
echo.
echo   AJOUTER UNE VIDEO ET SON FICHIER .SRT
echo.
echo   Choisissez la video, puis son fichier de sous-titres.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" -Action add-guided
echo.
pause
goto menu

:removeBatch
cls
echo.
echo   ENLEVER DES VIDEOS
echo.
echo   Cochez les videos a enlever de la bibliotheque, puis validez.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" -Action remove-batch
echo.
pause
goto menu

:publish
cls
echo.
echo   PUBLIER SUR GITHUB
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" -Action publish
echo.
pause
goto menu
