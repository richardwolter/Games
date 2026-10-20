@echo off
rem Exports the demo and uploads it to its Steam depot (app 5426290, depot 5426291).
rem   upload_demo.bat           upload; set it live by hand in Steamworks
rem   upload_demo.bat preview   export and list what would go up, upload nothing
rem It empties build\windows_demo, exports the "Windows Demo" preset (release) into it with the
rem Desktop Godot, copies GodotSteam's licence beside the exe (MIT: it travels with the DLL) and
rem refuses a folder holding steam_appid.txt, which is for dev runs only. Export log:
rem build\steampipe\export_demo.log.
rem steamcmd asks for the password and Steam Guard code itself; the login is cached after.
rem The build is not set live: do that in Steamworks, SteamPipe > Builds.
setlocal

set "HERE=%~dp0"
set "STEAMCMD=C:\Users\Administrador\Desktop\Steam\sdk\tools\ContentBuilder\builder\steamcmd.exe"
set "GODOT=C:\Users\Administrador\Desktop\Godot_v4.7.1-stable_win64.exe"
set "PROJECT=%HERE%..\.."
set "VDF=%HERE%app_build_5426290.vdf"
set "CONTENT=%HERE%..\..\build\windows_demo"
set "OUTPUT=%HERE%..\..\build\steampipe"
set "LICENSE=%HERE%..\..\addons\godotsteam\license.md"
set "ACCOUNT=fxknox"

if not exist "%STEAMCMD%" (
	echo steamcmd not found at %STEAMCMD%
	goto fail
)
if not exist "%GODOT%" (
	echo Godot not found at %GODOT%
	goto fail
)
if not exist "%LICENSE%" (
	echo GodotSteam licence not found at %LICENSE%
	goto fail
)
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

echo Exporting the "Windows Demo" preset into build\windows_demo...
if exist "%CONTENT%" rmdir /s /q "%CONTENT%"
mkdir "%CONTENT%"
"%GODOT%" --headless --path "%PROJECT%" --export-release "Windows Demo" "%CONTENT%\MyDirtyLittleLakeDemo.exe" --log-file "%OUTPUT%\export_demo.log" >nul 2>&1
if not exist "%CONTENT%\MyDirtyLittleLakeDemo.exe" (
	echo Export made no MyDirtyLittleLakeDemo.exe. See build\steampipe\export_demo.log.
	goto fail
)
if not exist "%CONTENT%\MyDirtyLittleLakeDemo.pck" (
	echo Export made no MyDirtyLittleLakeDemo.pck. See build\steampipe\export_demo.log.
	goto fail
)
if exist "%CONTENT%\steam_appid.txt" (
	echo build\windows_demo holds steam_appid.txt. It is for dev runs only: check the export filters.
	goto fail
)
copy /y "%LICENSE%" "%CONTENT%\GodotSteam_LICENSE.md" >nul

for /f %%i in ('git -C "%HERE%." rev-parse --short HEAD 2^>nul') do set "COMMIT=%%i"
if not defined COMMIT set "COMMIT=nogit"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH:mm"') do set "STAMP=%%i"
set "DESC=Demo %STAMP% %COMMIT%"

set "PREVIEW="
if /i "%~1"=="preview" set "PREVIEW=-preview"

echo.
echo Uploading build\windows_demo:
for %%f in ("%CONTENT%\*") do echo   %%~tf  %%~zf  %%~nxf
echo Description: %DESC%
if defined PREVIEW echo PREVIEW ONLY: nothing will be uploaded.
echo.
pause

"%STEAMCMD%" +login %ACCOUNT% +run_app_build -desc "%DESC%" %PREVIEW% "%VDF%" +quit
if errorlevel 1 goto fail

echo.
if defined PREVIEW (
	echo Preview done. Log in build\steampipe.
) else (
	echo Uploaded. Set it live in Steamworks: SteamPipe ^> Builds, app 5426290.
)
pause
exit /b 0

:fail
echo.
echo Upload did not run.
pause
exit /b 1
