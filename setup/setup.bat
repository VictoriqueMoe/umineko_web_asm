@echo off
cd /d "%~dp0.."
wsl sed -i "s/\r$//" ./setup/setup.sh 2>nul
wsl bash ./setup/setup.sh
