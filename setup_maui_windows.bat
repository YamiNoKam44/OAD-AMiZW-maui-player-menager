@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Automatyczna konfiguracja .NET MAUI - Windows

cd /d "%~dp0"

echo ============================================================
echo        KONFIGURACJA .NET MAUI - WINDOWS
echo ============================================================
echo.
echo Skrypt automatycznie:
echo - wykryje zainstalowane SDK .NET 9 / 10,
echo - jesli trzeba, zainstaluje .NET 10 SDK,
echo - przypnie wybrane SDK przez global.json,
echo - ustawi projekt jako Windows-only,
echo - poprawi projekt dla .NET 9 lub .NET 10,
echo - zainstaluje workload MAUI,
echo - zrobi restore i build,
echo - utworzy run_windows.bat.
echo.

rem ============================================================
rem 1. Administrator
rem ============================================================

net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Potrzebne sa uprawnienia administratora.
    echo [INFO] Uruchamiam ponownie jako administrator...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
    exit /b
)

rem ============================================================
rem 2. Znalezienie projektu
rem ============================================================

set "PROJECT="

if exist "%~dp0MauiApp3\MauiApp3.csproj" (
    set "PROJECT=%~dp0MauiApp3\MauiApp3.csproj"
)

if not defined PROJECT if exist "%~dp0MauiApp3.csproj" (
    set "PROJECT=%~dp0MauiApp3.csproj"
)

if not defined PROJECT (
    for /r "%~dp0" %%F in (*.csproj) do (
        if not defined PROJECT set "PROJECT=%%F"
    )
)

if not defined PROJECT (
    echo [BLAD] Nie znaleziono zadnego pliku .csproj.
    echo.
    echo Umiesc setup_maui_windows.bat w katalogu repozytorium
    echo albo bezposrednio w katalogu projektu.
    goto :ERROR
)

for %%F in ("!PROJECT!") do (
    set "PROJECT_DIR=%%~dpF"
    set "PROJECT_NAME=%%~nxF"
)

echo [OK] Projekt:
echo      !PROJECT!
echo.

rem ============================================================
rem 3. Czy dotnet istnieje?
rem ============================================================

where dotnet >nul 2>&1

if errorlevel 1 (
    echo [BRAK] Nie znaleziono .NET SDK.
    echo [INFO] Instaluje .NET 10 SDK przez WinGet...
    call :INSTALL_DOTNET10
    if errorlevel 1 goto :ERROR

    call :REFRESH_PATH
)

where dotnet >nul 2>&1
if errorlevel 1 (
    echo [BLAD] Polecenie dotnet nadal nie jest dostepne.
    echo [INFO] Uruchom ponownie komputer, a potem ten skrypt.
    goto :ERROR
)

rem ============================================================
rem 4. Wybieramy SDK
rem
rem Nie uzywamy tutaj "dotnet --version", bo istniejacy global.json
rem moglby wymusic inna wersje.
rem Najpierw sprawdzamy wszystkie zainstalowane SDK.
rem ============================================================

set "SELECTED_SDK="
set "NET_MAJOR="

rem Preferujemy .NET 10, jesli jest zainstalowany.
for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /b "10\."') do (
    set "SELECTED_SDK=%%S"
    set "NET_MAJOR=10"
)

rem Jezeli nie ma 10, uzywamy .NET 9.
if not defined SELECTED_SDK (
    for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /b "9\."') do (
        set "SELECTED_SDK=%%S"
        set "NET_MAJOR=9"
    )
)

rem Jezeli nie ma ani 9, ani 10 - instalujemy 10.
if not defined SELECTED_SDK (
    echo [INFO] Nie znaleziono .NET 9 ani .NET 10.
    echo [INFO] Instaluje .NET 10 SDK...

    call :INSTALL_DOTNET10
    if errorlevel 1 goto :ERROR

    call :REFRESH_PATH

    for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /b "10\."') do (
        set "SELECTED_SDK=%%S"
        set "NET_MAJOR=10"
    )
)

if not defined SELECTED_SDK (
    echo [BLAD] Nie udalo sie znalezc odpowiedniego SDK po instalacji.
    goto :ERROR
)

echo [OK] Wybrane SDK: !SELECTED_SDK!
echo.

rem ============================================================
rem 5. global.json
rem
rem To wazne szczegolnie przy .NET 9.
rem Zapobiega sytuacji, w ktorej projekt net9 uruchamia sie
rem przypadkiem na SDK 10.
rem ============================================================

set "GLOBAL_JSON=%~dp0global.json"

> "!GLOBAL_JSON!" echo {
>>"!GLOBAL_JSON!" echo   "sdk": {
>>"!GLOBAL_JSON!" echo     "version": "!SELECTED_SDK!",
>>"!GLOBAL_JSON!" echo     "rollForward": "latestPatch"
>>"!GLOBAL_JSON!" echo   }
>>"!GLOBAL_JSON!" echo }

