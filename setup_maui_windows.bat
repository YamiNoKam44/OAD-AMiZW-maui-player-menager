@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Konfiguracja .NET MAUI - Windows v5

cd /d "%~dp0"

set "ROOT=%~dp0"
set "LOG=%~dp0setup_maui_log.txt"

> "%LOG%" echo ===== SETUP MAUI WINDOWS v5 =====
>>"%LOG%" echo Start: %DATE% %TIME%
>>"%LOG%" echo Katalog: %CD%
>>"%LOG%" echo.

echo ============================================================
echo        KONFIGURACJA .NET MAUI - WINDOWS v5
echo ============================================================
echo.
echo Ta wersja:
echo - nie uzywa ProgramFiles(x86),
echo - nie wymaga systemowego .NET, jezeli go brakuje,
echo - w razie potrzeby instaluje lokalny .NET 10 do folderu .dotnet,
echo - dla .NET 9 przerabia projekt na net9 Windows,
echo - dla .NET 10 zostawia net10 Windows,
echo - instaluje tylko workload MAUI dla Windows.
echo.

rem ============================================================
rem 1. Projekt
rem ============================================================

set "PROJECT=%ROOT%MauiApp3\MauiApp3.csproj"

if not exist "!PROJECT!" (
    set "PROJECT="
    for /r "%ROOT%" %%F in (*.csproj) do (
        if not defined PROJECT set "PROJECT=%%~fF"
    )
)

if not defined PROJECT (
    echo [BLAD] Nie znaleziono pliku .csproj.
    >>"%LOG%" echo [BLAD] Nie znaleziono pliku .csproj.
    goto :ERROR
)

for %%F in ("!PROJECT!") do (
    set "PROJECT_DIR=%%~dpF"
    set "PROJECT_NAME=%%~nxF"
)

echo [OK] Projekt:
echo      !PROJECT!
>>"%LOG%" echo [OK] Projekt: !PROJECT!
echo.

rem ============================================================
rem 2. Szukamy dzialajacego SDK 10 lub 9
rem ============================================================

set "DOTNET_CMD="
set "SELECTED_SDK="
set "NET_MAJOR="

where dotnet >nul 2>&1
if not errorlevel 1 (
    set "DOTNET_CMD=dotnet"
    call :SELECT_SDK

    if defined SELECTED_SDK (
        echo [OK] Uzywam systemowego .NET.
    )
)

rem ============================================================
rem 3. Brak odpowiedniego SDK -> lokalny .NET 10
rem ============================================================

if not defined SELECTED_SDK (
    echo [INFO] Brak dzialajacego SDK .NET 9/10.
    echo [INFO] Instaluje lokalnie .NET 10 SDK do:
    echo        %ROOT%.dotnet
    echo.

    >>"%LOG%" echo [INFO] Instalacja lokalnego .NET 10.

    call :INSTALL_LOCAL_DOTNET10
    if errorlevel 1 goto :ERROR

    set "DOTNET_CMD=%ROOT%.dotnet\dotnet.exe"

    call :SELECT_SDK

    if not defined SELECTED_SDK (
        echo [BLAD] Lokalny .NET zostal zainstalowany, ale SDK 10 nadal nie jest widoczne.
        >>"%LOG%" echo [BLAD] Brak SDK po lokalnej instalacji.
        goto :ERROR
    )
)

echo.
echo [OK] Wybrane SDK: !SELECTED_SDK!
echo [OK] Polecenie: !DOTNET_CMD!
>>"%LOG%" echo [OK] Wybrane SDK: !SELECTED_SDK!
>>"%LOG%" echo [OK] Polecenie dotnet: !DOTNET_CMD!

if "!NET_MAJOR!"=="9" (
    set "TFM=net9.0-windows10.0.19041.0"
) else (
    set "TFM=net10.0-windows10.0.19041.0"
)

echo [OK] Target: !TFM!
>>"%LOG%" echo [OK] Target: !TFM!
echo.

