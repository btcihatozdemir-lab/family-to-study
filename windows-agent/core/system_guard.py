"""
===============================================================================
core/system_guard.py - İŞLETİM SİSTEMİ KANCA VE KORUMA MOTORU (LSP & SRP)
===============================================================================
Windows ortamında Win32 API ile Alt+Tab, Alt+F4, Windows tuşunu ve Görev
Yöneticisi'ni engeller. Windows harici ortamlarda (Linux/Geliştirme)
Liskov İkame Prensibine (LSP) tam uygun FallbackGuard devreye girer.
===============================================================================
"""

from __future__ import annotations
import ctypes
import os
import sys
import threading
import time
from typing import Any, Callable, Optional

from core.interfaces import ISystemGuard

IS_WINDOWS = sys.platform == "win32"

if IS_WINDOWS:
    try:
        import win32api
        import win32con
        import win32gui
        import win32process
        import winreg
    except ImportError:
        win32api = None
        win32con = None
        win32gui = None
        win32process = None
        winreg = None
else:
    win32api = None
    win32con = None
    win32gui = None
    win32process = None
    winreg = None

try:
    import psutil
except ImportError:
    psutil = None


# ------------------------------------------------------------------------------
# 1. WINDOWS WIN32 UYGULAMASI (KATI ENGELLEME & KANCA)
# ------------------------------------------------------------------------------
class Win32SystemGuard(ISystemGuard):
    """
    Windows üzerinde çalışan katı sistem koruyucusu.
    - Düşük seviyeli klavye kancasıyla (WH_KEYBOARD_LL) kaçış tuşlarını yutar.
    - Görev Yöneticisi'ni kapatır.
    - Kilit ekranını her zaman en üstte (HWND_TOPMOST) tutar.
    """

    WH_KEYBOARD_LL = 13
    WM_KEYDOWN = 0x0100
    WM_SYSKEYDOWN = 0x0104
    LLKHF_ALTDOWN = 0x20

    VK_TAB = 0x09
    VK_ESCAPE = 0x1B
    VK_F4 = 0x73
    VK_LWIN = 0x5B
    VK_RWIN = 0x5C

    def __init__(self, on_violation_callback: Optional[Callable[[str], None]] = None) -> None:
        self._on_violation = on_violation_callback
        self._hook_id: Optional[int] = None
        self._hook_thread: Optional[threading.Thread] = None
        self._taskmgr_killer_thread: Optional[threading.Thread] = None
        self._taskmgr_killer_running = False
        self._lock = threading.Lock()

    def start_hooks(self) -> bool:
        if not IS_WINDOWS or not hasattr(ctypes, "windll"):
            return False

        with self._lock:
            if self._hook_thread and self._hook_thread.is_alive():
                return True

            self._hook_thread = threading.Thread(
                target=self._run_hook_loop,
                name="Win32HookThread",
                daemon=True,
            )
            self._hook_thread.start()

            # Task Manager Katilini de Başlat
            self._taskmgr_killer_running = True
            self._taskmgr_killer_thread = threading.Thread(
                target=self._run_taskmgr_killer_loop,
                name="TaskMgrKillerThread",
                daemon=True,
            )
            self._taskmgr_killer_thread.start()

        print("[SystemGuard] Win32 düşük seviyeli klavye kancası ve TaskMgr katili devrede.")
        return True

    def stop_hooks(self) -> None:
        with self._lock:
            self._taskmgr_killer_running = False
            if self._hook_id and IS_WINDOWS:
                try:
                    ctypes.windll.user32.UnhookWindowsHookEx(self._hook_id)
                except Exception:
                    pass
                self._hook_id = None
        print("[SystemGuard] Win32 kancaları serbest bırakıldı.")

    def _run_hook_loop(self) -> None:
        HOOKPROC = ctypes.WINFUNCTYPE(
            ctypes.c_long, ctypes.c_int, ctypes.c_ulong, ctypes.c_void_p
        )

        def _hook_callback(n_code: int, w_param: int, l_param: int) -> int:
            if n_code >= 0 and w_param in (self.WM_KEYDOWN, self.WM_SYSKEYDOWN):
                vk_code = ctypes.c_ulong.from_address(l_param).value
                flags = ctypes.c_ulong.from_address(l_param + 8).value
                is_alt = bool(flags & self.LLKHF_ALTDOWN)

                # Alt + F4 (Kapatma girişimi)
                if is_alt and vk_code == self.VK_F4:
                    if self._on_violation:
                        self._on_violation("alt_f4_escape_attempt")
                    return 1  # Tuşu yut, sisteme iletme

                # Alt + Tab (Pencere değiştirme)
                if is_alt and vk_code == self.VK_TAB:
                    return 1

                # Windows Tuşları (Başlat menüsü kaçışı)
                if vk_code in (self.VK_LWIN, self.VK_RWIN):
                    return 1

                # Ctrl + Esc (Başlat menüsü kaçışı)
                if vk_code == self.VK_ESCAPE and (ctypes.windll.user32.GetKeyState(0x11) & 0x8000):
                    return 1

            return ctypes.windll.user32.CallNextHookEx(self._hook_id, n_code, w_param, l_param)

        self._callback_ref = HOOKPROC(_hook_callback)
        self._hook_id = ctypes.windll.user32.SetWindowsHookExW(
            self.WH_KEYBOARD_LL,
            self._callback_ref,
            ctypes.windll.kernel32.GetModuleHandleW(None),
            0,
        )

        # Mesaj döngüsü (Kancanın canlı kalması için gerekli)
        msg = ctypes.wintypes.MSG()
        while self._hook_id:
            res = ctypes.windll.user32.GetMessageW(ctypes.byref(msg), None, 0, 0)
            if res <= 0:
                break
            ctypes.windll.user32.TranslateMessage(ctypes.byref(msg))
            ctypes.windll.user32.DispatchMessageW(ctypes.byref(msg))

    def _run_taskmgr_killer_loop(self) -> None:
        while self._taskmgr_killer_running:
            self.terminate_task_manager()
            time.sleep(0.3)

    def terminate_task_manager(self) -> bool:
        if not psutil:
            return False
        killed = False
        try:
            for p in psutil.process_iter(["name", "pid"]):
                name = (p.info.get("name") or "").lower()
                if name in ("taskmgr.exe", "procexp.exe", "processhacker.exe"):
                    try:
                        p.kill()
                        killed = True
                        if self._on_violation:
                            self._on_violation("task_manager_kill_attempt")
                        print(f"[SystemGuard] İzinsiz süreç sonlandırıldı: {name}")
                    except Exception:
                        pass
        except Exception:
            pass
        return killed

    def enforce_window_topmost(self, window_handle: Any) -> None:
        if not IS_WINDOWS or not window_handle:
            return
        try:
            hwnd = int(window_handle)
            # HWND_TOPMOST = -1, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW = 0x0043
            ctypes.windll.user32.SetWindowPos(hwnd, -1, 0, 0, 0, 0, 0x0043)
            ctypes.windll.user32.SetForegroundWindow(hwnd)
        except Exception:
            pass

    def get_foreground_app_title(self) -> str:
        if not IS_WINDOWS or not win32gui:
            return "Bilinmeyen Pencere"
        try:
            hwnd = win32gui.GetForegroundWindow()
            if hwnd:
                return win32gui.GetWindowText(hwnd).strip() or "Masaüstü"
        except Exception:
            pass
        return "Bilinmeyen"


