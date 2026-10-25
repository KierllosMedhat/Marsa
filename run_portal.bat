@echo off
title Marsa Clinic Portal - Flutter App Launcher
cd /d "%~dp0flutter_app"
echo Starting Marsa Clinic Portal (Flutter App)...
flutter run -d chrome --web-port 8080
pause
