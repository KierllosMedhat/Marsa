@echo off
chcp 65001 >nul
title Marsa Clinic — Online OTA Update Publisher
cd /d "%~dp0"

echo ========================================================
echo   مرساة — نظام نشر التحديثات الهوائية المباشرة (OTA)
echo ========================================================
echo.
echo [1] نشر تحديث سحابي فوري (بدون انتظار بناء APK - يستغرق ~15 ثانية)
echo [2] نشر تحديث شامل (حزمة سحابية فورية + تحديث ملف APK + رفع إلى GitHub)
echo [3] تحديث رقم الإصدار والإعلان السحابي فقط (فوري)
echo.
set /p choice="اختر نوع التحديث (1 / 2 / 3) [الافتراضي 1]: "
if "%choice%"=="" set choice=1

if "%choice%"=="1" (
    node scripts/publish_ota.mjs --web-only --push
) else if "%choice%"=="2" (
    node scripts/publish_ota.mjs --push
) else (
    node scripts/publish_ota.mjs --manifest-only
)

echo.
pause
