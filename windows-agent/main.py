"""
===============================================================================
main.py - FAMILY-TO-STUDY WINDOWS ENDPOINT AGENT ANA GİRİŞ NOKTASI
===============================================================================
Özellikler:
- Windows Başlangıç (Registry HKCU\\...\\Run) otomatik kaydı.
- Çift Ajanlı "İkiz Nöbetçi" Mimarisi (Mutual Watchdog & Anti-Kill):
  1) Ana Ajan (`main.py`) başlar başlamaz arka planda penceresiz (`CREATE_NO_WINDOW`)
     olarak `watchdog_guard.py` sürecini başlatır ve her 1 saniyede bir hayatta
     olduğunu kontrol eder. Kapatılırsa anında yeniden başlatır.
  2) İkiz Nöbetçi (`watchdog_guard.py`) de Ana Ajanı her 0.5 saniyede bir izler;
     Ana Ajan sonlandırılırsa 0.5 saniyede diriltir ve `watchdog_agent_restarted`
     ihlalini kaydeder.
- Chromium / QWebEngine otomatik ses çalma bayrağı (--autoplay-policy).
- Global yakalanmamış istisna (sys.excepthook) kurtarma mekanizması.
===============================================================================
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
import traceback
from typing import Optional

try:
    import psutil
except ImportError:
    psutil = None

from config import (
    BASE_DIR,
    CONFIG,
    is_ota_updating,
)
from system_hooks import register_windows_startup

IS_WINDOWS = sys.platform == "win32"
CREATE_NO_WINDOW = 0x08000000 if IS_WINDOWS else 0


class WatchdogKeeperThread(threading.Thread):
    """
    Ana Ajan -> İkiz Nöbetçiyi İzler:
    Arka planda `watchdog_guard.py` sürecini penceresiz çalıştırır ve her 1 saniyede
    bir hayatta olup olmadığını denetler. Kapatılırsa anında yeniden başlatır.
    """

    def __init__(self, main_pid: int) -> None:
        super().__init__(name="WatchdogKeeperThread", daemon=True)
        self.main_pid = main_pid
        self.guard_proc: Optional[subprocess.Popen] = None
        self._running = False

    def _spawn_guard(self) -> None:
        watchdog_script = str(BASE_DIR / "watchdog_guard.py")
        cmd = [sys.executable, watchdog_script, "--target-pid", str(self.main_pid)]
        kwargs: dict = {
            "cwd": str(BASE_DIR),
            "close_fds": True,
        }
        if IS_WINDOWS:
            kwargs["creationflags"] = CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP

        try:
            self.guard_proc = subprocess.Popen(cmd, **kwargs)
            print(f"[MainKeeper] İkiz Nöbetçi (Watchdog Guard) başlatıldı. PID: {self.guard_proc.pid}")
        except Exception as err:
            print(f"[MainKeeper] Watchdog Guard başlatma hatası: {err}")

    def is_guard_alive(self) -> bool:
        if self.guard_proc is None:
            return False
        if self.guard_proc.poll() is not None:
            return False
        if psutil is not None:
            try:
                p = psutil.Process(self.guard_proc.pid)
                return p.is_running() and p.status() != psutil.STATUS_ZOMBIE
            except Exception:
                return False
        return True

    def stop(self) -> None:
        self._running = False
        if self.guard_proc:
            try:
                self.guard_proc.terminate()
            except Exception:
                pass

    def run(self) -> None:
        self._running = True
        self._spawn_guard()

        while self._running:
            time.sleep(1.0)
            if not self._running:
                break
            # OTA güncellemesi yapılıyorsa nöbetçiyi yeniden başlatma
            if is_ota_updating():
                continue

            if not self.is_guard_alive():
                print("[MainKeeper] ⚠️ İkiz Nöbetçi sonlandırılmış! Anında yeniden başlatılıyor...")
                self._spawn_guard()


def run_pyqt_endpoint_worker() -> int:
    """PyQt6 WebEngine Widget ve Tam Ekran Kilit arayüzünü başlatır."""
    os.environ.setdefault(
        "QTWEBENGINE_CHROMIUM_FLAGS",
        "--autoplay-policy=no-user-gesture-required --disable-features=HardwareMediaKeyHandling",
    )

    from PyQt6.QtWidgets import QApplication
    from agent_ui import StudentEndpointWindow

    def global_exception_handler(exc_type, exc_value, exc_tb):
        err_text = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
        print(f"[Main] Yakalanan çalışma zamanı hatası:\n{err_text}")

    sys.excepthook = global_exception_handler

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    window = StudentEndpointWindow()
    window.show()

    return app.exec()


def main() -> None:
    print("==================================================================")
    print(" FAMILY-TO-STUDY WINDOWS ENDPOINT AGENT (FAZ 5 FİNAL) BAŞLATILDI")
    print(f" Öğrenci ID : {CONFIG.user_id}")
    print(f" Cihaz ID   : {CONFIG.device_id} ({CONFIG.device_name})")
    print(f" Sürüm      : v{CONFIG.agent_version}")
    print(f" PWA Adresi : {CONFIG.pwa_url}")
    print("==================================================================")

    # 1. Windows Başlangıcına (Startup Registry) kendini otomatik kaydet
    if register_windows_startup():
        print("[Startup] Windows Registry başlangıç kaydı doğrulandı.")

    # 2. İkiz Nöbetçi (Watchdog Guard) koruyucu iş parçacığını başlat
    main_pid = os.getpid()
    keeper = WatchdogKeeperThread(main_pid=main_pid)
    keeper.start()

    # 3. PyQt6 Arayüzünü çalıştır
    exit_code = run_pyqt_endpoint_worker()

    # Çıkışta keeper'ı durdur
    keeper.stop()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