rem ============================================================
rem 4. global.json
rem ============================================================

> "%ROOT%global.json" echo {
>>"%ROOT%global.json" echo   "sdk": {
>>"%ROOT%global.json" echo     "version": "!SELECTED_SDK!",
>>"%ROOT%global.json" echo     "rollForward": "latestPatch"
>>"%ROOT%global.json" echo   }
>>"%ROOT%global.json" echo }

echo [OK] Utworzono global.json.
>>"%LOG%" echo [OK] Utworzono global.json.

"!DOTNET_CMD!" --version
if errorlevel 1 (
    echo [BLAD] dotnet --version nie dziala.
    >>"%LOG%" echo [BLAD] dotnet --version nie dziala.
    goto :ERROR
)

rem ============================================================
rem 5. Kopia .csproj
rem ============================================================

set "BACKUP=!PROJECT!.before-maui-setup.bak"

if not exist "!BACKUP!" (
    copy /y "!PROJECT!" "!BACKUP!" >nul
    if errorlevel 1 (
        echo [BLAD] Nie udalo sie utworzyc kopii .csproj.
        goto :ERROR
    )
    echo [OK] Utworzono kopie .csproj.
) else (
    echo [INFO] Kopia .csproj juz istnieje.
)

rem ============================================================
rem 6. Zmiana projektu na Windows-only
rem ============================================================

set "MAUI_PROJECT=!PROJECT!"
set "MAUI_TFM=!TFM!"
set "MAUI_MAJOR=!NET_MAJOR!"

echo.
echo [INFO] Dostosowuje MauiApp3.csproj...

powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand CgAkAEUAcgByAG8AcgBBAGMAdABpAG8AbgBQAHIAZQBmAGUAcgBlAG4AYwBlACAAPQAgACcAUwB0AG8AcAAnAAoACgAkAHAAIAA9ACAAJABlAG4AdgA6AE0AQQBVAEkAXwBQAFIATwBKAEUAQwBUAAoAJAB0AGYAbQAgAD0AIAAkAGUAbgB2ADoATQBBAFUASQBfAFQARgBNAAoAJABtAGEAagBvAHIAIAA9ACAAJABlAG4AdgA6AE0AQQBVAEkAXwBNAEEASgBPAFIACgAKACQAbABpAG4AZQBzACAAPQAgAFsASQBPAC4ARgBpAGwAZQBdADoAOgBSAGUAYQBkAEEAbABsAEwAaQBuAGUAcwAoACQAcAApAAoAJABvAHUAdAAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAJwBTAHkAcwB0AGUAbQAuAEMAbwBsAGwAZQBjAHQAaQBvAG4AcwAuAEcAZQBuAGUAcgBpAGMALgBMAGkAcwB0AFsAcwB0AHIAaQBuAGcAXQAnAAoAJABpAG4AcwBlAHIAdABlAGQAIAA9ACAAJABmAGEAbABzAGUACgAKAGYAbwByAGUAYQBjAGgAIAAoACQAbABpAG4AZQAwACAAaQBuACAAJABsAGkAbgBlAHMAKQAgAHsACgAgACAAIAAgACQAbABpAG4AZQAgAD0AIAAkAGwAaQBuAGUAMAAKAAoAIAAgACAAIAAjACAAUgBlAHAAbwAgAGgAYQBzACAAdABoAHIAZQBlACAAVABhAHIAZwBlAHQARgByAGEAbQBlAHcAbwByAGsAcwAgAGwAaQBuAGUAcwAgACgAQQBuAGQAcgBvAGkAZAAsACAAaQBPAFMALwBNAGEAYwBDAGEAdABhAGwAeQBzAHQALAAgAFcAaQBuAGQAbwB3AHMAKQAuAAoAIAAgACAAIAAjACAARgBvAHIAIAB0AGgAaQBzACAAcwBlAHQAdQBwACAAdwBlACAAawBlAGUAcAAgAG8AbgBsAHkAIABXAGkAbgBkAG8AdwBzAC4ACgAgACAAIAAgAGkAZgAgACgAJABsAGkAbgBlACAALQBtAGEAdABjAGgAIAAnADwAVABhAHIAZwBlAHQARgByAGEAbQBlAHcAbwByAGsAcwAoAD8AOgBcAHMAfAA+ACkAJwApACAAewAKACAAIAAgACAAIAAgACAAIABjAG8AbgB0AGkAbgB1AGUACgAgACAAIAAgAH0ACgAKACAAIAAgACAAaQBmACAAKAAtAG4AbwB0ACAAJABpAG4AcwBlAHIAdABlAGQAIAAtAGEAbgBkACAAJABsAGkAbgBlACAALQBtAGEAdABjAGgAIAAnADwAUAByAG8AcABlAHIAdAB5AEcAcgBvAHUAcAA+ACcAKQAgAHsACgAgACAAIAAgACAAIAAgACAAJABvAHUAdAAuAEEAZABkACgAJABsAGkAbgBlACkACgAgACAAIAAgACAAIAAgACAAJABpAG4AZABlAG4AdAAgAD0AIAAoACQAbABpAG4AZQAgAC0AcgBlAHAAbABhAGMAZQAgACcAPABQAHIAbwBwAGUAcgB0AHkARwByAG8AdQBwAD4ALgAqACQAJwAsACAAJwAnACkAIAArACAAIgBgAHQAIgAKACAAIAAgACAAIAAgACAAIAAkAG8AdQB0AC4AQQBkAGQAKAAkAGkAbgBkAGUAbgB0ACAAKwAgACcAPABUAGEAcgBnAGUAdABGAHIAYQBtAGUAdwBvAHIAawA+ACcAIAArACAAJAB0AGYAbQAgACsAIAAnADwALwBUAGEAcgBnAGUAdABGAHIAYQBtAGUAdwBvAHIAawA+ACcAKQAKACAAIAAgACAAIAAgACAAIAAkAGkAbgBzAGUAcgB0AGUAZAAgAD0AIAAkAHQAcgB1AGUACgAgACAAIAAgACAAIAAgACAAYwBvAG4AdABpAG4AdQBlAAoAIAAgACAAIAB9AAoACgAgACAAIAAgACMAIABTAG8AdQByAGMAZQBHAGUAbgAgAGUAbgB0AHIAeQAgAGUAeABpAHMAdABzACAAaQBuACAAdABoAGUAIAAuAE4ARQBUACAAMQAwACAAcAByAG8AagBlAGMAdAAgAGEAbgBkACAAYwBhAHUAcwBlAGQAIAB0AHIAbwB1AGIAbABlAAoAIAAgACAAIAAjACAAdwBoAGUAbgAgAHQAaABlACAAcAByAG8AagBlAGMAdAAgAHcAYQBzACAAZABvAHcAbgBnAHIAYQBkAGUAZAAgAHQAbwAgAC4ATgBFAFQAIAA5AC4ACgAgACAAIAAgAGkAZgAgACgAJABtAGEAagBvAHIAIAAtAGUAcQAgACcAOQAnACAALQBhAG4AZAAgACQAbABpAG4AZQAgAC0AbQBhAHQAYwBoACAAJwA8AE0AYQB1AGkAWABhAG0AbABJAG4AZgBsAGEAdABvAHIAPgAnACkAIAB7AAoAIAAgACAAIAAgACAAIAAgAGMAbwBuAHQAaQBuAHUAZQAKACAAIAAgACAAfQAKAAoAIAAgACAAIAAjACAASwBlAGUAcAAgAE0AaQBjAHIAbwBzAG8AZgB0AC4ARQB4AHQAZQBuAHMAaQBvAG4AcwAuAEwAbwBnAGcAaQBuAGcALgBEAGUAYgB1AGcAIABhAGwAaQBnAG4AZQBkACAAdwBpAHQAaAAgAHMAZQBsAGUAYwB0AGUAZAAgAFMARABLAC4ACgAgACAAIAAgAGkAZgAgACgAJABsAGkAbgBlACAALQBtAGEAdABjAGgAIAAnAE0AaQBjAHIAbwBzAG8AZgB0AFwALgBFAHgAdABlAG4AcwBpAG8AbgBzAFwALgBMAG8AZwBnAGkAbgBnAFwALgBEAGUAYgB1AGcAJwApACAAewAKACAAIAAgACAAIAAgACAAIABpAGYAIAAoACQAbQBhAGoAbwByACAALQBlAHEAIAAnADkAJwApACAAewAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACQAbABpAG4AZQAgAD0AIABbAHIAZQBnAGUAeABdADoAOgBSAGUAcABsAGEAYwBlACgAJABsAGkAbgBlACwAIAAnAFYAZQByAHMAaQBvAG4APQAiAFsAXgAiAF0AKgAiACcALAAgACcAVgBlAHIAcwBpAG8AbgA9ACIAOQAuADAALgAwACIAJwApAAoAIAAgACAAIAAgACAAIAAgAH0ACgAgACAAIAAgACAAIAAgACAAZQBsAHMAZQAgAHsACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAkAGwAaQBuAGUAIAA9ACAAWwByAGUAZwBlAHgAXQA6ADoAUgBlAHAAbABhAGMAZQAoACQAbABpAG4AZQAsACAAJwBWAGUAcgBzAGkAbwBuAD0AIgBbAF4AIgBdACoAIgAnACwAIAAnAFYAZQByAHMAaQBvAG4APQAiADEAMAAuADAALgAwACIAJwApAAoAIAAgACAAIAAgACAAIAAgAH0ACgAgACAAIAAgAH0ACgAKACAAIAAgACAAJABvAHUAdAAuAEEAZABkACgAJABsAGkAbgBlACkACgB9AAoACgBpAGYAIAAoAC0AbgBvAHQAIAAkAGkAbgBzAGUAcgB0AGUAZAApACAAewAKACAAIAAgACAAdABoAHIAbwB3ACAAJwBOAGkAZQAgAHoAbgBhAGwAZQB6AGkAbwBuAG8AIAA8AFAAcgBvAHAAZQByAHQAeQBHAHIAbwB1AHAAPgAgAHcAIABwAGwAaQBrAHUAIABjAHMAcAByAG8AagAuACcACgB9AAoACgBbAEkATwAuAEYAaQBsAGUAXQA6ADoAVwByAGkAdABlAEEAbABsAEwAaQBuAGUAcwAoAAoAIAAgACAAIAAkAHAALAAKACAAIAAgACAAJABvAHUAdAAsAAoAIAAgACAAIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABTAHkAcwB0AGUAbQAuAFQAZQB4AHQALgBVAFQARgA4AEUAbgBjAG8AZABpAG4AZwAoACQAZgBhAGwAcwBlACkAKQAKACkACgAKAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAoACcAWwBPAEsAXQAgAFoAbQBpAGUAbgBpAG8AbgBvACAAcAByAG8AagBlAGsAdAAgAG4AYQAgAFcAaQBuAGQAbwB3AHMALQBvAG4AbAB5ADoAIAAnACAAKwAgACQAdABmAG0AKQAKAA==

