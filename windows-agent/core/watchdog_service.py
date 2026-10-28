"""
===============================================================================
core/watchdog_service.py - İKİZ NÖBETÇİ VE KAPANAMAZLIK YÖNETİCİSİ (SRP)
===============================================================================
İkiz Nöbetçi (Mutual Watchdog & Anti-Kill) prensibi:
Ana süreç (Main Agent) ile Nöbetçi süreç (Watchdog Guard) birbirini çapraz izler.
Kullanıcı Görev Yöneticisi veya terminalden birini kapatsa dahi, diğeri 0.5 saniyede
yeniden diriltir.
===============================================================================
"""

from __future__ import annotations
import os
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Optional

try:
    import psutil
except ImportError:
    psutil = None

from core.interfaces import IWatchdogManager

IS_WINDOWS = sys.platform == "win32"
CREATE_NO_WINDOW = 0x08000000 if IS_WINDOWS else 0


class TwinWatchdogManager(IWatchdogManager):
    """
    İkiz Nöbetçi Yöneticisi.
    Single Responsibility: Sadece nöbetçi sürecin yaşam döngüsünü ve diriltilmesini sağlar.
    """

    def __init__(self, base_dir: Path, main_pid: Optional[int] = None) -> None:
        self.base_dir = base_dir
        self.main_pid = main_pid or os.getpid()
        self._guard_proc: Optional[subprocess.Popen] = None
        self._running = False
        self._monitor_thread: Optional[threading.Thread] = None

    def start_guard(self) -> None:
        self._running = True
        self._spawn_guard_process()
        self._monitor_thread = threading.Thread(
            target=self._monitor_loop,
            name="TwinWatchdogSupervisor",
            daemon=True,
        )
        self._monitor_thread.start()

    def stop_guard(self) -> None:
        self._running = False
        if self._guard_proc:
            try:
                self._guard_proc.terminate()
            except Exception:
                pass

    def is_guard_alive(self) -> bool:
        if self._guard_proc is None:
            return False
        if self._guard_proc.poll() is not None:
            return False
        if psutil is not None:
            try:
                p = psutil.Process(self._guard_proc.pid)
                return p.is_running() and p.status() != psutil.STATUS_ZOMBIE
            except Exception:
                return False
        return True

    def _spawn_guard_process(self) -> None:
        guard_exe = self.base_dir / "FamilyOS_Guard.exe"
        guard_script = self.base_dir / "watchdog_guard.py"

        if guard_exe.exists():
            cmd = [str(guard_exe), "--target-pid", str(self.main_pid)]
        elif guard_script.exists():
            cmd = [sys.executable, str(guard_script), "--target-pid", str(self.main_pid)]
        else:
            print(f"[WatchdogService] Nöbetçi yürütülebiliri veya betiği bulunamadı: {guard_exe} / {guard_script}")
            return
        kwargs: dict = {
            "cwd": str(self.base_dir),
            "close_fds": True,
        }
        if IS_WINDOWS:
            kwargs["creationflags"] = CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP

        try:
            self._guard_proc = subprocess.Popen(cmd, **kwargs)
            print(f"[WatchdogService] İkiz Nöbetçi devrede. PID: {self._guard_proc.pid}")
        except Exception as e:
            print(f"[WatchdogService] Nöbetçi başlatılamadı: {e}")

    def _monitor_loop(self) -> None:
        while self._running:
            time.sleep(1.0)
            if not self._running:
                break

            # Güncelleme kilit dosyası varsa nöbetçiyi zorla başlatma
            lock_file = self.base_dir / "updating.lock"
            if lock_file.exists():
                continue

            if not self.is_guard_alive():
                print("[WatchdogService] ⚠️ İkiz Nöbetçi sonlandırılmış! Anında yeniden diriltiliyor...")
                self._spawn_guard_process()
