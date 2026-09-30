@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Konfiguracja .NET MAUI - Windows v4

cd /d "%~dp0"

set "LOG=%~dp0setup_maui_log.txt"
> "%LOG%" echo ===== SETUP MAUI WINDOWS v4 =====
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
echo Pelny log zapisano tutaj:
echo %LOG%
echo.

if not "%RESULT%"=="0" (
    echo W razie bledu wyslij setup_maui_log.txt.
)

echo.
pause
exit /b %RESULT%


:MAIN

echo ============================================================
echo     KONFIGURACJA .NET MAUI - WINDOWS DESKTOP v4
echo ============================================================
echo.

rem ============================================================
rem 1. Uprawnienia administratora
rem ============================================================

net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Potrzebne sa uprawnienia administratora.
    echo [INFO] Uruchamiam ponownie jako administrator...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
    exit /b 0
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

rem ============================================================
rem 3. Zapewnienie dzialajacego polecenia dotnet
rem ============================================================

call :FIND_DOTNET

if errorlevel 1 (
    echo [BRAK] Nie znaleziono dzialajacego .NET SDK.
    echo [INFO] Probuje zainstalowac .NET 10 SDK przez WinGet...
    call :INSTALL_DOTNET_WINGET

    call :FIND_DOTNET

    if errorlevel 1 (
        echo.
        echo [UWAGA] WinGet nie dostarczyl dzialajacego dotnet.
        echo [INFO] Probuje oficjalnego instalatora Microsoft dotnet-install.ps1...
        call :INSTALL_DOTNET_SCRIPT

        call :FIND_DOTNET

        if errorlevel 1 (
            echo.
            echo [BLAD] Po obu probach nadal nie znaleziono dotnet.exe.
            echo.
            echo Sprawdzone lokalizacje:
            echo   %ProgramFiles%\dotnet\dotnet.exe
            echo   %ProgramFiles(x86)%\dotnet\dotnet.exe
            echo.
            exit /b 1
        )
    )
)

echo [OK] dotnet.exe:
where dotnet
echo.

echo [INFO] Zainstalowane SDK:
dotnet --list-sdks

if errorlevel 1 (
    echo [BLAD] dotnet.exe istnieje, ale dotnet --list-sdks nie dziala.
    exit /b 1
)

echo.

rem ============================================================
rem 4. Wybieranie SDK
rem Preferujemy 10; jesli go nie ma, 9.
rem ============================================================

set "SELECTED_SDK="
set "NET_MAJOR="

for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /r "^10\."') do (
    set "SELECTED_SDK=%%S"
    set "NET_MAJOR=10"
)

if not defined SELECTED_SDK (
    for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /r "^9\."') do (
        set "SELECTED_SDK=%%S"
        set "NET_MAJOR=9"
    )
)

