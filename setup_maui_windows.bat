@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Konfiguracja .NET MAUI - Windows v3

cd /d "%~dp0"

set "LOG=%~dp0setup_maui_log.txt"
> "%LOG%" echo ===== SETUP MAUI WINDOWS =====
>>"%LOG%" echo Start: %DATE% %TIME%
>>"%LOG%" echo Katalog: %CD%
>>"%LOG%" echo.

call :MAIN >>"%LOG%" 2>&1
set "RESULT=%ERRORLEVEL%"

echo.
echo ============================================================
if "%RESULT%"=="0" (
    echo                         GOTOWE
) else (
    echo                         BLAD
)
echo ============================================================
echo.
echo Pelny log:
echo %LOG%
echo.

if not "%RESULT%"=="0" (
    echo Wyslij mi plik setup_maui_log.txt albo jego koncowke.
)

echo.
pause
exit /b %RESULT%


:MAIN

echo ============================================================
echo   KONFIGURACJA .NET MAUI - WINDOWS DESKTOP v3
echo ============================================================
echo.

rem ------------------------------------------------------------
rem 1. Administrator
rem ------------------------------------------------------------

net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Brak uprawnien administratora.
    echo [INFO] Uruchamiam skrypt ponownie jako administrator...

    rem Nie uzywamy PowerShell do konfiguracji projektu.
    rem Tylko standardowy Windows ShellExecute przez mshta do podniesienia uprawnien.
    mshta "javascript:var sh=new ActiveXObject('Shell.Application'); sh.ShellExecute('%~f0','','%~dp0','runas',1);close();"
    exit /b 0
)

rem ------------------------------------------------------------
rem 2. Projekt
rem ------------------------------------------------------------

set "PROJECT="

if exist "%~dp0MauiApp3\MauiApp3.csproj" (
    set "PROJECT=%~dp0MauiApp3\MauiApp3.csproj"
)

if not defined PROJECT if exist "%~dp0MauiApp3.csproj" (
    set "PROJECT=%~dp0MauiApp3.csproj"
)

if not defined PROJECT (
    for /r "%~dp0" %%F in (*.csproj) do (
        if not defined PROJECT set "PROJECT=%%~fF"
    )
)

if not defined PROJECT (
    echo [BLAD] Nie znaleziono pliku .csproj.
    exit /b 1
)

for %%F in ("!PROJECT!") do (
    set "PROJECT_DIR=%%~dpF"
    set "PROJECT_NAME=%%~nxF"
)

echo [OK] Projekt:
echo      !PROJECT!
echo.

rem ------------------------------------------------------------
rem 3. dotnet
rem ------------------------------------------------------------

where dotnet >nul 2>&1
if errorlevel 1 (
    echo [BRAK] Nie znaleziono .NET SDK.
    call :INSTALL_DOTNET10
    if errorlevel 1 exit /b 1
)

call :REFRESH_PATH

echo [INFO] Zainstalowane SDK:
dotnet --list-sdks
echo.

rem ------------------------------------------------------------
rem 4. Wybieranie SDK
rem Preferencja: .NET 10, potem .NET 9.
rem ------------------------------------------------------------

set "SELECTED_SDK="
set "NET_MAJOR="

for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /r /b "10\."') do (
    set "SELECTED_SDK=%%S"
    set "NET_MAJOR=10"
)

if not defined SELECTED_SDK (
    for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /r /b "9\."') do (
        set "SELECTED_SDK=%%S"
        set "NET_MAJOR=9"
    )
)

if not defined SELECTED_SDK (
    echo [INFO] Brak .NET 9/10. Instaluje .NET 10 SDK...
    call :INSTALL_DOTNET10
    if errorlevel 1 exit /b 1

    call :REFRESH_PATH

    for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /r /b "10\."') do (
        set "SELECTED_SDK=%%S"
        set "NET_MAJOR=10"
    )
)

if not defined SELECTED_SDK (
    echo [BLAD] Nie znaleziono SDK .NET 9 ani 10.
    exit /b 1
)

if "!NET_MAJOR!"=="9" (
    set "TFM=net9.0-windows10.0.19041.0"
) else (
    set "TFM=net10.0-windows10.0.19041.0"
)

echo [OK] Wybrane SDK: !SELECTED_SDK!
echo [OK] Target: !TFM!
echo.

