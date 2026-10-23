@echo off
rem Records one take of the vertical gameplay short (tools/play_video.gd).
rem Plays in a portrait window as tall as the screen; the take is 1080x1920. F10 ends it.
cd /d "%~dp0.."
echo.
echo   Beats: casts, wash, house, tornado   (Enter = casts)
set /p BEAT=  Which beat? 
if "%BEAT%"=="" set BEAT=casts
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set STAMP=%%i
if not exist tools\film\short\takes mkdir tools\film\short\takes
set TAKE=tools\film\short\takes\%BEAT%_%STAMP%
(echo [editor]& echo movie_writer/mjpeg_quality=0.92& echo [display]& echo window/size/viewport_width=1080& echo window/size/viewport_height=1920) > override.cfg
set PLAY_VIDEO_BEAT=%BEAT%
echo   Recording %TAKE%.avi   (F10 ends the take)
"C:\Users\Administrador\Desktop\Godot_v4.7.1-stable_win64.exe" --path . --fixed-fps 30 --write-movie "%CD%\%TAKE%.avi" res://tools/play_video.tscn --log-file "%TAKE%.log"
del override.cfg
echo   Done: %TAKE%.avi
pause
