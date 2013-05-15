@echo off
title Zirconium Installer&color 0E&mode con lines=30 cols=75

echo  _________________  _____ _____ _   _ _____ _   ____  ___
echo ^|___  /_   _^| ___ \/  __ \  _  ^| \ ^| ^|_   _^| ^| ^| ^|  \/  ^|
echo    / /  ^| ^| ^| ^|_/ /^| /  \/ ^| ^| ^|  \^| ^| ^| ^| ^| ^| ^| ^| .  . ^|
echo   / /   ^| ^| ^|    / ^| ^|   ^| ^| ^| ^| . ` ^| ^| ^| ^| ^| ^| ^| ^|\/^| ^|
echo ./ /____^| ^|_^| ^|\ \ ^| \__/\ \_/ / ^|\  ^|_^| ^|_^| ^|_^| ^| ^|  ^| ^|
echo \_____/\___/\_^| \_^| \____/\___/\_^| \_/\___/ \___/\_^|  ^|_/                                                     
echo.
echo Zirconium Collector
echo Version 0.11 3/1/2013 lwintringham@psteering.com
echo.
echo Copyright (C) 2013 Lee Wintringham, PowerSteering Software
echo.
echo This program is free software: you can redistribute it and/or modify
echo it under the terms of the GNU General Public License as published by
echo the Free Software Foundation, version 3 of the License.
echo.
echo This program is distributed in the hope that it will be useful,
echo but WITHOUT ANY WARRANTY; without even the implied warranty of
echo MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
echo GNU General Public License for more details.
echo.
echo You should have received a copy of the GNU General Public License
echo along with this program.  If not, see http://www.gnu.org/licenses/
echo.

NET SESSION >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  echo You must have Administrator Privileges to install Zirconium!
  pause
  echo Exiting...
  exit 1
)

echo This will install Zirconium on your system (ctrl+c to cancel)
pause

Set zDir=c:\zirconium\
Set CWD=%~dp0

echo Creating Directories
md "%zDir%"

echo Installing Zirconium
copy /v "%CWD%\bin\zirconium.ps1" "%zDir%"
copy /v "%CWD%\bin\sendStats.bat" "%zDir%"

echo Creating task "Zirconium"
schtasks /create /sc minute /mo 5 /tn "Zirconium" /tr "c:\zirconium\sendStats.bat" /st 00:00

echo Setting Powershell Execution Policy
powershell -command "Set-Executionpolicy unrestricted"

echo Zirconium Installed to %zDir%

pause
echo Exiting...
exit