if errorlevel 1 (
    echo [BLAD] Nie udalo sie zmodyfikowac .csproj.
    >>"%LOG%" echo [BLAD] Modyfikacja csproj nie powiodla sie.
    goto :ERROR
)

>>"%LOG%" echo.
>>"%LOG%" echo ===== CSPROJ PO MODYFIKACJI =====
>>"%LOG%" type "!PROJECT!"
>>"%LOG%" echo ===== KONIEC CSPROJ =====
>>"%LOG%" echo.

rem ============================================================
rem 7. Czyszczenie bin / obj
rem ============================================================

if exist "!PROJECT_DIR!bin" (
    echo [INFO] Usuwam bin...
    rmdir /s /q "!PROJECT_DIR!bin"
)

if exist "!PROJECT_DIR!obj" (
    echo [INFO] Usuwam obj...
    rmdir /s /q "!PROJECT_DIR!obj"
)

rem ============================================================
rem 8. Workload tylko dla Windows
rem ============================================================

echo.
echo ============================================================
echo Instalacja MAUI Windows
echo ============================================================
echo.

"!DOTNET_CMD!" workload install maui-windows
set "WORKLOAD_RESULT=!ERRORLEVEL!"

>>"%LOG%" echo Workload install exit code: !WORKLOAD_RESULT!
"!DOTNET_CMD!" workload list >>"%LOG%" 2>&1

