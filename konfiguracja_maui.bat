@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Konfiguracja .NET MAUI

echo ============================================================
echo        AUTOMATYCZNA KONFIGURACJA .NET MAUI
echo ============================================================
echo.

rem ------------------------------------------------------------
rem 0. Sprawdzenie uprawnien administratora
rem ------------------------------------------------------------
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo [INFO] Skrypt wymaga uprawnien administratora.
    echo [INFO] Uruchamiam go ponownie jako administrator...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath '%~f0' -WorkingDirectory '%cd%' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

rem ------------------------------------------------------------
rem 1. Znalezienie projektu MAUI
rem ------------------------------------------------------------
set "PROJECT=%~dp0MauiApp3\MauiApp3.csproj"

if not exist "%PROJECT%" (
    echo [INFO] Nie znaleziono:
    echo        %PROJECT%
    echo [INFO] Szukam pierwszego pliku .csproj w katalogu skryptu...

    set "PROJECT="
    for /r "%~dp0" %%F in (*.csproj) do (
        if not defined PROJECT set "PROJECT=%%F"
    )
)

if defined PROJECT (
    echo [OK] Projekt: !PROJECT!
) else (
    echo [UWAGA] Nie znaleziono pliku .csproj.
    echo         .NET i MAUI zostana zainstalowane,
    echo         ale wersja projektu nie zostanie automatycznie zmieniona.
)
echo.

rem ------------------------------------------------------------
rem 2. Sprawdzenie .NET SDK
rem ------------------------------------------------------------
where dotnet >nul 2>&1

if errorlevel 1 (
    echo [BRAK] Nie znaleziono polecenia dotnet.
    echo [INFO] Instaluję .NET 10 SDK...
    call :InstallDotNet10
    if errorlevel 1 goto :ERROR

    call :RefreshPath

    where dotnet >nul 2>&1
    if errorlevel 1 (
        echo.
        echo [BLAD] .NET zostal zainstalowany, ale polecenie dotnet
        echo        nadal nie jest widoczne w tej sesji.
        echo        Uruchom komputer lub terminal ponownie i odpal skrypt jeszcze raz.
        goto :ERROR
    )
)

rem ------------------------------------------------------------
rem 3. Odczyt wersji .NET
rem ------------------------------------------------------------
for /f "tokens=*" %%V in ('dotnet --version 2^>nul') do set "DOTNET_VERSION=%%V"

if not defined DOTNET_VERSION (
    echo [BLAD] Nie udalo sie odczytac wersji .NET.
    goto :ERROR
)

for /f "tokens=1 delims=." %%M in ("!DOTNET_VERSION!") do set "DOTNET_MAJOR=%%M"

echo [OK] Wykryto .NET SDK: !DOTNET_VERSION!
echo.

rem ------------------------------------------------------------
rem 4. Dobor wersji projektu
rem ------------------------------------------------------------
if !DOTNET_MAJOR! GEQ 10 (
    echo [OK] .NET 10 lub nowszy.
    echo [INFO] Nie zmieniam pliku projektu.
    set "TARGET_NET=10"
    goto :INSTALL_MAUI
)

if "!DOTNET_MAJOR!"=="9" (
    echo [OK] Wykryto .NET 9.
    echo [INFO] Projekt zostanie dostosowany z net10.0 do net9.0.

    if defined PROJECT (
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
          "$p = '%PROJECT%';" ^
          "$c = [IO.File]::ReadAllText($p);" ^
          "if ($c -match 'net10\.0') {" ^
          "  Copy-Item $p ($p + '.bak') -Force;" ^
          "  $c = $c -replace 'net10\.0','net9.0';" ^
          "  [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)));" ^
          "  Write-Host '[OK] Zmieniono net10.0 na net9.0. Kopia: ' ($p + '.bak');" ^
          "} else {" ^
          "  Write-Host '[INFO] W projekcie nie znaleziono net10.0 - brak zmian.';" ^
          "}"

        if errorlevel 1 (
            echo [BLAD] Nie udalo sie zmienic pliku projektu.
            goto :ERROR
        )
    )

    set "TARGET_NET=9"
    goto :INSTALL_MAUI
)

rem ------------------------------------------------------------
rem 5. Starszy .NET
rem ------------------------------------------------------------
echo [UWAGA] Wykryto .NET !DOTNET_VERSION!.
echo [INFO] Do zadania potrzebny jest .NET 9 lub 10.
echo [INFO] Instaluję .NET 10 SDK...

