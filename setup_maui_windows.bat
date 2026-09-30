@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Konfiguracja .NET MAUI - Windows

cd /d "%~dp0"

echo ============================================================
echo   KONFIGURACJA .NET MAUI - WINDOWS DESKTOP
echo ============================================================
echo.
echo Skrypt:
echo - sprawdzi wersje .NET SDK,
echo - w razie potrzeby zainstaluje .NET 10 SDK,
echo - ustawi projekt pod .NET 9 albo .NET 10,
echo - ustawi Windows jako jedyny target,
echo - zainstaluje workload maui-windows,
echo - wyczysci bin i obj,
echo - wykona restore i build,
echo - utworzy run_windows.bat.
echo.

rem ============================================================
rem 1. Uprawnienia administratora
rem ============================================================

net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Potrzebne sa uprawnienia administratora.
    echo [INFO] Uruchamiam skrypt ponownie jako administrator...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
    exit /b
)

rem ============================================================
rem 2. Szukanie projektu
rem ============================================================

set "PROJECT="

if exist "%~dp0MauiApp3\MauiApp3.csproj" set "PROJECT=%~dp0MauiApp3\MauiApp3.csproj"
if not defined PROJECT if exist "%~dp0MauiApp3.csproj" set "PROJECT=%~dp0MauiApp3.csproj"

if not defined PROJECT (
    for /r "%~dp0" %%F in (*.csproj) do (
        if not defined PROJECT set "PROJECT=%%F"
    )
)

if not defined PROJECT (
    echo [BLAD] Nie znaleziono pliku .csproj.
    echo.
    echo Umiesc ten plik BAT w katalogu repozytorium
    echo albo bezposrednio w katalogu projektu.
    goto :ERROR
)

for %%F in ("!PROJECT!") do (
    set "PROJECT_DIR=%%~dpF"
    set "PROJECT_NAME=%%~nxF"
)

echo [OK] Znaleziono projekt:
echo      !PROJECT!
echo.

rem ============================================================
rem 3. Sprawdzenie .NET SDK
rem ============================================================

where dotnet >nul 2>&1

if errorlevel 1 (
    echo [BRAK] Nie znaleziono .NET SDK.
    echo [INFO] Instaluje .NET 10 SDK...
    call :INSTALL_DOTNET10
    if errorlevel 1 goto :ERROR
)

call :REFRESH_DOTNET_PATH

where dotnet >nul 2>&1
if errorlevel 1 (
    echo [BLAD] Polecenie dotnet nadal nie jest dostepne.
    echo [INFO] Uruchom ponownie komputer i odpal skrypt jeszcze raz.
    goto :ERROR
)

set "DOTNET_VERSION="
for /f "tokens=*" %%V in ('dotnet --version 2^>nul') do set "DOTNET_VERSION=%%V"

if not defined DOTNET_VERSION (
    echo [BLAD] Nie udalo sie odczytac wersji .NET SDK.
    goto :ERROR
)

for /f "tokens=1 delims=." %%M in ("!DOTNET_VERSION!") do set "DOTNET_MAJOR=%%M"

echo [OK] Wykryto .NET SDK: !DOTNET_VERSION!
echo.

rem ============================================================
rem 4. Dobor targetu
rem ============================================================

if "!DOTNET_MAJOR!"=="9" (
    set "NET_MAJOR=9"
    set "TFM=net9.0-windows10.0.19041.0"
    goto :CONFIGURE_PROJECT
)

if !DOTNET_MAJOR! GEQ 10 (
    set "NET_MAJOR=10"
    set "TFM=net10.0-windows10.0.19041.0"
    goto :CONFIGURE_PROJECT
)

echo [INFO] Wykryto starszy SDK: !DOTNET_VERSION!
echo [INFO] Instaluje .NET 10 SDK...

call :INSTALL_DOTNET10
if errorlevel 1 goto :ERROR

call :REFRESH_DOTNET_PATH

set "DOTNET_VERSION="
for /f "tokens=*" %%V in ('dotnet --version 2^>nul') do set "DOTNET_VERSION=%%V"

if not defined DOTNET_VERSION (
    echo [BLAD] Nie udalo sie odczytac .NET po instalacji.
    goto :ERROR
)