if not "!WORKLOAD_RESULT!"=="0" (
    echo.
    echo [BLAD] Nie udalo sie zainstalowac workloadu maui-windows.
    echo Szczegoly sa w setup_maui_log.txt.
    goto :ERROR
)

echo [OK] MAUI Windows zainstalowane.

rem ============================================================
rem 9. Restore
rem ============================================================

echo.
echo ============================================================
echo Restore
echo ============================================================
echo.

"!DOTNET_CMD!" restore "!PROJECT!"
set "RESTORE_RESULT=!ERRORLEVEL!"
>>"%LOG%" echo Restore exit code: !RESTORE_RESULT!

if not "!RESTORE_RESULT!"=="0" (
    echo [BLAD] Restore nie powiodl sie.
    goto :ERROR
)

echo [OK] Restore zakonczony.

rem ============================================================
rem 10. Build
rem ============================================================

echo.
echo ============================================================
echo Build Windows
echo ============================================================
echo.

"!DOTNET_CMD!" build "!PROJECT!" -f "!TFM!"
set "BUILD_RESULT=!ERRORLEVEL!"
>>"%LOG%" echo Build exit code: !BUILD_RESULT!

if not "!BUILD_RESULT!"=="0" (
    echo [BLAD] Build nie powiodl sie.
    goto :ERROR
)

echo [OK] Build zakonczony.

rem ============================================================
rem 11. run_windows.bat
rem ============================================================

set "RUN_BAT=%ROOT%run_windows.bat"

> "!RUN_BAT!" echo @echo off
>>"!RUN_BAT!" echo setlocal
>>"!RUN_BAT!" echo chcp 65001 ^>nul
>>"!RUN_BAT!" echo cd /d "%%~dp0"
>>"!RUN_BAT!" echo set "DOTNET=dotnet"
>>"!RUN_BAT!" echo if exist "%%~dp0.dotnet\dotnet.exe" set "DOTNET=%%~dp0.dotnet\dotnet.exe"
>>"!RUN_BAT!" echo "%%DOTNET%%" build -t:Run -f "!TFM!" "%%~dp0MauiApp3\MauiApp3.csproj"
>>"!RUN_BAT!" echo echo.
>>"!RUN_BAT!" echo if errorlevel 1 echo [BLAD] Nie udalo sie uruchomic aplikacji.
>>"!RUN_BAT!" echo pause

echo.
echo ============================================================
echo                         GOTOWE
echo ============================================================
echo.
echo SDK:
echo   !SELECTED_SDK!
echo.
echo Target:
echo   !TFM!
echo.
echo Program uruchomisz przez:
echo.
echo   run_windows.bat
echo.
echo albo:
echo.
echo   "!DOTNET_CMD!" build -t:Run -f !TFM! "!PROJECT!"
echo.
echo Android SDK, JDK i emulator NIE zostaly zainstalowane.
echo.
echo Log:
echo   %LOG%
echo.

exit /b 0


rem ============================================================
rem SELECT_SDK
rem ============================================================

:SELECT_SDK

set "SELECTED_SDK="
set "NET_MAJOR="
set "SDK_FILE=%TEMP%\maui_sdks_%RANDOM%_%RANDOM%.txt"

