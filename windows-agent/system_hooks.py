"""
===============================================================================
2. system_hooks.py - WIN32 SİSTEM KANCALARI, DONANIM SES, SENSÖR VE EKRAN MOTORU
===============================================================================
İçerik:
- Düşük seviyeli klavye kancası (SetWindowsHookExW / WH_KEYBOARD_LL):
  Alt+F4, Alt+Tab, Win tuşu, Ctrl+Esc, Ctrl+Shift+Esc engelleme.
- GetLastInputInfo (ctypes.windll.user32):
  STUDY_TIME sırasında izinsiz fare/klavye hareketini milisaniyelik yakalama.
- Taskmgr.exe (Görev Yöneticisi) engelleme ve SetForegroundWindow zorlama.
- pycaw ile Windows Master Volume'ü Mute'dan çıkarma ve %80'e yükseltme.
- win32gui ile aktif pencere başlığını okuma.
- mss ile anlık ekran görüntüsü yakalama ve Supabase Storage yükleme hazırlığı.
- Windows Registry (HKCU\\...\\Run) ve Task Scheduler başlangıç kaydı.
===============================================================================
"""

from __future__ import annotations

import ctypes
from ctypes import wintypes
from datetime import datetime
import io
import os
import queue
import subprocess
import sys
import threading
import time
from typing import Callable, Optional

# Platforma özgü kütüphaneleri güvenli içe aktar
IS_WINDOWS = sys.platform == "win32"

if IS_WINDOWS:
    import winreg
    try:
        import win32api
        import win32con
        import win32gui
        import win32process
    except ImportError:
        win32api = None
        win32con = None
        win32gui = None
        win32process = None

    try:
        import win32com.client as win32com_client
    except ImportError:
        win32com_client = None

    try:
        import comtypes
        from ctypes import cast, POINTER
        from comtypes import CLSCTX_ALL
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume, ISimpleAudioVolume
    except ImportError:
        comtypes = None
        AudioUtilities = None
        IAudioEndpointVolume = None
        ISimpleAudioVolume = None
else:
    winreg = None
    win32api = None
    win32con = None
    win32gui = None
    win32process = None
    win32com_client = None
    comtypes = None
    AudioUtilities = None
    IAudioEndpointVolume = None
    ISimpleAudioVolume = None

try:
    import pyttsx3
except Exception:
    pyttsx3 = None

try:
    import psutil
except ImportError:
    psutil = None

try:
    import mss
    import mss.tools
except ImportError:
    mss = None

try:
    import numpy as np
except ImportError:
    np = None

try:
    import sounddevice as sd
except Exception:
    sd = None


# ==============================================================================
# 1. CTYPES STRUCT & SABİTLER (GetLastInputInfo ve WH_KEYBOARD_LL için)
# ==============================================================================
WH_KEYBOARD_LL = 13
WM_KEYDOWN = 0x0100
WM_SYSKEYDOWN = 0x0104
LLKHF_ALTDOWN = 0x20

VK_TAB = 0x09
VK_ESCAPE = 0x1B
VK_F4 = 0x73
VK_LWIN = 0x5B
VK_RWIN = 0x5C
VK_CONTROL = 0x11
VK_LCONTROL = 0xA2
VK_RCONTROL = 0xA3
VK_SHIFT = 0x10
VK_DELETE = 0x2E

# Güç Yönetimi ve Monitör Uyandırma Sabitleri (SetThreadExecutionState)
ES_CONTINUOUS = 0x80000000
ES_SYSTEM_REQUIRED = 0x00000001
ES_DISPLAY_REQUIRED = 0x00000002

HWND_BROADCAST = 0xFFFF
WM_SYSCOMMAND = 0x0112
SC_MONITORPOWER = 0xF170
MOUSEEVENTF_MOVE = 0x0001


class LASTINPUTINFO(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.UINT),
        ("dwTime", wintypes.DWORD),
    ]