for /f "tokens=1 delims=." %%M in ("!DOTNET_VERSION!") do set "DOTNET_MAJOR=%%M"

if !DOTNET_MAJOR! LSS 10 (
    echo [BLAD] Po instalacji aktywny jest nadal SDK !DOTNET_VERSION!.
    echo [INFO] Uruchom ponownie komputer i odpal skrypt jeszcze raz.
    goto :ERROR
)

set "NET_MAJOR=10"
set "TFM=net10.0-windows10.0.19041.0"

rem ============================================================
rem 5. Konfiguracja projektu
rem ============================================================

:CONFIGURE_PROJECT

echo ============================================================
echo Konfiguracja projektu dla !TFM!
echo ============================================================
echo.

set "BACKUP=!PROJECT!.before-maui-setup.bak"

if not exist "!BACKUP!" (
    copy /y "!PROJECT!" "!BACKUP!" >nul
    echo [OK] Utworzono kopie .csproj:
    echo      !BACKUP!
) else (
    echo [INFO] Kopia .csproj juz istnieje - nie nadpisuje jej.
)

set "MAUI_PROJECT=!PROJECT!"
set "MAUI_TFM=!TFM!"
set "MAUI_NET_MAJOR=!NET_MAJOR!"

powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand CgAkAEUAcgByAG8AcgBBAGMAdABpAG8AbgBQAHIAZQBmAGUAcgBlAG4AYwBlACAAPQAgACcAUwB0AG8AcAAnAAoAJABwACAAPQAgACQAZQBuAHYAOgBNAEEAVQBJAF8AUABSAE8ASgBFAEMAVAAKACQAdABmAG0AIAA9ACAAJABlAG4AdgA6AE0AQQBVAEkAXwBUAEYATQAKACQAbQBhAGoAbwByACAAPQAgACQAZQBuAHYAOgBNAEEAVQBJAF8ATgBFAFQAXwBNAEEASgBPAFIACgAkAGMAIAA9ACAAWwBJAE8ALgBGAGkAbABlAF0AOgA6AFIAZQBhAGQAQQBsAGwAVABlAHgAdAAoACQAcAApAAoACgBpAGYAIAAoACQAYwAgAC0AbQBhAHQAYwBoACAAJwA8AFQAYQByAGcAZQB0AEYAcgBhAG0AZQB3AG8AcgBrAHMAPgBbAF4APABdACoAPAAvAFQAYQByAGcAZQB0AEYAcgBhAG0AZQB3AG8AcgBrAHMAPgAnACkAIAB7AAoAIAAgACAAIAAkAGMAIAA9ACAAWwByAGUAZwBlAHgAXQA6ADoAUgBlAHAAbABhAGMAZQAoAAoAIAAgACAAIAAgACAAIAAgACQAYwAsAAoAIAAgACAAIAAgACAAIAAgACcAPABUAGEAcgBnAGUAdABGAHIAYQBtAGUAdwBvAHIAawBzAD4AWwBeADwAXQAqADwALwBUAGEAcgBnAGUAdABGAHIAYQBtAGUAdwBvAHIAawBzAD4AJwAsAAoAIAAgACAAIAAgACAAIAAgACgAJwA8AFQAYQByAGcAZQB0AEYAcgBhAG0AZQB3AG8AcgBrAHMAPgAnACAAKwAgACQAdABmAG0AIAArACAAJwA8AC8AVABhAHIAZwBlAHQARgByAGEAbQBlAHcAbwByAGsAcwA+ACcAKQAKACAAIAAgACAAKQAKAH0ACgBlAGwAcwBlAGkAZgAgACgAJABjACAALQBtAGEAdABjAGgAIAAnADwAVABhAHIAZwBlAHQARgByAGEAbQBlAHcAbwByAGsAPgBbAF4APABdACoAPAAvAFQAYQByAGcAZQB0AEYAcgBhAG0AZQB3AG8AcgBrAD4AJwApACAAewAKACAAIAAgACAAJABjACAAPQAgAFsAcgBlAGcAZQB4AF0AOgA6AFIAZQBwAGwAYQBjAGUAKAAKACAAIAAgACAAIAAgACAAIAAkAGMALAAKACAAIAAgACAAIAAgACAAIAAnADwAVABhAHIAZwBlAHQARgByAGEAbQBlAHcAbwByAGsAPgBbAF4APABdACoAPAAvAFQAYQByAGcAZQB0AEYAcgBhAG0AZQB3AG8AcgBrAD4AJwAsAAoAIAAgACAAIAAgACAAIAAgACgAJwA8AFQAYQByAGcAZQB0AEYAcgBhAG0AZQB3AG8AcgBrAD4AJwAgACsAIAAkAHQAZgBtACAAKwAgACcAPAAvAFQAYQByAGcAZQB0AEYAcgBhAG0AZQB3AG8AcgBrAD4AJwApAAoAIAAgACAAIAApAAoAfQAKAGUAbABzAGUAIAB7AAoAIAAgACAAIAB0AGgAcgBvAHcAIAAnAE4AaQBlACAAegBuAGEAbABlAHoAaQBvAG4AbwAgAFQAYQByAGcAZQB0AEYAcgBhAG0AZQB3AG8AcgBrACAAYQBuAGkAIABUAGEAcgBnAGUAdABGAHIAYQBtAGUAdwBvAHIAawBzACAAdwAgAHAAbABpAGsAdQAgAGMAcwBwAHIAbwBqAC4AJwAKAH0ACgAKAGkAZgAgACgAJABtAGEAagBvAHIAIAAtAGUAcQAgACcAOQAnACkAIAB7AAoAIAAgACAAIAAkAGMAIAA9ACAAWwByAGUAZwBlAHgAXQA6ADoAUgBlAHAAbABhAGMAZQAoAAoAIAAgACAAIAAgACAAIAAgACQAYwAsAAoAIAAgACAAIAAgACAAIAAgACcAKAA8AFAAYQBjAGsAYQBnAGUAUgBlAGYAZQByAGUAbgBjAGUAXABzACsASQBuAGMAbAB1AGQAZQA9ACIATQBpAGMAcgBvAHMAbwBmAHQAXAAuAEUAeAB0AGUAbgBzAGkAbwBuAHMAXAAuAEwAbwBnAGcAaQBuAGcAXAAuAEQAZQBiAHUAZwAiAFwAcwArAFYAZQByAHMAaQBvAG4APQAiACkAMQAwAFwALgBbAF4AIgBdACoAKAAiACkAJwAsAAoAIAAgACAAIAAgACAAIAAgACcAJAB7ADEAfQA5AC4AMAAuADAAJAB7ADIAfQAnAAoAIAAgACAAIAApAAoACgAgACAAIAAgACQAYwAgAD0AIABbAHIAZQBnAGUAeABdADoAOgBSAGUAcABsAGEAYwBlACgACgAgACAAIAAgACAAIAAgACAAJABjACwACgAgACAAIAAgACAAIAAgACAAJwAoAD8AbQApAF4AXABzACoAPABNAGEAdQBpAFgAYQBtAGwASQBuAGYAbABhAHQAbwByAD4AUwBvAHUAcgBjAGUARwBlAG4APAAvAE0AYQB1AGkAWABhAG0AbABJAG4AZgBsAGEAdABvAHIAPgBcAHMAKgBcAHIAPwBcAG4APwAnACwACgAgACAAIAAgACAAIAAgACAAJwAnAAoAIAAgACAAIAApAAoAfQAKAAoAWwBJAE8ALgBGAGkAbABlAF0AOgA6AFcAcgBpAHQAZQBBAGwAbABUAGUAeAB0ACgAJABwACwAIAAkAGMALAAgACgATgBlAHcALQBPAGIAagBlAGMAdAAgAFQAZQB4AHQALgBVAFQARgA4AEUAbgBjAG8AZABpAG4AZwAoACQAZgBhAGwAcwBlACkAKQApAAoAVwByAGkAdABlAC0ASABvAHMAdAAgACgAJwBbAE8ASwBdACAAVABhAHIAZwBlAHQAIABwAHIAbwBqAGUAawB0AHUAOgAgACcAIAArACAAJAB0AGYAbQApAAoA

