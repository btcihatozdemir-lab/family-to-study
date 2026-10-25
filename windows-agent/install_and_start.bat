@echo off
chcp 65001 >nul
title FamilyToStudy - PyQt6 Windows Endpoint Agent Kurulumu
echo ============================================================================
echo FAMILY-TO-STUDY: PYQT6 WEBENGINE WIDGET VE KİLİT AJANI KURULUMU
echo ============================================================================

cd /d "%~dp0"

echo [1/2] Python 3.11+ ve PyQt6 / Win32 bağımlılıkları yükleniyor...
pip install -r requirements.txt

echo [2/2] Ajan başlatılıyor (Windows Registry Startup kaydı main.py tarafından otomatik yapılır)...
start "" pythonw main.py
echo ✅ Ajan arka planda başlatıldı!
pause