class KBDLLHOOKSTRUCT(ctypes.Structure):
    _fields_ = [
        ("vkCode", wintypes.DWORD),
        ("scanCode", wintypes.DWORD),
        ("flags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong)),
    ]


# ==============================================================================
# 2. SON GİRDİ ZAMANI VE İZİNSİZ HAREKET SENSÖRÜ (GetLastInputInfo)
# ==============================================================================
class InputActivityTracker:
    """
    ctypes.windll.user32.GetLastInputInfo kullanarak fare ve klavye
    hareketlerini izler. STUDY_TIME sırasında izinli alan dışında bir
    aktivite olduğunda ('pc_mouse_move' veya 'pc_key_press') tespit eder.
    """

    def __init__(self) -> None:
        self._last_recorded_tick: int = self.get_last_input_tick()
        self._last_cursor_pos: tuple[int, int] = self.get_cursor_pos()
        self._ignore_synthetic_until: float = 0.0

    def mark_synthetic_input(self, grace_seconds: float = 2.0) -> None:
        """
        Sabah alarmında monitörü uyandırmak için gönderilen 1 piksellik sanal
        fare hareketinin ihlal (violation) olarak algılanmasını engeller.
        """
        try:
            self._ignore_synthetic_until = time.time() + grace_seconds
            self._last_recorded_tick = self.get_last_input_tick()
            self._last_cursor_pos = self.get_cursor_pos()
        except Exception:
            pass

    @staticmethod
    def get_last_input_tick() -> int:
        """Son kullanıcı girdisinin sistem tick (ms) zamanını döndürür."""
        if not IS_WINDOWS:
            return int(time.time() * 1000)
        try:
            lii = LASTINPUTINFO()
            lii.cbSize = ctypes.sizeof(LASTINPUTINFO)
            if ctypes.windll.user32.GetLastInputInfo(ctypes.byref(lii)):
                return int(lii.dwTime)
        except Exception:
            pass
        return 0

    @staticmethod
    def get_idle_duration_ms() -> int:
        """Kullanıcının kaç milisaniyedir fare/klavyeye dokunmadığını döndürür."""
        if not IS_WINDOWS:
            return 999999
        try:
            tick_now = ctypes.windll.kernel32.GetTickCount()
            last_tick = InputActivityTracker.get_last_input_tick()
            return max(0, int(tick_now - last_tick))
        except Exception:
            return 999999

    @staticmethod
    def get_cursor_pos() -> tuple[int, int]:
        if IS_WINDOWS and win32api:
            try:
                return win32api.GetCursorPos()
            except Exception:
                pass
        return (0, 0)

    def detect_violation_input_type(self) -> Optional[str]:
        """
        Son kontrol anından bu yana yeni bir girdi olduysa:
        - Fare konumu değiştiyse 'pc_mouse_move'
        - Klavye tuşuna basıldıysa 'pc_key_press'
        döndürür. Aktivite yoksa veya sanal uyandırma sinyali ise None döndürür.
        """
        try:
            current_tick = self.get_last_input_tick()
            if current_tick == self._last_recorded_tick:
                return None

            self._last_recorded_tick = current_tick
            current_pos = self.get_cursor_pos()

            if time.time() < self._ignore_synthetic_until:
                self._last_cursor_pos = current_pos
                return None

            # Fare pozisyonu değiştiyse
            dx = abs(current_pos[0] - self._last_cursor_pos[0])
            dy = abs(current_pos[1] - self._last_cursor_pos[1])
            self._last_cursor_pos = current_pos

            if dx > 12 or dy > 12:
                return "pc_mouse_move"
            return "pc_key_press"
        except Exception as err:
            print(f"[SystemHooks] Girdi sensörü okuma hatası: {err}")
            return None


# ==============================================================================
# 3. DÜŞÜK SEVİYELİ WIN32 KLAVYE KANCASI (WH_KEYBOARD_LL)
# ==============================================================================
class LowLevelKeyboardBlocker:
    """
    SetWindowsHookExW (WH_KEYBOARD_LL) kullanarak kilit modundayken:
    Alt+F4, Alt+Tab, Win tuşu, Ctrl+Esc, Ctrl+Shift+Esc kısayollarını
    işletim sistemi seviyesinde engeller.
    """

    def __init__(
        self,
        on_blocked_shortcut_callback: Optional[Callable[[str], None]] = None,
    ) -> None:
        self.blocking_enabled: bool = False
        self.on_blocked_shortcut = on_blocked_shortcut_callback
        self._hook_id: Optional[int] = None
        self._thread: Optional[threading.Thread] = None
        self._running: bool = False
        self._hook_proc_ref = None  # Garbage collection'ı önlemek için referans

    def start(self) -> None:
        if not IS_WINDOWS or self._running:
            return
        self._running = True
        self._thread = threading.Thread(
            target=self._hook_loop,
            name="Win32KeyboardHookThread",
            daemon=True,
        )
        self._thread.start()

    def set_blocking(self, enabled: bool) -> None:
        self.blocking_enabled = enabled

    def _hook_loop(self) -> None:
        try:
            user32 = ctypes.windll.user32
            kernel32 = ctypes.windll.kernel32

            HOOKPROC = ctypes.WINFUNCTYPE(
                ctypes.c_long,
                ctypes.c_int,
                wintypes.WPARAM,
                wintypes.LPARAM,
            )

            def low_level_keyboard_proc(nCode: int, wParam: int, lParam: int) -> int:
                if nCode == 0 and self.blocking_enabled:
                    if wParam in (WM_KEYDOWN, WM_SYSKEYDOWN):
                        kb = ctypes.cast(lParam, ctypes.POINTER(KBDLLHOOKSTRUCT)).contents
                        vk = kb.vkCode
                        alt_down = bool(kb.flags & LLKHF_ALTDOWN)
                        ctrl_down = bool(user32.GetAsyncKeyState(VK_CONTROL) & 0x8000)
                        shift_down = bool(user32.GetAsyncKeyState(VK_SHIFT) & 0x8000)

                        blocked_reason: Optional[str] = None

                        # 1. Sol veya Sağ Windows Tuşu
                        if vk in (VK_LWIN, VK_RWIN):
                            blocked_reason = "Windows Tuşu (VK_WIN)"
                        # 2. Alt + Tab
                        elif alt_down and vk == VK_TAB:
                            blocked_reason = "Alt+Tab Pencere Değiştirme"
                        # 3. Alt + F4
                        elif alt_down and vk == VK_F4:
                            blocked_reason = "Alt+F4 Pencere Kapatma"
                        # 4. Alt + Esc
                        elif alt_down and vk == VK_ESCAPE:
                            blocked_reason = "Alt+Esc Kısayolu"
                        # 5. Ctrl + Esc (Başlat Menüsü)
                        elif ctrl_down and vk == VK_ESCAPE and not shift_down:
                            blocked_reason = "Ctrl+Esc Başlat Menüsü"
                        # 6. Ctrl + Shift + Esc (Görev Yöneticisi)
                        elif ctrl_down and shift_down and vk == VK_ESCAPE:
                            blocked_reason = "Ctrl+Shift+Esc Görev Yöneticisi"

                        if blocked_reason:
                            if self.on_blocked_shortcut:
                                try:
                                    self.on_blocked_shortcut(blocked_reason)
                                except Exception:
                                    pass
                            return 1  # Tuşu yut (OS'e iletme!)

                return user32.CallNextHookEx(self._hook_id, nCode, wParam, lParam)

            self._hook_proc_ref = HOOKPROC(low_level_keyboard_proc)
            h_mod = kernel32.GetModuleHandleW(None)
            self._hook_id = user32.SetWindowsHookExW(
                WH_KEYBOARD_LL,
                self._hook_proc_ref,
                h_mod,
                0,
            )

            msg = wintypes.MSG()
            while self._running and user32.GetMessageW(ctypes.byref(msg), 0, 0, 0) != 0:
                user32.TranslateMessage(ctypes.byref(msg))
                user32.DispatchMessageW(ctypes.byref(msg))
        except Exception as err:
            print(f"[SystemHooks] Klavye kancası hatası: {err}")
        finally:
            if self._hook_id:
                try:
                    ctypes.windll.user32.UnhookWindowsHookEx(self._hook_id)
                except Exception:
                    pass


# ==============================================================================
# 4. GÖREV YÖNETİCİSİ (Taskmgr.exe) ENGELLEME VE ÖN PLANA ZORLAMA
# ==============================================================================
def terminate_task_manager_if_running() -> bool:
    """
    Kilit modundayken Görev Yöneticisi (Taskmgr.exe) açılırsa
    milisaniyeler içinde sonlandırır ve True döndürür.
    """
    if not psutil:
        return False
    killed = False
    try:
        for proc in psutil.process_iter(["name"]):
            name = (proc.info.get("name") or "").lower()
            if name in ("taskmgr.exe", "procexp.exe", "procexp64.exe"):
                try:
                    proc.kill()
                    killed = True
                except Exception:
                    pass
    except Exception:
        pass
    return killed


def force_window_to_foreground(hwnd: int) -> None:
    """Verilen pencere tanıtıcısını (HWND) zorla en üste ve aktif odağa taşır."""
    if not IS_WINDOWS or not win32gui or not win32con or not hwnd:
        return
    try:
        if win32gui.IsIconic(hwnd):
            win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
        win32gui.SetWindowPos(
            hwnd,
            win32con.HWND_TOPMOST,
            0,
            0,
            0,
            0,
            win32con.SWP_NOMOVE | win32con.SWP_NOSIZE | win32con.SWP_SHOWWINDOW,
        )
        fg_hwnd = win32gui.GetForegroundWindow()
        if fg_hwnd != hwnd:
            win32gui.SetForegroundWindow(hwnd)
    except Exception:
        pass


def set_window_topmost_no_activate(
    hwnd: int,
    x: int,
    y: int,
    width: int,
    height: int,
) -> None:
    """
    Faz 3 Modül 1 (Oyun Üstü Top-Most Overlay):
    Pencereyi (`hwnd`) verilen koordinat ve boyuta (`600x350` merkez veya `350x120`
    sağ üst) taşır ve `HWND_TOPMOST` + `SWP_NOACTIVATE | SWP_SHOWWINDOW` bayraklarıyla
    odak çalmadan (tam ekran oyunu alta atmadan) en üstte gösterir.
    """
    if not IS_WINDOWS or not win32gui or not win32con or not hwnd:
        return
    try:
        flags = win32con.SWP_NOACTIVATE | win32con.SWP_SHOWWINDOW
        win32gui.SetWindowPos(
            hwnd,
            win32con.HWND_TOPMOST,
            int(x),
            int(y),
            int(width),
            int(height),
            flags,
        )
    except Exception as err:
        print(f"[SystemHooks] set_window_topmost_no_activate hatası: {err}")


# ==============================================================================
# 5. DONANIM SES KONTROLÜ (PYCAW - MUTE AÇMA VE %80 SES SEVİYESİ)
# ==============================================================================
def enforce_master_volume(target_scalar: float = 0.80) -> bool:
    """
    WAKE_UP_ALARM veya BREAK_TIME moduna geçildiğinde Windows Master Volume'ü
    Mute'dan çıkarır ve ses seviyesini en az %80'e (0.80) yükseltir.
    """
    if not IS_WINDOWS or not AudioUtilities or not IAudioEndpointVolume:
        return False
    try:
        if comtypes:
            try:
                comtypes.CoInitialize()
            except Exception:
                pass
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        volume = cast(interface, POINTER(IAudioEndpointVolume))

        # 1. Mute durumunu kaldır
        if volume.GetMute():
            volume.SetMute(0, None)

        # 2. Ses seviyesini hedef seviyeye (%80) çıkar
        current_level = float(volume.GetMasterVolumeLevelScalar())
        if current_level < target_scalar:
            volume.SetMasterVolumeLevelScalar(float(target_scalar), None)
        return True
    except Exception as err:
        print(f"[SystemHooks] pycaw ses kontrol hatası: {err}")
        return False


# ==============================================================================
# 5B. UYKU MODU ENGELLEME VE SABAH MONİTÖR UYANDIRMA (SetThreadExecutionState)
# ==============================================================================
def prevent_deep_sleep_allow_monitor_off() -> bool:
    """
    Derin Uyku Engeli:
    Ajan çalışmaya başladığı andan itibaren SetThreadExecutionState(0x80000001)
    (ES_CONTINUOUS | ES_SYSTEM_REQUIRED) çağrısı yaparak Windows'un gece boyunca
    derin uykuya (Sleep/Hibernate) geçip ağ bağlantısını koparmasını engeller.
    ES_DISPLAY_REQUIRED bayrağını KULLANMAZ; böylece gece monitörün ışığı doğal
    olarak kapanır ve çocuğun uykusunu bölmez.
    """
    if not IS_WINDOWS:
        return False
    try:
        flags = ES_CONTINUOUS | ES_SYSTEM_REQUIRED  # 0x80000001
        res = ctypes.windll.kernel32.SetThreadExecutionState(flags)
        return bool(res)
    except Exception as err:
        print(f"[SystemHooks] SetThreadExecutionState (derin uyku engeli) hatası: {err}")
        return False


def wake_up_monitor_for_alarm(
    tracker: Optional[InputActivityTracker] = None,
) -> bool:
    """
    Sabah Monitör Uyandırma (WAKE_UP_ALARM):
    1) SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)
       (0x80000003) çağrısı yapar.
    2) win32gui.SendMessage(HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, -1)
       ile kapalı monitöre güç açma sinyali gönderir.
    3) win32api.mouse_event ile 1 piksellik sanal fare hareketi göndererek
       monitörü anında uyandırır (ve bu sanal hareketi ihlal sensöründen hariç tutar).
    """
    if not IS_WINDOWS:
        return False
    try:
        if tracker is not None:
            tracker.mark_synthetic_input(grace_seconds=2.5)

        # 1. Sistem ve Ekran uyanık kalma bayrağını aktif et (0x80000003)
        flags = ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
        ctypes.windll.kernel32.SetThreadExecutionState(flags)

        # 2. Monitör gücünü aç (SC_MONITORPOWER = -1)
        try:
            if win32gui:
                win32gui.SendMessage(
                    HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, -1
                )
            else:
                ctypes.windll.user32.SendMessageW(
                    HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, -1
                )
        except Exception as mon_err:
            print(f"[SystemHooks] SC_MONITORPOWER uyarı: {mon_err}")

        # 3. 1 piksellik sanal fare hareketi gönder
        try:
            if win32api:
                win32api.mouse_event(MOUSEEVENTF_MOVE, 1, 0, 0, 0)
                win32api.mouse_event(MOUSEEVENTF_MOVE, -1, 0, 0, 0)
            else:
                ctypes.windll.user32.mouse_event(MOUSEEVENTF_MOVE, 1, 0, 0, 0)
                ctypes.windll.user32.mouse_event(MOUSEEVENTF_MOVE, -1, 0, 0, 0)
        except Exception as mouse_err:
            print(f"[SystemHooks] Sanal fare uyandırma uyarı: {mouse_err}")

        if tracker is not None:
            tracker.mark_synthetic_input(grace_seconds=2.5)

        return True
    except Exception as err:
        print(f"[SystemHooks] Sabah monitör uyandırma hatası: {err}")
        return False


# ==============================================================================
# 6. AKTİF PENCERE BAŞLIĞI OKUMA (win32gui)
# ==============================================================================
def get_active_window_title() -> str:
    """O an açık olan pencerenin başlığını ve süreç adını döndürür."""
    if not IS_WINDOWS or not win32gui:
        return "Windows Masaüstü (Aktif)"
    try:
        hwnd = win32gui.GetForegroundWindow()
        if not hwnd:
            return "Masaüstü - Boşta"
        title = win32gui.GetWindowText(hwnd).strip()
        proc_name = ""
        if win32process and psutil:
            _, pid = win32process.GetWindowThreadProcessId(hwnd)
            if pid > 0:
                proc_name = psutil.Process(pid).name()
        if title and proc_name:
            return f"{title} [{proc_name}]"
        return title or proc_name or "Masaüstü - Boşta"
    except Exception:
        return "Masaüstü - Boşta"


# ==============================================================================
# 7. ANLIK EKRAN GÖRÜNTÜSÜ ALMA (mss)
# ==============================================================================
def capture_screen_to_png_bytes() -> Optional[bytes]:
    """
    mss kütüphanesi ile tüm masaüstünün anlık ekran görüntüsünü alır ve
    PNG formatında byte dizisi olarak döndürür.
    """
    if not mss:
        return None
    try:
        with mss.mss() as sct:
            # monitor 0 = tüm monitörlerin birleşik görüntüsü
            monitor = sct.monitors[0]
            sct_img = sct.grab(monitor)
            png_bytes = mss.tools.to_png(sct_img.rgb, sct_img.size)
            return png_bytes
    except Exception as err:
        print(f"[SystemHooks] mss ekran görüntüsü hatası: {err}")
        return None


# ==============================================================================
# 8. WINDOWS BAŞLANGIÇ (REGISTRY & TASK SCHEDULER) KAYDI
# ==============================================================================
def register_windows_startup(app_name: str = "FamilyToStudyEndpointAgent") -> bool:
    """
    Ajanı HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run anahtarına
    otomatik kaydeder; böylece bilgisayar her açıldığında ajan devreye girer.
    """
    if not IS_WINDOWS or not winreg:
        return False
    try:
        main_script = os.path.abspath(os.path.join(os.path.dirname(__file__), "main.py"))
        if getattr(sys, "frozen", False):
            cmd = f'"{sys.executable}"'
        else:
            pythonw_exe = sys.executable.replace("python.exe", "pythonw.exe")
            if not os.path.exists(pythonw_exe):
                pythonw_exe = sys.executable
            cmd = f'"{pythonw_exe}" "{main_script}"'

        key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            key_path,
            0,
            winreg.KEY_SET_VALUE,
        ) as reg_key:
            winreg.SetValueEx(reg_key, app_name, 0, winreg.REG_SZ, cmd)
        return True
    except Exception as err:
        print(f"[SystemHooks] Startup kayıt hatası: {err}")
        return False