if not defined SELECTED_SDK (
    echo [INFO] dotnet dziala, ale nie ma SDK 9 ani 10.
    echo [INFO] Instaluje .NET 10 SDK oficjalnym instalatorem...
    call :INSTALL_DOTNET_SCRIPT

    call :FIND_DOTNET
    if errorlevel 1 exit /b 1

    for /f "tokens=1" %%S in ('dotnet --list-sdks ^| findstr /r "^10\."') do (
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

rem ============================================================
rem 5. global.json
rem ============================================================

set "GLOBAL_JSON=%~dp0global.json"

> "!GLOBAL_JSON!" echo {
>>"!GLOBAL_JSON!" echo   "sdk": {
>>"!GLOBAL_JSON!" echo     "version": "!SELECTED_SDK!",
>>"!GLOBAL_JSON!" echo     "rollForward": "latestPatch"
>>"!GLOBAL_JSON!" echo   }
>>"!GLOBAL_JSON!" echo }

echo [OK] Utworzono global.json.

set "ACTIVE_SDK="
for /f "tokens=*" %%V in ('dotnet --version 2^>nul') do set "ACTIVE_SDK=%%V"

if not defined ACTIVE_SDK (
    echo [BLAD] Po utworzeniu global.json dotnet --version nie dziala.
    exit /b 1
)

echo [OK] Aktywne SDK: !ACTIVE_SDK!
echo.

rem ============================================================
rem 6. Kopia projektu
rem ============================================================

set "BACKUP=!PROJECT!.before-maui-setup.bak"

if not exist "!BACKUP!" (
    copy /y "!PROJECT!" "!BACKUP!" >nul
    if errorlevel 1 (
        echo [BLAD] Nie udalo sie wykonac kopii .csproj.
        exit /b 1
    )
    echo [OK] Utworzono kopie .csproj.
) else (
    echo [INFO] Kopia .csproj juz istnieje.
)

echo.

rem ============================================================
rem 7. Modyfikacja csproj
rem Uzywamy PowerShell tylko jako parsera XML.
rem Dotychczasowy blad wystepowal PRZED tym etapem - przy braku dotnet.
rem ============================================================

set "PSFILE=%TEMP%\maui_project_config_%RANDOM%_%RANDOM%.ps1"

> "!PSFILE!" echo $ErrorActionPreference = 'Stop'
>>"!PSFILE!" echo $project = $env:MAUI_PROJECT
>>"!PSFILE!" echo $tfm = $env:MAUI_TFM
>>"!PSFILE!" echo $major = $env:MAUI_MAJOR
>>"!PSFILE!" echo [xml]$xml = Get-Content -LiteralPath $project -Raw
>>"!PSFILE!" echo $tfms = $xml.Project.PropertyGroup.TargetFrameworks
>>"!PSFILE!" echo $tfmNode = $xml.Project.PropertyGroup.TargetFramework
>>"!PSFILE!" echo if ($tfms) {
>>"!PSFILE!" echo     foreach ($node in @($xml.Project.PropertyGroup.TargetFrameworks)) { if ($node) { $node = $tfm } }
>>"!PSFILE!" echo     $pg = @($xml.Project.PropertyGroup ^| Where-Object { $_.TargetFrameworks })[0]
>>"!PSFILE!" echo     $pg.TargetFrameworks = $tfm
>>"!PSFILE!" echo } elseif ($tfmNode) {
>>"!PSFILE!" echo     $pg = @($xml.Project.PropertyGroup ^| Where-Object { $_.TargetFramework })[0]
>>"!PSFILE!" echo     $pg.TargetFramework = $tfm
>>"!PSFILE!" echo } else {
>>"!PSFILE!" echo     throw 'Nie znaleziono TargetFramework ani TargetFrameworks.'
>>"!PSFILE!" echo }
>>"!PSFILE!" echo foreach ($ig in @($xml.Project.ItemGroup)) {
>>"!PSFILE!" echo     foreach ($pr in @($ig.PackageReference)) {
>>"!PSFILE!" echo         if ($pr.Include -eq 'Microsoft.Extensions.Logging.Debug') {
>>"!PSFILE!" echo             if ($major -eq '9') { $pr.Version = '9.0.0' } else { $pr.Version = '10.0.0' }
>>"!PSFILE!" echo         }
>>"!PSFILE!" echo     }
>>"!PSFILE!" echo }
>>"!PSFILE!" echo if ($major -eq '9') {
>>"!PSFILE!" echo     foreach ($pg2 in @($xml.Project.PropertyGroup)) {
>>"!PSFILE!" echo         if ($pg2.MauiXamlInflator) { $pg2.RemoveChild($pg2.MauiXamlInflator) ^| Out-Null }
>>"!PSFILE!" echo     }
>>"!PSFILE!" echo }
>>"!PSFILE!" echo $settings = New-Object System.Xml.XmlWriterSettings
>>"!PSFILE!" echo $settings.Indent = $true
>>"!PSFILE!" echo $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
>>"!PSFILE!" echo $writer = [System.Xml.XmlWriter]::Create($project, $settings)
>>"!PSFILE!" echo $xml.Save($writer)
>>"!PSFILE!" echo $writer.Dispose()
>>"!PSFILE!" echo Write-Host ('[OK] Projekt ustawiony na ' + $tfm)

set "MAUI_PROJECT=!PROJECT!"
set "MAUI_TFM=!TFM!"
set "MAUI_MAJOR=!NET_MAJOR!"

powershell -NoProfile -ExecutionPolicy Bypass -File "!PSFILE!"
set "PS_RESULT=!ERRORLEVEL!"

del /q "!PSFILE!" >nul 2>&1

if not "!PS_RESULT!"=="0" (
    echo [BLAD] Nie udalo sie zmodyfikowac .csproj.
    exit /b 1
)

echo.

rem ============================================================
rem 8. Czyszczenie
rem ============================================================

if exist "!PROJECT_DIR!bin" (
    echo [INFO] Usuwam bin...
    rmdir /s /q "!PROJECT_DIR!bin"
)

if exist "!PROJECT_DIR!obj" (
    echo [INFO] Usuwam obj...
    rmdir /s /q "!PROJECT_DIR!obj"
)

echo.

rem ============================================================
rem 9. MAUI
rem ============================================================

echo ============================================================
echo Instalacja / aktualizacja workloadu MAUI
echo ============================================================
echo.

dotnet workload install maui

if errorlevel 1 (
    echo.
    echo [BLAD] dotnet workload install maui nie powiodlo sie.
    echo.
    echo Aktualne workloady:
    dotnet workload list
    exit /b 1
)

echo.
echo [OK] Workload MAUI gotowy.
echo.

rem ============================================================
rem 10. Restore
rem ============================================================

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

rem ============================================================
rem 11. Build
rem ============================================================

echo ============================================================
echo Build Windows
echo ============================================================
echo.

dotnet build "!PROJECT!" -f "!TFM!"

if errorlevel 1 (
    echo [BLAD] dotnet build nie powiodlo sie.
    exit /b 1
)

echo.
echo [OK] Build zakonczony.
echo.

rem ============================================================
rem 12. run_windows.bat
rem ============================================================

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
echo Uruchomienie:
echo   run_windows.bat
echo.
echo lub:
echo   dotnet build -t:Run -f !TFM! "!PROJECT_NAME!"
echo.
echo Android SDK, JDK i emulator nie byly konfigurowane.
echo.

exit /b 0


rem ============================================================
rem FUNKCJE
rem ============================================================

:FIND_DOTNET

where dotnet >nul 2>&1
if not errorlevel 1 (
    dotnet --info >nul 2>&1
    if not errorlevel 1 exit /b 0
)

if exist "%ProgramFiles%\dotnet\dotnet.exe" (
    set "DOTNET_ROOT=%ProgramFiles%\dotnet"
    set "PATH=%ProgramFiles%\dotnet;%PATH%"
    "%ProgramFiles%\dotnet\dotnet.exe" --info >nul 2>&1
    if not errorlevel 1 exit /b 0
)

if exist "%ProgramFiles(x86)%\dotnet\dotnet.exe" (
    set "PATH=%ProgramFiles(x86)%\dotnet;%PATH%"
    "%ProgramFiles(x86)%\dotnet\dotnet.exe" --info >nul 2>&1
    if not errorlevel 1 exit /b 0
)

exit /b 1


:INSTALL_DOTNET_WINGET

where winget >nul 2>&1
if errorlevel 1 (
    echo [UWAGA] WinGet nie jest dostepny.
    exit /b 1
)

winget install --id Microsoft.DotNet.SDK.10 --exact --source winget --accept-package-agreements --accept-source-agreements

set "WINGET_RESULT=%ERRORLEVEL%"
echo [INFO] Kod wyjscia WinGet: %WINGET_RESULT%

call :REFRESH_PATH

exit /b %WINGET_RESULT%


:INSTALL_DOTNET_SCRIPT

set "DOTNET_INSTALLER=%TEMP%\dotnet-install.ps1"

echo [INFO] Pobieram oficjalny dotnet-install.ps1...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing 'https://dot.net/v1/dotnet-install.ps1' -OutFile '%DOTNET_INSTALLER%'"

if errorlevel 1 (
    echo [BLAD] Nie udalo sie pobrac dotnet-install.ps1.
    exit /b 1
)

echo [INFO] Instaluje .NET 10 SDK x64 do:
echo        %ProgramFiles%\dotnet

powershell -NoProfile -ExecutionPolicy Bypass -File "%DOTNET_INSTALLER%" ^
  -Channel 10.0 ^
  -Architecture x64 ^
  -InstallDir "%ProgramFiles%\dotnet"

set "INSTALL_RESULT=%ERRORLEVEL%"
echo [INFO] Kod wyjscia dotnet-install: %INSTALL_RESULT%

call :REFRESH_PATH

exit /b %INSTALL_RESULT%


:REFRESH_PATH

if exist "%ProgramFiles%\dotnet\dotnet.exe" (
    set "DOTNET_ROOT=%ProgramFiles%\dotnet"
    set "PATH=%ProgramFiles%\dotnet;%PATH%"
)

exit /b 0