# ------------------------------------------------------------------------------
# 2. CROSS-PLATFORM FALLBACK UYGULAMASI (LINUX & BİRİM TESTLERİ İÇİN LSP)
# ------------------------------------------------------------------------------
class FallbackSystemGuard(ISystemGuard):
    """
    Windows dışı platformlarda veya test senaryolarında Win32 API'yi taklit eder.
    Sistemi kırmadan koruma mantığını yürütür ve birim testlerinin her yerde
    sorunsuz koşmasını sağlar.
    """

    def __init__(self, on_violation_callback: Optional[Callable[[str], None]] = None) -> None:
        self._on_violation = on_violation_callback
        self._active = False
        self._blocked_attempts_count = 0

    def start_hooks(self) -> bool:
        self._active = True
        return True

    def stop_hooks(self) -> None:
        self._active = False

    def terminate_task_manager(self) -> bool:
        # Testlerde ve Linux'ta psutil üzerinden kontrol
        return False

    def enforce_window_topmost(self, window_handle: Any) -> None:
        pass

    def get_foreground_app_title(self) -> str:
        return "FamilyToStudy Agent (Test Environment)"

    def simulate_alt_f4_attempt(self) -> None:
        """Birim testleri için Alt+F4 saldırı simülasyonu."""
        self._blocked_attempts_count += 1
        if self._on_violation:
            self._on_violation("simulated_alt_f4_attempt")


# ------------------------------------------------------------------------------
# FACTORY METHOD (DEPENDENCY INJECTION İÇİN FABRİKA)
# ------------------------------------------------------------------------------
def create_system_guard(on_violation: Optional[Callable[[str], None]] = None) -> ISystemGuard:
    """Platforma göre en uygun ISystemGuard implementasyonunu döndürür."""
    if IS_WINDOWS:
        return Win32SystemGuard(on_violation_callback=on_violation)
    return FallbackSystemGuard(on_violation_callback=on_violation)