rem ------------------------------------------------------------
rem 5. global.json
rem ------------------------------------------------------------

set "GLOBAL_JSON=%~dp0global.json"

> "!GLOBAL_JSON!" echo {
>>"!GLOBAL_JSON!" echo   "sdk": {
>>"!GLOBAL_JSON!" echo     "version": "!SELECTED_SDK!",
>>"!GLOBAL_JSON!" echo     "rollForward": "latestPatch"
>>"!GLOBAL_JSON!" echo   }
>>"!GLOBAL_JSON!" echo }

echo [OK] global.json utworzony.

set "ACTIVE_SDK="
for /f "tokens=*" %%V in ('dotnet --version 2^>nul') do set "ACTIVE_SDK=%%V"

if not defined ACTIVE_SDK (
    echo [BLAD] dotnet --version nie dziala po utworzeniu global.json.
    exit /b 1
)

echo [OK] Aktywne SDK: !ACTIVE_SDK!
echo.

rem ------------------------------------------------------------
rem 6. Kopia csproj
rem ------------------------------------------------------------

set "BACKUP=!PROJECT!.before-maui-setup.bak"

if not exist "!BACKUP!" (
    copy /y "!PROJECT!" "!BACKUP!" >nul
    if errorlevel 1 (
        echo [BLAD] Nie udalo sie utworzyc kopii .csproj.
        exit /b 1
    )
    echo [OK] Utworzono kopie .csproj.
) else (
    echo [INFO] Kopia .csproj juz istnieje.
)

rem ------------------------------------------------------------
rem 7. Modyfikacja csproj BEZ POWERSHELL
rem
rem Standardowy plik MAUI ma TargetFramework/TargetFrameworks
rem i PackageReference w pojedynczych liniach.
rem Pomijanie pustych linii nie zmienia znaczenia XML.
rem ------------------------------------------------------------

set "TMP_PROJECT=!PROJECT!.tmp"
if exist "!TMP_PROJECT!" del /q "!TMP_PROJECT!" >nul 2>&1

set "FOUND_TFM=0"

