@echo off
chcp 65001 >nul
:: Yönetici yetkisi kontrolü ve istemi
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [FamilyOS] Yönetici yetkileri alınıyor...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "INSTALL_DIR=%~dp0"
set "AGENT_EXE=%INSTALL_DIR%FamilyOS_Agent.exe"

echo =================================================================
echo   FAMILY-TO-STUDY ENDPOINT AGENT KURULUM VE BAŞLATMA
echo =================================================================
echo.
echo Kurulum Dizini: %INSTALL_DIR%
echo Ajan Programı : %AGENT_EXE%
echo.

if not exist "%AGENT_EXE%" (
    echo [BILGI] Derlenmiş FamilyOS_Agent.exe bulunamadı. Python üzerinden başlatılıyor...
    if exist "%INSTALL_DIR%main.py" (
        start "" python "%INSTALL_DIR%main.py"
        echo [OK] Ajan python üzerinden arka planda başlatıldı.
        timeout /t 3 >nul
        exit /b 0
    ) else (
        echo [HATA] FamilyOS_Agent.exe veya main.py bulunamadı!
        pause
        exit /b 1
    )
)

:: 1. Task Scheduler'a (Görev Zamanlayıcı) en yüksek yetkiyle (HIGHEST) başlangıç görevi ekle
schtasks /create /tn "FamilyOS_Endpoint_Agent" /tr "\"%AGENT_EXE%\"" /sc ONLOGON /rl HIGHEST /f >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Windows Görev Zamanlayıcı başlangıç kaydı başarıyla oluşturuldu.
) else (
    echo [UYARI] Görev Zamanlayıcı kaydı oluşturulamadı, Registry deneniyor...
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "FamilyToStudyEndpointAgent" /t REG_SZ /d "\"%AGENT_EXE%\"" /f >nul 2>&1
)

:: 2. Ajanı hemen arka planda başlat
echo [BILGI] FamilyOS Ajanı başlatılıyor...
start "" "%AGENT_EXE%"

echo.
echo =================================================================
echo   KURULUM BAŞARIYLA TAMAMLANDI!
echo   Ajan arka planda ve her bilgisayar açılışında otomatik çalışacaktır.
echo =================================================================
timeout /t 5 >nul
exit /b 0