# ==============================================================================
# 9. BEYAZ LİSTE DENETLEYİCİSİ (`COMPUTER_STUDY` MODU - WhitelistEnforcer)
# ==============================================================================
class WhitelistEnforcer:
    """
    `COMPUTER_STUDY` (Bilgisayarlı Ders) modundayken her 1.5 saniyede bir aktif
    pencerenin (`GetForegroundWindow`) süreç adını (`process.name().lower()`) ve
    pencere başlığını (`GetWindowText().lower()`) kontrol eder.

    Öğrencinin `users.whitelist_config` (`allowed_exes` ve `allowed_keywords`)
    listesinde OLMAYAN bir uygulama veya sekme açtığını tespit ederse
    (kendi PyQt6 penceremiz ve Windows sistem süreçleri `explorer.exe` hariç):
      1. İlgili pencereyi `win32gui.ShowWindow(hwnd, win32con.SW_MINIMIZE)` ile
         anında aşağı indirir (simge durumuna küçültür).
      2. Arayüzün 4 saniyelik uyarı baloncuğu göstermesi ve 30 sn cooldown ile
         `unauthorized_app_opened` ihlali kaydetmesi için ihlal bilgisini döndürür.
    """

    SYSTEM_EXEMPT_EXES = {
        "explorer.exe",
        "python.exe",
        "pythonw.exe",
        "familytostudyagent.exe",
        "dwm.exe",
        "searchhost.exe",
        "searchui.exe",
        "shellexperiencehost.exe",
        "startmenuexperiencehost.exe",
        "textinputhost.exe",
        "applicationframehost.exe",
        "ctfmon.exe",
        "sihost.exe",
        "taskhostw.exe",
        "LockApp.exe".lower(),
    }

    BROWSER_EXES = {
        "chrome.exe",
        "msedge.exe",
        "firefox.exe",
        "brave.exe",
        "opera.exe",
        "vivaldi.exe",
    }

    SAFE_INTERNAL_TITLE_KEYWORDS = (
        "familytostudy",
        "family-to-study",
        "localhost:3000",
        "yeni sekme",
        "new tab",
        "about:blank",
    )

    def __init__(self, initial_config: Optional[dict] = None) -> None:
        self.allowed_exes: set[str] = {
            "chrome.exe",
            "msedge.exe",
            "winword.exe",
            "excel.exe",
            "powerpnt.exe",
            "acrord32.exe",
            "code.exe",
        }
        self.allowed_keywords: list[str] = [
            "eba",
            "ders",
            "ödev",
            "morpa",
            "tonguç",
            "matematik",
            "fen",
            "türkçe",
            "ingilizce",
            "pdf",
            "word",
        ]
        self._own_pid: int = os.getpid()
        if initial_config:
            self.update_config(initial_config)

    def update_config(self, whitelist_config: Optional[dict]) -> None:
        """Supabase `users.whitelist_config` JSONB verisiyle beyaz listeyi günceller."""
        if not isinstance(whitelist_config, dict):
            return
        try:
            raw_exes = whitelist_config.get("allowed_exes")
            if isinstance(raw_exes, list) and raw_exes:
                self.allowed_exes = {
                    str(item).strip().lower()
                    for item in raw_exes
                    if str(item).strip()
                }
            raw_keywords = whitelist_config.get("allowed_keywords")
            if isinstance(raw_keywords, list) and raw_keywords:
                self.allowed_keywords = [
                    str(kw).strip().lower()
                    for kw in raw_keywords
                    if str(kw).strip()
                ]
        except Exception as err:
            print(f"[WhitelistEnforcer] Yapılandırma güncelleme hatası: {err}")

    def inspect_and_enforce(
        self,
        own_hwnds: Optional[set[int]] = None,
    ) -> Optional[dict]:
        """
        Aktif pencereyi kontrol eder. İzin verilmeyen bir uygulama veya sekme
        açıksa anında `SW_MINIMIZE` ile küçültür ve ihlal sözlüğünü döndürür.
        İhlal yoksa `None` döndürür.
        """
        if not IS_WINDOWS or not win32gui or not win32con or not win32process or not psutil:
            return None

        try:
            hwnd = win32gui.GetForegroundWindow()
            if not hwnd:
                return None

            if own_hwnds and int(hwnd) in own_hwnds:
                return None

            # Simge durumundaki veya görünmez pencereleri atla
            if win32gui.IsIconic(hwnd) or not win32gui.IsWindowVisible(hwnd):
                return None

            _, pid = win32process.GetWindowThreadProcessId(hwnd)
            if pid <= 0 or pid == self._own_pid:
                return None

            try:
                proc = psutil.Process(pid)
                proc_name = (proc.name() or "").strip().lower()
            except Exception:
                return None

            if not proc_name or proc_name in self.SYSTEM_EXEMPT_EXES:
                return None

            window_title_raw = (win32gui.GetWindowText(hwnd) or "").strip()
            window_title = window_title_raw.lower()

            # Boş başlıklı masaüstü/kabuk bileşenlerini atla
            if not window_title and proc_name in ("explorer.exe", "shellexperiencehost.exe"):
                return None

            # Kendi PWA veya ajan penceremiz ise muaf tut
            if any(safe_kw in window_title for safe_kw in self.SAFE_INTERNAL_TITLE_KEYWORDS):
                return None

            # 1) Süreç adı (`allowed_exes`) kontrolü ve
            # 2) Pencere başlığı (`allowed_keywords`) kontrolü:
            exe_is_allowed = proc_name in self.allowed_exes
            title_matches_keyword = (
                any(kw in window_title for kw in self.allowed_keywords)
                if (self.allowed_keywords and window_title)
                else False
            )

            is_authorized = False
            if exe_is_allowed:
                # Eğer uygulama bir web tarayıcısıysa (chrome.exe, msedge.exe vb.)
                # sekme başlığında izin verilen ders kelimelerinden (`allowed_keywords`)
                # en az birinin geçmesi zorunludur (oyun/video sekmelerini engellemek için).
                if proc_name in self.BROWSER_EXES and self.allowed_keywords:
                    is_authorized = title_matches_keyword
                else:
                    is_authorized = True
            else:
                # Uygulama exe listesinde olmasa bile başlığı doğrudan ders anahtar
                # kelimesiyle eşleşiyorsa? Hayır, hem exe izinli olmalı veya başlıkta
                # açıkça izin verilen eğitim aracı olmalı: güvenlik için exe_is_allowed şart!
                is_authorized = False

            if is_authorized:
                return None

            # İZİNSİZ UYGULAMA VEYA SEKME TESPİT EDİLDİ!
            # 1. Pencereyi win32gui.ShowWindow(hwnd, win32con.SW_MINIMIZE) ile anında aşağı indir!
            try:
                win32gui.ShowWindow(hwnd, win32con.SW_MINIMIZE)
            except Exception as min_err:
                print(f"[WhitelistEnforcer] SW_MINIMIZE hatası: {min_err}")

            short_title = (
                window_title_raw[:50] + "..."
                if len(window_title_raw) > 50
                else (window_title_raw or proc_name)
            )
            display_app = f"{proc_name} ({short_title})"

            return {
                "hwnd": int(hwnd),
                "pid": int(pid),
                "proc_name": proc_name,
                "window_title": window_title_raw,
                "display_app": display_app,
            }
        except Exception as err:
            print(f"[WhitelistEnforcer] Denetim hatası: {err}")
            return None


