@echo off
rem Uploads build\windows to the game's Steam depot (app 5375170, depot 5375171).
rem   upload_game.bat           upload; set it live by hand in Steamworks
rem   upload_game.bat beta      upload and set it live on the "beta" branch
rem   upload_game.bat preview   list what would go up, upload nothing
rem Export the "Windows" preset from the editor first: this uploads the folder as it is.
rem It copies GodotSteam's licence beside the exe (MIT: it travels with the DLL) and refuses
rem a folder holding steam_appid.txt, which is for dev runs only.
rem steamcmd asks for the password and Steam Guard code itself; the login is cached after.
setlocal

set "HERE=%~dp0"
set "STEAMCMD=C:\Users\Administrador\Desktop\Steam\sdk\tools\ContentBuilder\builder\steamcmd.exe"
set "VDF=%HERE%app_build_5375170.vdf"
set "CONTENT=%HERE%..\..\build\windows"
set "LICENSE=%HERE%..\..\addons\godotsteam\license.md"
set "ACCOUNT=fxknox"

if not exist "%STEAMCMD%" (
	echo steamcmd not found at %STEAMCMD%
	goto fail
)
if not exist "%CONTENT%\MyDirtyLittleLake.exe" (
	echo No MyDirtyLittleLake.exe in build\windows. Export the "Windows" preset first.
	goto fail
)
if not exist "%CONTENT%\MyDirtyLittleLake.pck" (
	echo No MyDirtyLittleLake.pck in build\windows. Export the "Windows" preset first.
	goto fail
)
if exist "%CONTENT%\steam_appid.txt" (
	echo build\windows holds steam_appid.txt. It is for dev runs only: delete it and run again.
	goto fail
)
if exist "%CONTENT%\LakeCleanup.exe" (
	echo build\windows still holds the old LakeCleanup.exe and .pck. Delete them and run again.
	goto fail
)
if not exist "%LICENSE%" (
	echo GodotSteam licence not found at %LICENSE%
	goto fail
)
copy /y "%LICENSE%" "%CONTENT%\GodotSteam_LICENSE.md" >nul
if not exist "%HERE%..\..\build\steampipe" mkdir "%HERE%..\..\build\steampipe"

for /f %%i in ('git -C "%HERE%." rev-parse --short HEAD 2^>nul') do set "COMMIT=%%i"
if not defined COMMIT set "COMMIT=nogit"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH:mm"') do set "STAMP=%%i"
set "DESC=Game %STAMP% %COMMIT%"

set "PREVIEW="
set "BRANCH="
if /i "%~1"=="preview" set "PREVIEW=-preview"
if /i "%~1"=="beta" set "BRANCH=beta"
if defined BRANCH (
	set "DESC=%DESC% beta"
	powershell -NoProfile -Command "(Get-Content -LiteralPath '%VDF%') -replace '\"SetLive\" \"\"', '\"SetLive\" \"beta\"' | Set-Content -LiteralPath '%HERE%app_build_5375170_beta.tmp.vdf'"
	set "VDF=%HERE%app_build_5375170_beta.tmp.vdf"
)

echo.
echo Uploading build\windows:
for %%f in ("%CONTENT%\*") do echo   %%~tf  %%~zf  %%~nxf
echo Description: %DESC%
if defined PREVIEW echo PREVIEW ONLY: nothing will be uploaded.
if defined BRANCH echo Goes live on the beta branch.
echo.
pause

"%STEAMCMD%" +login %ACCOUNT% +run_app_build -desc "%DESC%" %PREVIEW% "%VDF%" +quit
if errorlevel 1 goto fail
if defined BRANCH del "%HERE%app_build_5375170_beta.tmp.vdf" 2>nul

echo.
if defined PREVIEW (
	echo Preview done. Log in build\steampipe.
) else if defined BRANCH (
	echo Uploaded and live on beta. Testers pick the branch in the game's Betas tab.
) else (
	echo Uploaded. Set it live in Steamworks: SteamPipe ^> Builds, app 5375170.
)
pause
exit /b 0

:fail
if defined BRANCH del "%HERE%app_build_5375170_beta.tmp.vdf" 2>nul
echo.
echo Upload did not run.
pause
exit /b 1
