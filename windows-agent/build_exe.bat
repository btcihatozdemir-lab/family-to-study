@echo off
chcp 65001 >nul
title FamilyToStudy - PyQt6 Endpoint Agent .EXE Derleyici
echo ============================================================================
echo FAMILY-TO-STUDY: PYQT6 ENDPOINT AGENT TEK DOSYA (.EXE) DERLEYİCİ
echo ============================================================================

cd /d "%~dp0"
pip install -r requirements.txt

echo FamilyToStudyAgent.exe derleniyor...
pyinstaller --noconfirm --onefile --windowed --icon "assets\kids.ico" --add-data "assets;assets" --add-data "locales;locales" --name "FamilyToStudyAgent" main.py

echo.
echo ✅ Derleme tamamlandı! "dist\FamilyToStudyAgent.exe" dosyasını kullanabilirsiniz.
pause