# ==============================================================================
# 10. FAZ 3: DONANIMSAL GÜRÜLTÜ / BAĞIRMA SENSÖRÜ (`NoiseMonitorThread`)
# ==============================================================================
class NoiseMonitorThread(threading.Thread):
    """
    Tarayıcı mikrofon iznine bağlı kalmamak için Windows tarafında doğrudan ses
    giriş seviyesini (`sounddevice` + `numpy`) dinleyen hafif arka plan iş parçacığı.

    GİZLİLİK KURALI:
    - Kesinlikle ses kaydı yapmaz, bellekte ses geçmişi tutmaz veya diske yazmaz.
    - Sadece anlık RMS / Desibel (dB) genlik seviyesini hesaplar ve tamponu anında siler.

    DAVRANIŞ:
    - Odadaki ses seviyesi 8 saniye boyunca kesintisiz olarak `threshold_db`
      (`family_settings.noise_threshold_db`, varsayılan 75 dB) eşiğini aşarsa
      `on_high_noise_callback(measured_db)` fonksiyonunu tetikler.
    - Mikrofon bulunmayan masaüstü PC'lerde veya ses sürücüsü hatasında `try-except`
      ile yakalanır ve hata vermeden sessizce devre dışı kalır.
    """

    def __init__(
        self,
        threshold_db: int = 75,
        sustained_seconds: float = 8.0,
        on_high_noise_callback: Optional[Callable[[int], None]] = None,
    ) -> None:
        super().__init__(name="HardwareNoiseMonitorThread", daemon=True)
        self.threshold_db: int = int(threshold_db)
        self.sustained_seconds: float = float(sustained_seconds)
        self.on_high_noise_callback = on_high_noise_callback

        self.current_db: int = 35
        self.monitoring_enabled: bool = True
        self.is_available: bool = False
        self._running: bool = False
        self._above_threshold_since: Optional[float] = None
        self._last_trigger_epoch: float = 0.0

    def set_threshold_db(self, new_threshold_db: int) -> None:
        if 40 <= int(new_threshold_db) <= 120:
            self.threshold_db = int(new_threshold_db)

    def set_monitoring_enabled(self, enabled: bool) -> None:
        self.monitoring_enabled = bool(enabled)
        if not self.monitoring_enabled:
            self._above_threshold_since = None

    def stop(self) -> None:
        self._running = False

    @staticmethod
    def _compute_db_from_float_samples(samples) -> int:
        """
        [-1.0, 1.0] aralığındaki anlık ses örneklerinden sadece RMS tabanlı
        yaklaşık SPL desibel (dB) değerini hesaplar (30 dB .. 105 dB).
        """
        if np is None or samples is None or len(samples) == 0:
            return 35
        try:
            rms = float(np.sqrt(np.mean(np.square(samples, dtype=np.float64))))
            if rms <= 1e-7:
                return 30
            # Referans kalibrasyonu: normal konuşma ~55-65 dB, bağırma >= 75-85 dB
            db = int(round(20.0 * float(np.log10(rms)) + 94.0))
            return max(30, min(108, db))
        except Exception:
            return 35

    def _evaluate_measured_db(self, measured_db: int) -> None:
        self.current_db = measured_db
        if not self.monitoring_enabled:
            self._above_threshold_since = None
            return

        now = time.time()
        if measured_db >= self.threshold_db:
            if self._above_threshold_since is None:
                self._above_threshold_since = now
            else:
                sustained = now - self._above_threshold_since
                if sustained >= self.sustained_seconds:
                    # 8 saniye kesintisiz eşik aşıldı!
                    self._above_threshold_since = now
                    if (
                        self.on_high_noise_callback is not None
                        and (now - self._last_trigger_epoch) >= 5.0
                    ):
                        self._last_trigger_epoch = now
                        try:
                            self.on_high_noise_callback(measured_db)
                        except Exception as cb_err:
                            print(f"[NoiseMonitor] Callback hatası: {cb_err}")
        else:
            self._above_threshold_since = None

    def run(self) -> None:
        self._running = True

        # Mikrofon veya sounddevice/numpy yoksa sessizce devre dışı kal
        if sd is None or np is None:
            self.is_available = False
            return

        try:
            # Varsayılan giriş cihazı (mikrofon) var mı kontrol et
            default_in = sd.query_devices(kind="input")
            if not default_in or int(default_in.get("max_input_channels", 0)) < 1:
                self.is_available = False
                return
        except Exception:
            # Masaüstü PC'de mikrofon takılı değilse sessizce devre dışı kal
            self.is_available = False
            return

        sample_rate = 16000
        block_duration_sec = 0.25  # 250ms dilimlerle anlık genlik ölçümü
        block_size = int(sample_rate * block_duration_sec)

        def _audio_callback(indata, frames, time_info, status) -> None:
            # GİZLİLİK: `indata` kaydedilmez veya kopyalanmaz, sadece RMS hesaplanır
            try:
                if not self._running or not self.monitoring_enabled:
                    return
                db_val = self._compute_db_from_float_samples(indata[:, 0])
                self._evaluate_measured_db(db_val)
            except Exception:
                pass

        try:
            with sd.InputStream(
                samplerate=sample_rate,
                channels=1,
                dtype="float32",
                blocksize=block_size,
                callback=_audio_callback,
            ):
                self.is_available = True
                while self._running:
                    time.sleep(0.5)
        except Exception:
            # Mikrofon erişimi reddedildiyse veya cihaz çıkarıldıysa sessizce kapan
            self.is_available = False
            self._running = False