call :InstallDotNet10
if errorlevel 1 goto :ERROR

call :RefreshPath

echo.
echo [INFO] Po instalacji sprawdzam ponownie .NET...

for /f "tokens=*" %%V in ('dotnet --version 2^>nul') do set "DOTNET_VERSION=%%V"
for /f "tokens=1 delims=." %%M in ("!DOTNET_VERSION!") do set "DOTNET_MAJOR=%%M"

if !DOTNET_MAJOR! LSS 10 (
    echo [BLAD] Nadal aktywna jest starsza wersja .NET: !DOTNET_VERSION!
    echo        Zamknij terminal / uruchom komputer ponownie i odpal skrypt jeszcze raz.
    goto :ERROR
)

set "TARGET_NET=10"

rem ------------------------------------------------------------
rem 6. Instalacja MAUI
rem ------------------------------------------------------------
:INSTALL_MAUI
echo.
echo ============================================================
echo Instalacja workloadu .NET MAUI
echo ============================================================
echo.

dotnet workload list | findstr /i /c:"maui" >nul 2>&1
if "%errorlevel%"=="0" (
    echo [OK] Workload MAUI jest juz zainstalowany.
) else (
    echo [INFO] Instaluję .NET MAUI...
    dotnet workload install maui

    if errorlevel 1 (
        echo.
        echo [BLAD] Instalacja workloadu MAUI nie powiodla sie.
        goto :ERROR
    )

    echo [OK] MAUI zostalo zainstalowane.
)

rem ------------------------------------------------------------
rem 7. Przywracanie projektu
rem ------------------------------------------------------------
if defined PROJECT (
    echo.
    echo ============================================================
    echo Przywracanie pakietow projektu
    echo ============================================================
    echo.

    dotnet restore "!PROJECT!"

    if errorlevel 1 (
        echo.
        echo [UWAGA] dotnet restore zakonczyl sie bledem.
        echo         Sama instalacja .NET/MAUI mogla przebiec poprawnie.
        echo         Sprawdz komunikat powyzej.
    ) else (
        echo [OK] Pakiety projektu zostaly przywrocone.
    )
)

rem ------------------------------------------------------------
rem 8. Podsumowanie
rem ------------------------------------------------------------
echo.
echo ============================================================
echo GOTOWE
echo ============================================================
echo.
dotnet --version
echo.
echo Zainstalowane workloady:
dotnet workload list
echo.

if "!TARGET_NET!"=="9" (
    echo Projekt jest przygotowany do pracy na .NET 9.
) else (
    echo Projekt pozostaje na .NET 10.
)

echo.
echo Mozesz teraz otworzyc projekt w Riderze, Visual Studio
echo albo Visual Studio Code.
echo.
pause
exit /b 0


rem ============================================================
rem FUNKCJE
rem ============================================================

:InstallDotNet10
where winget >nul 2>&1

if not errorlevel 1 (
    echo [INFO] Instalacja przez WinGet...
    winget install --id Microsoft.DotNet.SDK.10 --exact ^
        --source winget ^
        --accept-package-agreements ^
        --accept-source-agreements

    if errorlevel 1 (
        echo [BLAD] WinGet nie zainstalowal .NET 10 SDK.
        exit /b 1
    )

    exit /b 0
)

echo [UWAGA] Nie znaleziono WinGet.
echo [INFO] Uzywam oficjalnego skryptu dotnet-install firmy Microsoft...

set "DOTNET_INSTALL=%TEMP%\dotnet-install.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile '%DOTNET_INSTALL%'"

if errorlevel 1 (
    echo [BLAD] Nie udalo sie pobrac instalatora .NET.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%DOTNET_INSTALL%" ^
    -Channel 10.0 ^
    -Architecture x64 ^
    -InstallDir "%ProgramFiles%\dotnet"

if errorlevel 1 (
    echo [BLAD] Instalacja .NET 10 SDK nie powiodla sie.
    exit /b 1
)

setx /M DOTNET_ROOT "%ProgramFiles%\dotnet" >nul
setx /M PATH "%PATH%;%ProgramFiles%\dotnet" >nul

exit /b 0


:RefreshPath
set "PATH=%ProgramFiles%\dotnet;%PATH%"
exit /b 0


:ERROR
echo.
echo ============================================================
echo WYSTAPIL BLAD
echo ============================================================
echo.
echo Przeczytaj komunikat powyzej.
echo Skrypt nie bedzie kontynuowal, zeby nie ukryc problemu.
echo.
pause
exit /b 1
