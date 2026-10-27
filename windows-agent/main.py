"""
===============================================================================
main.py - FAMILY-TO-STUDY WINDOWS KIDS ENDPOINT AGENT (SOLID MİMARİSİ)
===============================================================================
Özellikler:
1) Windows Registry (HKCU\\...\\Run) otomatik başlangıç kaydı.
2) İkiz Nöbetçi (Mutual Watchdog & Anti-Kill) koruması.
3) SOLID mimarisine uygun AgentApp orkestrasyonu.
4) Serbest zamanda kullanıcıyı rahatsız etmeyen mini durum kapsülü.
5) Ders modunda engellenemez, kapanamaz tam ekran kilit ve kalkan koruma.
===============================================================================
"""

from __future__ import annotations
import os
import sys
import threading
import time
import traceback

from config import (
    BASE_DIR,
    CONFIG,
)
from system_hooks import register_windows_startup
from agent_app import AgentApp

try:
    from PyQt6.QtWidgets import QApplication
    from PyQt6.QtGui import QIcon
    HAS_PYQT = True
except ImportError:
    HAS_PYQT = False


def main() -> int:
    print("==================================================================")
    print(" FAMILY-TO-STUDY WINDOWS KIDS AGENT (SOLID ARCHITECTURE)")
    print(f" Cihaz ID   : {CONFIG.device_id} ({CONFIG.device_name})")
    print(f" Sürüm      : v{CONFIG.agent_version}")
    print(f" Supabase   : {CONFIG.supabase_url}")
    print("==================================================================")

    # 1. Windows Başlangıcına Otomatik Kayıt (Startup Registry)
    if register_windows_startup():
        print("[Startup] Windows Registry başlangıç kaydı doğrulandı.")

    # 2. PyQt6 Uygulama Örneği
    app = None
    if HAS_PYQT:
        app = QApplication(sys.argv)
        app.setQuitOnLastWindowClosed(False)

        icon_candidate = BASE_DIR / "assets" / "kids.ico"
        if not icon_candidate.exists():
            icon_candidate = BASE_DIR / "assets" / "kids-logo.png"
        if icon_candidate.exists():
            app.setWindowIcon(QIcon(str(icon_candidate)))

    # 3. SOLID Ajan Orkestratörünü Başlat
    agent = AgentApp()
    agent.start()

    # 4. Döngü Yürütme
    if app:
        exit_code = app.exec()
    else:
        # Başsız / CLI / Test modunda canlı tut
        print("[Main] UI kütüphanesi olmadan servis modunda çalışıyor. (Ctrl+C ile durdurun)")
        try:
            while True:
                time.sleep(1.0)
        except KeyboardInterrupt:
            exit_code = 0

    agent.stop()
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