# ==============================================================================
# 11. FAZ 4: WINDOWS YEREL TÜRKÇE SESLİ ANONS MOTORU VE "AUDIO DUCKING" (`TTSAnnouncer`)
# ==============================================================================
class TTSAnnouncer(threading.Thread):
    """
    Faz 4 Modül 2:
    `pyttsx3` veya Windows SAPI (`win32com.client.Dispatch("SAPI.SpVoice")`)
    kullanan, arka plan kuyruklu (`queue.Queue`) asenkron Türkçe Sesli Anons Motoru.

    AUDIO DUCKING (OYUN SESİNİ GEÇİCİ KISMA):
    - Anons başlamadan hemen önce `pycaw` (`AudioUtilities.GetAllSessions()`) ile
      o an bilgisayarda ses çalan diğer tüm uygulamaların (oyunlar, videolar,
      tarayıcılar) sesini geçici olarak %20'ye (`0.20`) düşürür.
    - Türkçe sesli anonsu net bir şekilde okur.
    - Anons biter bitmez diğer uygulamaların sesini orijinal seviyesine geri yükseltir.
    """

    def __init__(
        self,
        duck_scalar: float = 0.20,
        enabled: bool = True,
    ) -> None:
        super().__init__(name="WindowsTTSAnnouncerThread", daemon=True)
        self.duck_scalar: float = max(0.05, min(0.50, float(duck_scalar)))
        self.enabled: bool = bool(enabled)
        self._queue: "queue.Queue[Optional[str]]" = queue.Queue()
        self._running: bool = False
        self._own_pid: int = os.getpid()
        self._recent_messages: dict[str, float] = {}

    def set_enabled(self, enabled: bool) -> None:
        self.enabled = bool(enabled)

    def stop(self) -> None:
        self._running = False
        try:
            self._queue.put_nowait(None)
        except Exception:
            pass

    def announce(self, text: str, dedupe_window_sec: float = 6.0) -> None:
        """
        Metni arka plan sesli anons kuyruğuna ekler.
        Aynı anonsun kısa sürede üst üste tekrarlanmasını önler.
        """
        if not self.enabled:
            return
        cleaned = (text or "").strip()
        if not cleaned:
            return

        now = time.time()
        last_spoken = self._recent_messages.get(cleaned, 0.0)
        if now - last_spoken < dedupe_window_sec:
            return
        self._recent_messages[cleaned] = now

        try:
            self._queue.put_nowait(cleaned)
        except Exception as err:
            print(f"[TTSAnnouncer] Kuyruğa ekleme hatası: {err}")

    def _duck_other_audio_sessions(self) -> list[tuple[object, float]]:
        """
        `pycaw` (`AudioUtilities.GetAllSessions()`) kullanarak kendi ajan sürecimiz
        dışındaki tüm aktif ses oturumlarının mevcut ses seviyesini kaydeder ve
        %20'ye (`self.duck_scalar`) kısar.
        """
        saved_sessions: list[tuple[object, float]] = []
        if not IS_WINDOWS or not AudioUtilities:
            return saved_sessions

        try:
            sessions = AudioUtilities.GetAllSessions()
            for session in sessions:
                try:
                    proc = getattr(session, "Process", None)
                    if proc is not None and int(proc.pid) == self._own_pid:
                        continue
                    volume_iface = getattr(session, "SimpleAudioVolume", None)
                    if volume_iface is None and ISimpleAudioVolume is not None and hasattr(session, "_ctl"):
                        volume_iface = session._ctl.QueryInterface(ISimpleAudioVolume)
                    if volume_iface is None:
                        continue

                    orig_vol = float(volume_iface.GetMasterVolume())
                    if orig_vol > self.duck_scalar:
                        saved_sessions.append((volume_iface, orig_vol))
                        volume_iface.SetMasterVolume(float(self.duck_scalar), None)
                except Exception:
                    continue
        except Exception as err:
            print(f"[TTSAnnouncer] Audio Ducking kısma uyarısı: {err}")

        return saved_sessions

    @staticmethod
    def _restore_ducked_audio_sessions(saved_sessions: list[tuple[object, float]]) -> None:
        """Anons biter bitmez kısılan uygulama seslerini eski seviyesine geri yükler."""
        for volume_iface, orig_vol in saved_sessions:
            try:
                volume_iface.SetMasterVolume(float(max(0.0, min(1.0, orig_vol))), None)
            except Exception:
                continue

    @staticmethod
    def _select_turkish_voice_pyttsx3(engine) -> None:
        """pyttsx3 motorunda Türkçe ses (Tolga / tr-TR) varsa seçer."""
        try:
            voices = engine.getProperty("voices") or []
            for v in voices:
                v_id = str(getattr(v, "id", "") or "").lower()
                v_name = str(getattr(v, "name", "") or "").lower()
                v_langs = str(getattr(v, "languages", "") or "").lower()
                if (
                    "tr_tr" in v_id
                    or "tr-tr" in v_id
                    or "turkish" in v_name
                    or "türkçe" in v_name
                    or "tolga" in v_name
                    or "tr" in v_langs
                ):
                    engine.setProperty("voice", v.id)
                    break
            engine.setProperty("rate", 172)
            engine.setProperty("volume", 1.0)
        except Exception:
            pass

    def _speak_blocking(self, text: str) -> None:
        """
        Sırasıyla:
        1) Windows SAPI (`win32com.client.Dispatch("SAPI.SpVoice")`)
        2) `pyttsx3`
        3) PowerShell `System.Speech.Synthesis.SpeechSynthesizer`
        üzerinden Türkçe sesli anonsu gerçekleştirir.
        """
        # 1) Windows SAPI COM arayüzü (Thread içinde en kararlı Windows yerel motoru)
        if IS_WINDOWS and win32com_client is not None:
            try:
                speaker = win32com_client.Dispatch("SAPI.SpVoice")
                try:
                    voices = speaker.GetVoices()
                    for i in range(voices.Count):
                        v = voices.Item(i)
                        desc = str(v.GetDescription() or "").lower()
                        if "turkish" in desc or "türkçe" in desc or "tolga" in desc or "tr-tr" in desc:
                            speaker.Voice = v
                            break
                except Exception:
                    pass
                speaker.Volume = 100
                speaker.Rate = 0
                speaker.Speak(text)
                return
            except Exception as sapi_err:
                print(f"[TTSAnnouncer] SAPI.SpVoice yedek motora geçiliyor: {sapi_err}")

        # 2) pyttsx3 motoru
        if pyttsx3 is not None:
            try:
                engine = pyttsx3.init()
                self._select_turkish_voice_pyttsx3(engine)
                engine.say(text)
                engine.runAndWait()
                try:
                    engine.stop()
                except Exception:
                    pass
                return
            except Exception as p_err:
                print(f"[TTSAnnouncer] pyttsx3 yedek motora geçiliyor: {p_err}")

        # 3) Windows PowerShell System.Speech yedek motoru
        if IS_WINDOWS:
            try:
                safe_text = text.replace("'", " ").replace('"', " ")
                ps_cmd = (
                    "Add-Type -AssemblyName System.Speech; "
                    "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
                    "$s.Volume = 100; "
                    f"$s.Speak('{safe_text}');"
                )
                subprocess.run(
                    ["powershell", "-NoProfile", "-WindowStyle", "Hidden", "-Command", ps_cmd],
                    timeout=12,
                    check=False,
                )
            except Exception as ps_err:
                print(f"[TTSAnnouncer] PowerShell TTS hatası: {ps_err}")

    def run(self) -> None:
        self._running = True
        if IS_WINDOWS and comtypes is not None:
            try:
                comtypes.CoInitialize()
            except Exception:
                pass

        while self._running:
            try:
                text = self._queue.get(timeout=0.5)
            except queue.Empty:
                continue

            if text is None or not self._running:
                break

            if not self.enabled:
                self._queue.task_done()
                continue

            saved_sessions: list[tuple[object, float]] = []
            start_ts = time.time()
            try:
                # 1) Audio Ducking: Diğer tüm uygulamaların sesini %20'ye kıs
                saved_sessions = self._duck_other_audio_sessions()
                # 2) Türkçe sesli anonsu oku
                self._speak_blocking(text)
                # Oyun sesinin en az ~3 saniye kısılmış kalmasını sağla (kısa anonslarda bile net duyulsun)
                elapsed = time.time() - start_ts
                if saved_sessions and elapsed < 2.8:
                    time.sleep(max(0.0, 2.8 - elapsed))
            except Exception as err:
                print(f"[TTSAnnouncer] Anons çalışma hatası: {err}")
            finally:
                # 3) Anons biter bitmez diğer uygulamaların sesini eski seviyesine geri yükselt
                self._restore_ducked_audio_sessions(saved_sessions)
                try:
                    self._queue.task_done()
                except Exception:
                    pass

        if IS_WINDOWS and comtypes is not None:
            try:
                comtypes.CoUninitialize()
            except Exception:
                pass