if errorlevel 1 (
    echo [BLAD] Nie udalo sie zmodyfikowac pliku .csproj.
    goto :ERROR
)

echo.

rem ============================================================
rem 6. Instalacja MAUI dla Windows
rem ============================================================

echo ============================================================
echo Instalacja workloadu MAUI dla Windows
echo ============================================================
echo.

dotnet workload install maui-windows

if errorlevel 1 (
    echo.
    echo [BLAD] Instalacja workloadu maui-windows nie powiodla sie.
    goto :ERROR
)

echo [OK] Workload maui-windows jest gotowy.
echo.

rem ============================================================
rem 7. Czyszczenie starych artefaktow
rem ============================================================

echo ============================================================
echo Czyszczenie bin i obj
echo ============================================================
echo.

if exist "!PROJECT_DIR!bin" (
    rmdir /s /q "!PROJECT_DIR!bin"
    echo [OK] Usunieto bin.
)

if exist "!PROJECT_DIR!obj" (
    rmdir /s /q "!PROJECT_DIR!obj"
    echo [OK] Usunieto obj.
)

rem ============================================================
rem 8. Restore
rem ============================================================

echo.
echo ============================================================
echo dotnet restore
echo ============================================================
echo.

dotnet restore "!PROJECT!"

if errorlevel 1 (
    echo.
    echo [BLAD] dotnet restore nie powiodl sie.
    goto :ERROR
)