echo [OK] Utworzono global.json dla SDK !SELECTED_SDK!.

rem Teraz dotnet powinien korzystac z wybranego SDK.
set "ACTIVE_SDK="
for /f "tokens=*" %%V in ('dotnet --version 2^>nul') do set "ACTIVE_SDK=%%V"

if not defined ACTIVE_SDK (
    echo [BLAD] global.json wskazuje SDK, ktorego dotnet nie moze uruchomic.
    goto :ERROR
)

echo [OK] Aktywne SDK: !ACTIVE_SDK!
echo.

rem ============================================================
rem 6. Target Framework
rem ============================================================

if "!NET_MAJOR!"=="9" (
    set "TFM=net9.0-windows10.0.19041.0"
) else (
    set "TFM=net10.0-windows10.0.19041.0"
)

echo [OK] Target projektu: !TFM!
echo.

rem ============================================================
rem 7. Kopia .csproj
rem ============================================================

set "BACKUP=!PROJECT!.before-maui-setup.bak"

if not exist "!BACKUP!" (
    copy /y "!PROJECT!" "!BACKUP!" >nul
    echo [OK] Kopia projektu:
    echo      !BACKUP!
) else (
    echo [INFO] Kopia .csproj juz istnieje - nie nadpisuje jej.
)

echo.

rem ============================================================
rem 8. Modyfikacja .csproj
rem
rem Tworzymy zwykly tymczasowy plik PowerShell.
rem Bez EncodedCommand.
rem ============================================================

set "PSFILE=%TEMP%\maui_config_%RANDOM%_%RANDOM%.ps1"

> "!PSFILE!" echo $ErrorActionPreference = 'Stop'
>>"!PSFILE!" echo $project = $env:MAUI_PROJECT
>>"!PSFILE!" echo $tfm = $env:MAUI_TFM
>>"!PSFILE!" echo $major = $env:MAUI_MAJOR
>>"!PSFILE!" echo.
>>"!PSFILE!" echo $xml = New-Object System.Xml.XmlDocument
>>"!PSFILE!" echo $xml.PreserveWhitespace = $true
>>"!PSFILE!" echo $xml.Load($project)
>>"!PSFILE!" echo.
>>"!PSFILE!" echo $frameworks = $xml.SelectSingleNode('//TargetFrameworks')
>>"!PSFILE!" echo $framework = $xml.SelectSingleNode('//TargetFramework')
>>"!PSFILE!" echo.
>>"!PSFILE!" echo if ($frameworks -ne $null) {
>>"!PSFILE!" echo     $frameworks.InnerText = $tfm
>>"!PSFILE!" echo } elseif ($framework -ne $null) {
>>"!PSFILE!" echo     $framework.InnerText = $tfm
>>"!PSFILE!" echo } else {
>>"!PSFILE!" echo     throw 'Nie znaleziono TargetFramework ani TargetFrameworks.'
>>"!PSFILE!" echo }
>>"!PSFILE!" echo.
>>"!PSFILE!" echo $logging = $xml.SelectSingleNode('//PackageReference[@Include="Microsoft.Extensions.Logging.Debug"]')
>>"!PSFILE!" echo.
>>"!PSFILE!" echo if ($logging -ne $null) {
>>"!PSFILE!" echo     if ($major -eq '9') {
>>"!PSFILE!" echo         $logging.SetAttribute('Version', '9.0.0')
>>"!PSFILE!" echo     } else {
>>"!PSFILE!" echo         $logging.SetAttribute('Version', '10.0.0')
>>"!PSFILE!" echo     }
>>"!PSFILE!" echo }
>>"!PSFILE!" echo.
>>"!PSFILE!" echo if ($major -eq '9') {
>>"!PSFILE!" echo     $inflator = $xml.SelectSingleNode('//MauiXamlInflator')
>>"!PSFILE!" echo     if ($inflator -ne $null) {
>>"!PSFILE!" echo         $null = $inflator.ParentNode.RemoveChild($inflator)
>>"!PSFILE!" echo     }
>>"!PSFILE!" echo }
>>"!PSFILE!" echo.
>>"!PSFILE!" echo $settings = New-Object System.Xml.XmlWriterSettings
>>"!PSFILE!" echo $settings.Indent = $false
>>"!PSFILE!" echo $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
>>"!PSFILE!" echo $writer = [System.Xml.XmlWriter]::Create($project, $settings)
>>"!PSFILE!" echo $xml.Save($writer)
>>"!PSFILE!" echo $writer.Close()
>>"!PSFILE!" echo.
>>"!PSFILE!" echo Write-Host ('[OK] Zmieniono projekt na: ' + $tfm)