for /f "usebackq delims=" %%L in ("!PROJECT!") do (
    set "LINE=%%L"
    set "SKIP=0"

    rem TargetFrameworks
    set "TEST=!LINE:<TargetFrameworks>=!"
    if not "!TEST!"=="!LINE!" (
        >>"!TMP_PROJECT!" echo(    ^<TargetFrameworks^>!TFM!^</TargetFrameworks^>
        set "FOUND_TFM=1"
        set "SKIP=1"
    )

    rem TargetFramework
    if "!SKIP!"=="0" (
        set "TEST=!LINE:<TargetFramework>=!"
        if not "!TEST!"=="!LINE!" (
            >>"!TMP_PROJECT!" echo(    ^<TargetFramework^>!TFM!^</TargetFramework^>
            set "FOUND_TFM=1"
            set "SKIP=1"
        )
    )

    rem Dla .NET 9 usuwamy MauiXamlInflator SourceGen
    if "!SKIP!"=="0" if "!NET_MAJOR!"=="9" (
        set "TEST=!LINE:<MauiXamlInflator>=!"
        if not "!TEST!"=="!LINE!" (
            echo [INFO] Usuwam MauiXamlInflator dla .NET 9.
            set "SKIP=1"
        )
    )

    rem Microsoft.Extensions.Logging.Debug
    if "!SKIP!"=="0" (
        set "TEST=!LINE:Microsoft.Extensions.Logging.Debug=!"
        if not "!TEST!"=="!LINE!" (
            if "!NET_MAJOR!"=="9" (
                >>"!TMP_PROJECT!" echo(    ^<PackageReference Include="Microsoft.Extensions.Logging.Debug" Version="9.0.0" /^>
            ) else (
                >>"!TMP_PROJECT!" echo(    ^<PackageReference Include="Microsoft.Extensions.Logging.Debug" Version="10.0.0" /^>
            )
            set "SKIP=1"
        )
    )

    if "!SKIP!"=="0" (
        >>"!TMP_PROJECT!" echo(!LINE!
    )
)

if "!FOUND_TFM!"=="0" (
    echo [BLAD] W .csproj nie znaleziono TargetFramework ani TargetFrameworks.
    del /q "!TMP_PROJECT!" >nul 2>&1
    exit /b 1
)

move /y "!TMP_PROJECT!" "!PROJECT!" >nul
if errorlevel 1 (
    echo [BLAD] Nie udalo sie zapisac zmodyfikowanego .csproj.
    exit /b 1
)

echo [OK] Zmieniono .csproj bez PowerShell.
echo.

echo ----- AKTUALNY CSPROJ -----
type "!PROJECT!"
echo ----- KONIEC CSPROJ -----
echo.

rem ------------------------------------------------------------
rem 8. Czyszczenie bin/obj
rem ------------------------------------------------------------

if exist "!PROJECT_DIR!bin" (
    echo [INFO] Usuwam bin...
    rmdir /s /q "!PROJECT_DIR!bin"
)

if exist "!PROJECT_DIR!obj" (
    echo [INFO] Usuwam obj...
    rmdir /s /q "!PROJECT_DIR!obj"
)

echo.

rem ------------------------------------------------------------
rem 9. MAUI workload
rem ------------------------------------------------------------

echo ============================================================
echo Instalacja workloadu MAUI
echo ============================================================
echo.

dotnet workload install maui
if errorlevel 1 (
    echo [BLAD] dotnet workload install maui nie powiodlo sie.
    echo.
    echo Workload list:
    dotnet workload list
    exit /b 1
)

echo [OK] MAUI workload gotowy.
echo.

rem ------------------------------------------------------------
rem 10. Restore
rem ------------------------------------------------------------

echo ============================================================
echo Restore
echo ============================================================
echo.

dotnet restore "!PROJECT!"
if errorlevel 1 (
    echo [BLAD] dotnet restore nie powiodlo sie.
    exit /b 1
)

echo [OK] Restore zakonczony.
echo.

rem ------------------------------------------------------------
rem 11. Build
rem ------------------------------------------------------------

echo ============================================================
echo Build
echo ============================================================
echo.

dotnet build "!PROJECT!" -f "!TFM!"
if errorlevel 1 (
    echo [BLAD] dotnet build nie powiodlo sie.
    exit /b 1
)

echo [OK] Build zakonczony.
echo.

rem ------------------------------------------------------------
rem 12. run_windows.bat
rem ------------------------------------------------------------

set "RUN_BAT=!PROJECT_DIR!run_windows.bat"

> "!RUN_BAT!" echo @echo off
>>"!RUN_BAT!" echo setlocal
>>"!RUN_BAT!" echo chcp 65001 ^>nul
>>"!RUN_BAT!" echo cd /d "%%~dp0"
>>"!RUN_BAT!" echo dotnet build -t:Run -f "!TFM!" "%%~dp0!PROJECT_NAME!"
>>"!RUN_BAT!" echo echo.
>>"!RUN_BAT!" echo if errorlevel 1 echo [BLAD] Nie udalo sie uruchomic aplikacji.
>>"!RUN_BAT!" echo pause

echo [OK] Utworzono:
echo      !RUN_BAT!
echo.

echo ============================================================
echo PODSUMOWANIE
echo ============================================================
echo SDK:       !ACTIVE_SDK!
echo Framework: !TFM!
echo.
echo Uruchom aplikacje:
echo.
echo   run_windows.bat
echo.
echo lub:
echo.
echo   dotnet build -t:Run -f !TFM! "!PROJECT_NAME!"
echo.
echo Android SDK / JDK / emulator nie byly konfigurowane.
echo.

exit /b 0


:INSTALL_DOTNET10

where winget >nul 2>&1
if errorlevel 1 (
    echo [BLAD] Nie znaleziono WinGet.
    echo Zainstaluj recznie .NET 10 SDK x64:
    echo https://dotnet.microsoft.com/download/dotnet/10.0
    exit /b 1
)

winget install --id Microsoft.DotNet.SDK.10 --exact --source winget --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo [BLAD] Instalacja .NET 10 SDK przez WinGet nie powiodla sie.
    exit /b 1
)

exit /b 0


:REFRESH_PATH

if exist "%ProgramFiles%\dotnet\dotnet.exe" (
    set "DOTNET_ROOT=%ProgramFiles%\dotnet"
    set "PATH=%ProgramFiles%\dotnet;%PATH%"
)

exit /b 0