"!DOTNET_CMD!" --list-sdks > "!SDK_FILE!" 2>&1

if errorlevel 1 (
    type "!SDK_FILE!"
    >>"%LOG%" type "!SDK_FILE!"
    del /q "!SDK_FILE!" >nul 2>&1
    exit /b 1
)

echo [INFO] Dostepne SDK:
type "!SDK_FILE!"
>>"%LOG%" echo ===== DOTNET --LIST-SDKS =====
>>"%LOG%" type "!SDK_FILE!"

for /f "usebackq tokens=1" %%S in ("!SDK_FILE!") do (
    set "SDK_VERSION=%%S"

    if "!SDK_VERSION:~0,3!"=="10." (
        set "SELECTED_SDK=!SDK_VERSION!"
        set "NET_MAJOR=10"
    )
)

if not defined SELECTED_SDK (
    for /f "usebackq tokens=1" %%S in ("!SDK_FILE!") do (
        set "SDK_VERSION=%%S"

        if "!SDK_VERSION:~0,2!"=="9." (
            set "SELECTED_SDK=!SDK_VERSION!"
            set "NET_MAJOR=9"
        )
    )
)

del /q "!SDK_FILE!" >nul 2>&1

if defined SELECTED_SDK (
    exit /b 0
)

exit /b 1


rem ============================================================
rem INSTALL_LOCAL_DOTNET10
rem ============================================================

:INSTALL_LOCAL_DOTNET10

set "DOTNET_DIR=%ROOT%.dotnet"
set "INSTALLER=%TEMP%\dotnet-install.ps1"

if exist "!DOTNET_DIR!\dotnet.exe" (
    echo [INFO] Folder .dotnet juz istnieje - sprawdzam go.
    "!DOTNET_DIR!\dotnet.exe" --list-sdks
    if not errorlevel 1 (
        exit /b 0
    )
)

echo [INFO] Pobieram oficjalny instalator Microsoftu...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing 'https://dot.net/v1/dotnet-install.ps1' -OutFile '%TEMP%\dotnet-install.ps1'"

if errorlevel 1 (
    echo [UWAGA] PowerShell nie pobral instalatora. Probuje curl.exe...

    where curl.exe >nul 2>&1
    if errorlevel 1 (
        echo [BLAD] Nie mozna pobrac dotnet-install.ps1.
        >>"%LOG%" echo [BLAD] Pobranie dotnet-install.ps1 nie powiodlo sie.
        exit /b 1
    )

    curl.exe -L "https://dot.net/v1/dotnet-install.ps1" -o "!INSTALLER!"

    if errorlevel 1 (
        echo [BLAD] curl.exe rowniez nie pobral instalatora.
        exit /b 1
    )
)

echo [INFO] Instaluje .NET 10 SDK x64 lokalnie...
echo [INFO] To moze chwile potrwac.

powershell -NoProfile -ExecutionPolicy Bypass -File "!INSTALLER!" -Channel 10.0 -Quality GA -Architecture x64 -InstallDir "!DOTNET_DIR!" -NoPath

if errorlevel 1 (
    echo [BLAD] Oficjalny dotnet-install.ps1 zakonczyl sie bledem.
    >>"%LOG%" echo [BLAD] dotnet-install.ps1 zakonczyl sie bledem.
    exit /b 1
)

if not exist "!DOTNET_DIR!\dotnet.exe" (
    echo [BLAD] Instalator zakonczyl prace, ale nie ma:
    echo        !DOTNET_DIR!\dotnet.exe
    exit /b 1
)

echo [OK] Lokalny .NET 10 zostal zainstalowany.
exit /b 0


:ERROR

echo.
echo ============================================================
echo                         BLAD
echo ============================================================
echo.
echo Pelny log:
echo   %LOG%
echo.
echo Podeślij setup_maui_log.txt, jezeli skrypt znow sie zatrzyma.
echo.
pause
exit /b 1