set "MAUI_PROJECT=!PROJECT!"
set "MAUI_TFM=!TFM!"
set "MAUI_MAJOR=!NET_MAJOR!"

powershell -NoProfile -ExecutionPolicy Bypass -File "!PSFILE!"
set "PS_RESULT=!errorlevel!"

del /q "!PSFILE!" >nul 2>&1

if not "!PS_RESULT!"=="0" (
    echo.
    echo [BLAD] Nie udalo sie zmodyfikowac .csproj.
    goto :ERROR
)

echo.

rem ============================================================
rem 9. Czyszczenie bin / obj
rem ============================================================

echo ============================================================
echo Czyszczenie poprzedniego buildu
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

echo.

rem ============================================================
rem 10. Instalacja MAUI
rem
rem Uzywamy "maui" - tak jak w poprzedniej dzialajacej konfiguracji.
rem Nie konfigurujemy Android SDK, JDK ani emulatora.
rem ============================================================

echo ============================================================
echo Instalacja / sprawdzenie workloadu MAUI
echo ============================================================
echo.

dotnet workload install maui

if errorlevel 1 (
    echo.
    echo [BLAD] Nie udalo sie zainstalowac workloadu MAUI.
    echo.
    echo Aktualne workloady:
    dotnet workload list
    goto :ERROR
)

echo.
echo [OK] Workload MAUI jest gotowy.
echo.

rem ============================================================
rem 11. Restore
rem ============================================================

echo ============================================================
echo Restore
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
rem 12. Build Windows
rem ============================================================

echo ============================================================
echo Build Windows
echo ============================================================
echo.

dotnet build "!PROJECT!" -f "!TFM!"

if errorlevel 1 (
    echo.
    echo [BLAD] Build nie powiodl sie.
    goto :ERROR
)

echo.
echo [OK] Projekt zbudowal sie poprawnie.
echo.

rem ============================================================
rem 13. run_windows.bat
rem ============================================================

set "RUN_BAT=!PROJECT_DIR!run_windows.bat"

> "!RUN_BAT!" echo @echo off
>>"!RUN_BAT!" echo setlocal
>>"!RUN_BAT!" echo chcp 65001 ^>nul
>>"!RUN_BAT!" echo cd /d "%%~dp0"
>>"!RUN_BAT!" echo echo Uruchamianie MAUI - Windows...
>>"!RUN_BAT!" echo echo.
>>"!RUN_BAT!" echo dotnet build -t:Run -f "!TFM!" "%%~dp0!PROJECT_NAME!"
>>"!RUN_BAT!" echo echo.
>>"!RUN_BAT!" echo if errorlevel 1 echo [BLAD] Nie udalo sie uruchomic programu.
>>"!RUN_BAT!" echo pause

echo [OK] Utworzono:
echo      !RUN_BAT!
echo.

rem ============================================================
rem 14. Koniec
rem ============================================================

echo ============================================================
echo                       GOTOWE
echo ============================================================
echo.
echo SDK:
echo   !ACTIVE_SDK!
echo.
echo Target:
echo   !TFM!
echo.
echo Projekt:
echo   !PROJECT!
echo.
echo Uruchomienie:
echo.
echo   run_windows.bat
echo.
echo albo recznie:
echo.
echo   dotnet build -t:Run -f !TFM! "!PROJECT_NAME!"
echo.
echo Android SDK, JDK i emulator NIE byly konfigurowane.
echo.
pause
exit /b 0


rem ============================================================
rem FUNKCJE
rem ============================================================

:INSTALL_DOTNET10

where winget >nul 2>&1

if errorlevel 1 (
    echo [BLAD] Na komputerze nie ma WinGet.
    echo.
    echo Zainstaluj recznie:
    echo .NET 10 SDK - Windows x64
    echo https://dotnet.microsoft.com/download/dotnet/10.0
    echo.
    exit /b 1
)

winget install --id Microsoft.DotNet.SDK.10 --exact --source winget --accept-package-agreements --accept-source-agreements

if errorlevel 1 (
    echo [BLAD] WinGet nie zainstalowal .NET 10 SDK.
    exit /b 1
)

exit /b 0


:REFRESH_PATH

if exist "%ProgramFiles%\dotnet\dotnet.exe" (
    set "DOTNET_ROOT=%ProgramFiles%\dotnet"
    set "PATH=%ProgramFiles%\dotnet;%PATH%"
)

exit /b 0


:ERROR
echo.
echo ============================================================
echo                    WYSTAPIL BLAD
echo ============================================================
echo.
echo Skrypt zostal zatrzymany.
echo Przeczytaj komunikat znajdujacy sie wyzej.
echo.
pause
exit /b 1