echo [OK] Restore zakonczony.
echo.

rem ============================================================
rem 9. Build
rem ============================================================

echo ============================================================
echo Build Windows
echo ============================================================
echo.

dotnet build "!PROJECT!" -f !TFM!

if errorlevel 1 (
    echo.
    echo [BLAD] Build projektu nie powiodl sie.
    goto :ERROR
)

echo [OK] Projekt zbudowal sie poprawnie.
echo.

rem ============================================================
rem 10. run_windows.bat
rem ============================================================

set "RUN_BAT=!PROJECT_DIR!run_windows.bat"

> "!RUN_BAT!" echo @echo off
>>"!RUN_BAT!" echo setlocal
>>"!RUN_BAT!" echo chcp 65001 ^>nul
>>"!RUN_BAT!" echo cd /d "%%~dp0"
>>"!RUN_BAT!" echo echo Uruchamianie aplikacji MAUI dla Windows...
>>"!RUN_BAT!" echo echo.
>>"!RUN_BAT!" echo dotnet build -t:Run -f !TFM! "%%~dp0!PROJECT_NAME!"
>>"!RUN_BAT!" echo echo.
>>"!RUN_BAT!" echo if errorlevel 1 echo [BLAD] Nie udalo sie uruchomic aplikacji.
>>"!RUN_BAT!" echo pause

echo [OK] Utworzono:
echo      !RUN_BAT!
echo.

rem ============================================================
rem 11. Podsumowanie
rem ============================================================

echo ============================================================
echo GOTOWE
echo ============================================================
echo.
echo Wersja .NET:
dotnet --version
echo.
echo Target:
echo !TFM!
echo.
echo Komenda do uruchomienia:
echo.
echo dotnet build -t:Run -f !TFM! "!PROJECT_NAME!"
echo.
echo Mozesz tez uruchomic:
echo.
echo run_windows.bat
echo.
echo Android NIE byl instalowany ani konfigurowany.
echo.
pause
exit /b 0

rem ============================================================
rem FUNKCJE
rem ============================================================

:INSTALL_DOTNET10

where winget >nul 2>&1
if errorlevel 1 (
    echo [BLAD] Nie znaleziono WinGet.
    echo [INFO] Zainstaluj recznie .NET 10 SDK x64:
    echo https://dotnet.microsoft.com/download/dotnet/10.0
    exit /b 1
)

winget install --id Microsoft.DotNet.SDK.10 --exact --source winget --accept-package-agreements --accept-source-agreements

if errorlevel 1 (
    echo [BLAD] Nie udalo sie zainstalowac .NET 10 SDK przez WinGet.
    exit /b 1
)

exit /b 0

:REFRESH_DOTNET_PATH

if exist "%ProgramFiles%\dotnet\dotnet.exe" (
    set "DOTNET_ROOT=%ProgramFiles%\dotnet"
    set "PATH=%ProgramFiles%\dotnet;%PATH%"
)

exit /b 0

:ERROR
echo.
echo ============================================================
echo WYSTAPIL BLAD
echo ============================================================
echo.
echo Przeczytaj komunikat wyzej.
echo Skrypt zostal zatrzymany, zeby nie ukryc problemu.
echo.
pause
exit /b 1
