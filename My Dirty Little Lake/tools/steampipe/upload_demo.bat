@echo off
rem Uploads build\windows_demo to the demo's Steam depot (app 5426290, depot 5426291).
rem   upload_demo.bat           upload
rem   upload_demo.bat preview   list what would go up, upload nothing
rem Export the "Windows Demo" preset from the editor first: this uploads the folder as it is.
rem steamcmd asks for the password and Steam Guard code itself; the login is cached after.
rem The build is not set live: do that in Steamworks, SteamPipe > Builds.
setlocal

set "HERE=%~dp0"
set "STEAMCMD=C:\Users\Administrador\Desktop\Steam\sdk\tools\ContentBuilder\builder\steamcmd.exe"
set "VDF=%HERE%app_build_5426290.vdf"
set "CONTENT=%HERE%..\..\build\windows_demo"
set "ACCOUNT=fxknox"

if not exist "%STEAMCMD%" (
	echo steamcmd not found at %STEAMCMD%
	goto fail
)
if not exist "%CONTENT%\MyDirtyLittleLakeDemo.exe" (
	echo No MyDirtyLittleLakeDemo.exe in build\windows_demo. Export the "Windows Demo" preset first.
	goto fail
)
if not exist "%CONTENT%\MyDirtyLittleLakeDemo.pck" (
	echo No MyDirtyLittleLakeDemo.pck in build\windows_demo. Export the "Windows Demo" preset first.
	goto fail
)
if not exist "%HERE%..\..\build\steampipe" mkdir "%HERE%..\..\build\steampipe"

for /f %%i in ('git -C "%HERE%." rev-parse --short HEAD 2^>nul') do set "COMMIT=%%i"
if not defined COMMIT set "COMMIT=nogit"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH:mm"') do set "STAMP=%%i"
set "DESC=Demo %STAMP% %COMMIT%"

echo.
echo Uploading build\windows_demo:
for %%f in ("%CONTENT%\*") do echo   %%~tf  %%~zf  %%~nxf
echo Description: %DESC%

set "PREVIEW="
if /i "%~1"=="preview" (
	set "PREVIEW=-preview"
	echo PREVIEW ONLY: nothing will be uploaded.
)
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