# ==============================================================================
# 12. FAZ 6: YARININ DERS PROGRAMI VE SESLİ ÇANTA HAZIRLAMA ANONSU
# ==============================================================================
def announce_tomorrow_bag_schedule(
    supabase_client: Optional[object],
    user_id: str,
    student_name: str,
    tts_announcer: Optional[TTSAnnouncer],
) -> Optional[str]:
    """
    Akşam çanta hazırlama rutini veya ebeveyn hatırlatması tetiklendiğinde:
    Öğrencinin `school_schedules` tablosundaki yarınki derslerini (`lessons`) ve
    ekstra malzemelerini (`extra_materials`) Supabase üzerinden çeker.
    Audio Ducking ile diğer tüm oyun/video seslerini kısarak Türkçe sesli anons yapar:
    'Dikkat [Öğrenci Adı]! Çanta hazırlama vakti. Yarınki derslerin: [Dersler]. Lütfen kitaplarını, defterlerini ve [Malzemeler] eşyalarını çantana yerleştir.'
    """
    now = datetime.now()
    # ISO weekday: 1 = Pazartesi ... 7 = Pazar
    today_iso = now.isoweekday()
    tomorrow_iso = (today_iso % 7) + 1

    lessons_list: list[str] = []
    materials_list: list[str] = []

    if supabase_client:
        try:
            res = (
                supabase_client.table("school_schedules")
                .select("*")
                .eq("user_id", user_id)
                .eq("day_of_week", tomorrow_iso)
                .limit(1)
                .execute()
            )
            if res.data and len(res.data) > 0:
                row = res.data[0]
                raw_lessons = row.get("lessons") or []
                if isinstance(raw_lessons, list):
                    sorted_lessons = sorted(
                        raw_lessons,
                        key=lambda x: x.get("period", 0) if isinstance(x, dict) else 0,
                    )
                    for item in sorted_lessons:
                        if isinstance(item, dict) and item.get("name"):
                            l_name = str(item["name"]).strip()
                            if l_name and l_name not in lessons_list:
                                lessons_list.append(l_name)

                raw_mats = row.get("extra_materials") or row.get("custom_items_to_pack") or []
                if isinstance(raw_mats, list):
                    for m in raw_mats:
                        m_str = str(m).strip()
                        if m_str and m_str not in materials_list:
                            materials_list.append(m_str)

                if row.get("has_pe_class") and "Eşofman Takımı" not in materials_list:
                    materials_list.insert(0, "Eşofman Takımı")
                if row.get("has_art_class") and "Resim Çantası" not in materials_list:
                    materials_list.append("Resim Çantası")
        except Exception as err:
            print(f"[BagSchedule] Supabase sorgu hatası: {err}")

    # Eğer veritabanında henüz girilmemişse zengin varsayılan dersler
    lessons_text = ", ".join(lessons_list) if lessons_list else "Matematik, Türkçe ve Fen Bilimleri"
    materials_text = ", ".join(materials_list) if materials_list else "Suluğunu ve Resim Çantanı"

    speech_text = (
        f"Dikkat {student_name}! Çanta hazırlama vakti. "
        f"Yarınki derslerin: {lessons_text}. "
        f"Lütfen kitaplarını, defterlerini ve {materials_text} eşyalarını çantana yerleştir."
    )

    if tts_announcer:
        tts_announcer.announce(speech_text, dedupe_window_sec=10.0)

    return speech_text

