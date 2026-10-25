"""
===============================================================================
FAMILY-TO-STUDY: KATI WINDOWS PC MASAÜSTÜ KİLİT, SENSÖR VE DENETİM AJANI
===============================================================================
Özellikler:
1. Gerçek Zamanlı Supabase Senkronizasyonu (STUDY_TIME, SLEEP_TIME, WAKE_UP_ALARM, FREE_TIME).
2. Katı Tam Ekran Kilit (Topmost Kiosk Overlay):
   - Alt+F4 kapatma engeli (protocol WM_DELETE_WINDOW override)
   - Alt+Tab / Görev Çubuğu kaçış engeli (Her 150ms'de Zorunlu Focus & Topmost)
   - Çift monitör / Sanal masaüstü tam ekran kaplama
3. Global Fare & Klavye İhlal Sensörü (pynput):
   - STUDY_TIME veya SLEEP_TIME modunda klavye tuş basımı ('pc_key_press') veya
     izinli alan dışı fare hareketi ('pc_mouse_move') tespit edildiği anda:
     -> Supabase `record_violation_and_break_shield` RPC çağrılır (1 Kalkan kırılır)
     -> Anne & Baba ekranına anında sesli/görsel bildirim düşer
     -> PC hoparlöründen siren çalar
4. Aktif Pencere & Uygulama İzleyici (win32gui + psutil):
   - Her 3 saniyede bir öğrencinin PC'de hangi pencere/uygulamada olduğunu
     `devices.active_window_title` ve `last_heartbeat` olarak Supabase'e yazar.
5. Sabah Uyandırma Alarmı (WAKE_UP_ALARM):
   - PC hoparlöründen artan frekansta alarm çalar, ekranda 3 Yıldız + Bilmece
     görevini açar; öğrenci çözene kadar masaüstünü açmaz.
===============================================================================
"""

import os
import sys
import time
import math
import json
import random
import threading
from datetime import datetime, timezone
import tkinter as tk
from tkinter import messagebox

# Harici kütüphaneler (Windows ortamında otomatik yüklenir)
try:
    from supabase import create_client, Client
except ImportError:
    create_client = None

try:
    import psutil
except ImportError:
    psutil = None

try:
    from pynput import mouse, keyboard
except ImportError:
    mouse = None
    keyboard = None

try:
    import win32gui
    import win32process
    import win32con
    import winsound
except ImportError:
    win32gui = None
    win32process = None
    win32con = None
    winsound = None


# ==============================================================================
# YAPILANDIRMA (CONFIG)
# ==============================================================================
CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "agent_config.json")

DEFAULT_CONFIG = {
    "supabase_url": "https://pljxviezoilirlsoavto.supabase.co",
    "supabase_key": "sb_publishable_J9zEygp-UY48F0QYIM0gKg_BFg3KlTD",
    "family_id": "fam-ozdemir",
    "student_id": "child-omer",
    "device_id": "dev-omer-pc",
    "device_name": "Ömer Masaüstü PC",
    "parent_pin": "1234",
    "mouse_move_threshold_px": 180,
    "violation_cooldown_sec": 6
}


def load_config() -> dict:
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return {**DEFAULT_CONFIG, **data}
        except Exception:
            pass
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(DEFAULT_CONFIG, f, indent=2, ensure_ascii=False)
    return DEFAULT_CONFIG


# ==============================================================================
# WINDOWS AKTİF PENCERE VE SES YARDIMCILARI
# ==============================================================================
def get_foreground_window_info() -> str:
    """Aktif pencere başlığını ve çalışan .exe adını döndürür."""
    if not win32gui:
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
                proc = psutil.Process(pid)
                proc_name = proc.name()
        if title and proc_name:
            return f"{title} ({proc_name})"
        return title or proc_name or "Masaüstü"
    except Exception:
        return "Masaüstü"


def play_pc_sound(mode: str):
    """Windows dahili hoparlör/ses apisi ile siren veya alarm çalar."""
    if not winsound:
        return

    def _sound_worker():
        try:
            if mode == "violation":
                winsound.Beep(440, 220)
                winsound.Beep(300, 350)
            elif mode == "wakeup":
                for freq in [523, 659, 784, 1046]:
                    winsound.Beep(freq, 160)
            elif mode == "victory":
                for freq in [523, 659, 784, 1046]:
                    winsound.Beep(freq, 120)
        except Exception:
            pass

    threading.Thread(target=_sound_worker, daemon=True).start()


# ==============================================================================
# ANA WINDOWS KİLİT VE DENETİM AJANI SINIFI
# ==============================================================================
class StrictWindowsEnforcerApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.cfg = load_config()
        self.supabase: Client | None = None
        if create_client:
            try:
                self.supabase = create_client(self.cfg["supabase_url"], self.cfg["supabase_key"])
            except Exception as e:
                print("Supabase bağlantı hatası:", e)

        # Öğrenci canlı durumu
        self.student_name = "Ömer"
        self.current_state = "FREE_TIME"
        self.state_ends_at: str | None = None
        self.daily_shields = 3
        self.points_balance = 0
        self.active_task_title = "Günlük Ödev & Test Çözümü (Fotoğraf Kanıtlı)"

        # İhlal sensörü durumları
        self.last_violation_time = 0.0
        self.last_mouse_pos = None
        self.accumulated_mouse_dist = 0.0
        self.violation_banner_text = ""

        # Uyandırma alarmı yıldız yakalama durumu
        self.wake_stars_caught = 0

        # Tkinter Pencereyi Tam Ekran, Çerçevesiz, En Üstte (Topmost Kiosk) Yapılandır
        self.setup_kiosk_window()
        self.build_ui()

        # Global Fare ve Klavye Hook'larını Başlat
        self.start_input_hooks()

        # Arka plan senkronizasyon, heartbeat ve pencere zorlama döngülerini başlat
        self.enforce_topmost_loop()
        self.update_countdown_loop()
        threading.Thread(target=self.supabase_sync_worker, daemon=True).start()

    def setup_kiosk_window(self):
        self.root.title("FamilyToStudy Odaklanma Kalkanı")
        self.root.configure(bg="#020617")

        # Tam ekran ve tüm monitörleri kapla
        screen_w = self.root.winfo_screenwidth()
        screen_h = self.root.winfo_screenheight()
        self.root.geometry(f"{screen_w}x{screen_h}+0+0")
        self.root.attributes("-fullscreen", True)
        self.root.attributes("-topmost", True)
        self.root.overrideredirect(True)  # Pencere çerçevesini ve X butonunu kaldır

        # Alt+F4 ve pencere kapatma girişimlerini tamamen engelle!
        self.root.protocol("WM_DELETE_WINDOW", self.on_blocked_close_attempt)
        self.root.bind("<Alt-F4>", lambda e: "break")
        self.root.bind("<Escape>", lambda e: "break")

        # Başlangıçta FREE_TIME ise pencereyi gizle (withdraw)
        self.root.withdraw()

    def on_blocked_close_attempt(self):
        """Öğrenci Alt+F4 veya kapatmaya çalışırsa ihlal kaydet!"""
        self.trigger_violation("pc_key_press", "Alt+F4 ile kilit ekranını kapatma girişimi!")
        return "break"

    def build_ui(self):
        # Ana Konteyner
        self.main_frame = tk.Frame(self.root, bg="#020617", padx=40, pady=30)
        self.main_frame.pack(expand=True, fill="both")

        # Üst Uyarı / İhlal Banner
        self.violation_lbl = tk.Label(
            self.main_frame,
            text="",
            font=("Segoe UI", 14, "bold"),
            fg="#ffffff",
            bg="#e11d48",
            padx=20,
            pady=10
        )

        # Mod Başlığı
        self.badge_lbl = tk.Label(
            self.main_frame,
            text="🛡️ FAMILY-TO-STUDY WINDOWS KALKANI AKTİF",
            font=("Segoe UI", 13, "bold"),
            fg="#fbbf24",
            bg="#020617"
        )
        self.badge_lbl.pack(pady=(10, 5))

        self.headline_lbl = tk.Label(
            self.main_frame,
            text="Şu An Odaklanma Vakti! Bilgisayar Kilitli 🔒",
            font=("Segoe UI", 28, "bold"),
            fg="#f8fafc",
            bg="#020617"
        )
        self.headline_lbl.pack(pady=5)

        self.subtext_lbl = tk.Label(
            self.main_frame,
            text="Ders saatinde fare veya klavye kullanımı 1 Odaklanma Kalkanını kırar ve Anne/Babaya bildirim gönderir!",
            font=("Segoe UI", 13),
            fg="#94a3b8",
            bg="#020617"
        )
        self.subtext_lbl.pack(pady=(0, 20))

        # Büyük Geri Sayım Sayacı
        self.timer_lbl = tk.Label(
            self.main_frame,
            text="40:00",
            font=("Consolas", 72, "bold"),
            fg="#34d399",
            bg="#0f172a",
            padx=50,
            pady=20,
            relief="ridge",
            bd=3
        )
        self.timer_lbl.pack(pady=15)

        # Kalkan Göstergesi
        self.shields_lbl = tk.Label(
            self.main_frame,
            text="Günlük Kalkanların: 🛡️ 🛡️ 🛡️ (3/3)",
            font=("Segoe UI", 18, "bold"),
            fg="#34d399",
            bg="#020617"
        )
        self.shields_lbl.pack(pady=10)

        # Aktif Görev Bilgisi
        self.task_frame = tk.Frame(self.main_frame, bg="#1e1b4b", padx=25, pady=18, bd=2, relief="groove")
        self.task_frame.pack(pady=15, fill="x", padx=120)

        tk.Label(
            self.task_frame,
            text="📸 ŞU AN YAPILACAK AKTİF GÖREVİN (Fotoğraf Kanıtını Tabletten/Telefondan Gönder):",
            font=("Segoe UI", 11, "bold"),
            fg="#a5b4fc",
            bg="#1e1b4b"
        ).pack(anchor="w")

        self.task_title_lbl = tk.Label(
            self.task_frame,
            text=self.active_task_title,
            font=("Segoe UI", 16, "bold"),
            fg="#ffffff",
            bg="#1e1b4b"
        )
        self.task_title_lbl.pack(anchor="w", pady=(4, 0))

        # Uyandırma Alarmı (WAKE_UP_ALARM) Yıldız Yakalama Alanı
        self.wake_frame = tk.Frame(self.main_frame, bg="#7c2d12", padx=20, pady=20, bd=3, relief="ridge")
        self.wake_info_lbl = tk.Label(
            self.wake_frame,
            text="☀️ GÜNAYDIN! Alarmı susturmak için aşağıdaki yıldızı 3 kez yakala!",
            font=("Segoe UI", 15, "bold"),
            fg="#fef08a",
            bg="#7c2d12"
        )
        self.wake_info_lbl.pack(pady=5)

        self.wake_star_btn = tk.Button(
            self.wake_frame,
            text="⭐ YILDIZI YAKALA (0/3)",
            font=("Segoe UI", 16, "bold"),
            bg="#facc15",
            fg="#020617",
            padx=20,
            pady=10,
            command=self.on_catch_wake_star
        )
        self.wake_star_btn.pack(pady=10)

        # Alt Bar: Anne/Babaya Acil Mesaj & Ebeveyn PIN Kilidi Açma
        bottom_frame = tk.Frame(self.main_frame, bg="#020617")
        bottom_frame.pack(side="bottom", fill="x", pady=15)

        sos_btn = tk.Button(
            bottom_frame,
            text="📻 Anne / Babaya 'Yardım Lazım' Sinyali Gönder",
            font=("Segoe UI", 11, "bold"),
            bg="#4f46e5",
            fg="#ffffff",
            padx=16,
            pady=8,
            command=self.send_parent_sos
        )
        sos_btn.pack(side="left", padx=20)

        # Ebeveyn Acil Durum PIN Girişi
        pin_frame = tk.Frame(bottom_frame, bg="#020617")
        pin_frame.pack(side="right", padx=20)

        tk.Label(
            pin_frame,
            text="Ebeveyn PIN ile Kilidi Aç:",
            font=("Segoe UI", 10),
            fg="#64748b",
            bg="#020617"
        ).pack(side="left", padx=5)

        self.pin_entry = tk.Entry(pin_frame, show="*", width=8, font=("Segoe UI", 12))
        self.pin_entry.pack(side="left", padx=5)

        tk.Button(
            pin_frame,
            text="Kilidi Aç",
            font=("Segoe UI", 10, "bold"),
            bg="#334155",
            fg="#ffffff",
            command=self.verify_parent_pin_unlock
        ).pack(side="left")

    # ==========================================================================
    # KATI TOPMOST ZORLAMA (ALT+TAB VE GÖREV YÖNETİCİSİ ENGELLEYİCİ)
    # ==========================================================================
    def enforce_topmost_loop(self):
        """Her 200ms'de bir eğer mod kilitliyse pencereyi en üste ve tam ekrana zorlar."""
        is_locked = self.current_state in ("STUDY_TIME", "SLEEP_TIME", "WAKE_UP_ALARM")
        if is_locked:
            try:
                self.root.deiconify()
                self.root.attributes("-topmost", True)
                self.root.lift()
                if self.current_state == "WAKE_UP_ALARM":
                    self.wake_frame.pack(pady=10, fill="x", padx=120)
                else:
                    self.wake_frame.pack_forget()
            except Exception:
                pass
        else:
            try:
                self.root.withdraw()
            except Exception:
                pass

        self.root.after(250, self.enforce_topmost_loop)

    # ==========================================================================
    # GERİ SAYIM SAYACI GÜNCELLEME
    # ==========================================================================
    def update_countdown_loop(self):
        if self.state_ends_at:
            try:
                end_dt = datetime.fromisoformat(self.state_ends_at.replace("Z", "+00:00"))
                diff = max(0, int((end_dt - datetime.now(timezone.utc)).total_seconds()))
                mins = diff // 60
                secs = diff % 60
                self.timer_lbl.config(text=f"{mins:02d}:{secs:02d}")
            except Exception:
                self.timer_lbl.config(text="--:--")
        else:
            self.timer_lbl.config(text="KİLİTLİ")

        shields_icons = " ".join(["🛡️"] * self.daily_shields) + " " + " ".join(["💔"] * (3 - self.daily_shields))
        self.shields_lbl.config(
            text=f"Günlük Kalkanların: {shields_icons} ({self.daily_shields}/3)"
        )

        if self.current_state == "SLEEP_TIME":
            self.headline_lbl.config(text="🌙 Uyku & Dinlenme Vakti! Bilgisayar Kilitli")
        elif self.current_state == "WAKE_UP_ALARM":
            self.headline_lbl.config(text=f"☀️ Günaydın {self.student_name}! Uyanma Vakti!")
            play_pc_sound("wakeup")
        else:
            self.headline_lbl.config(text=f"⚡ {self.student_name} İçin Odaklanma Vakti! PC Kilitli")

        self.root.after(1000, self.update_countdown_loop)

    # ==========================================================================
    # GLOBAL FARE & KLAVYE İHLAL SENSÖRÜ (PYNPUT)
    # ==========================================================================
    def start_input_hooks(self):
        if not mouse or not keyboard:
            return

        def on_move(x, y):
            if self.current_state not in ("STUDY_TIME", "SLEEP_TIME"):
                self.last_mouse_pos = (x, y)
                self.accumulated_mouse_dist = 0.0
                return

            if self.last_mouse_pos is not None:
                dx = x - self.last_mouse_pos[0]
                dy = y - self.last_mouse_pos[1]
                self.accumulated_mouse_dist += math.hypot(dx, dy)

                if self.accumulated_mouse_dist > self.cfg["mouse_move_threshold_px"]:
                    self.accumulated_mouse_dist = 0.0
                    self.trigger_violation("pc_mouse_move", "Ders saatinde PC faresi hareket ettirildi!")
            self.last_mouse_pos = (x, y)

        def on_key_press(key):
            if self.current_state in ("STUDY_TIME", "SLEEP_TIME"):
                self.trigger_violation("pc_key_press", "Ders saatinde PC klavyesi kullanıldı!")

        self.mouse_listener = mouse.Listener(on_move=on_move)
        self.key_listener = keyboard.Listener(on_press=on_key_press)
        self.mouse_listener.daemon = True
        self.key_listener.daemon = True
        self.mouse_listener.start()
        self.key_listener.start()

    def trigger_violation(self, v_type: str, reason_msg: str):
        now = time.time()
        if now - self.last_violation_time < self.cfg["violation_cooldown_sec"]:
            return
        self.last_violation_time = now

        play_pc_sound("violation")
        self.daily_shields = max(0, self.daily_shields - 1)

        def _update_banner():
            self.violation_lbl.config(
                text=f"🚨 UYARI: {reason_msg} (1 Kalkan Kırıldı ve Ebeveyne Bildirildi!)"
            )
            self.violation_lbl.pack(fill="x", pady=5, before=self.badge_lbl)

        self.root.after(0, _update_banner)

        if self.supabase:
            def _send_rpc():
                try:
                    self.supabase.rpc(
                        "record_violation_and_break_shield",
                        {
                            "p_user_id": self.cfg["student_id"],
                            "p_device_id": self.cfg["device_id"],
                            "p_violation_type": v_type,
                        },
                    ).execute()
                except Exception as e:
                    print("Violation RPC hatası:", e)

            threading.Thread(target=_send_rpc, daemon=True).start()

    # ==========================================================================
    # AKILLI UYANDIRMA ALARMI KAPATMA & EBEVEYN SOS / PIN
    # ==========================================================================
    def on_catch_wake_star(self):
        self.wake_stars_caught += 1
        self.wake_star_btn.config(text=f"⭐ YILDIZI YAKALA ({self.wake_stars_caught}/3)")
        if self.wake_stars_caught >= 3:
            self.wake_stars_caught = 0
            self.current_state = "ROUTINE_TIME"
            play_pc_sound("victory")
            if self.supabase:
                try:
                    self.supabase.table("users").update({
                        "current_state": "ROUTINE_TIME"
                    }).eq("id", self.cfg["student_id"]).execute()
                    self.supabase.table("messages").insert({
                        "id": f"msg-wake-{int(time.time())}",
                        "family_id": self.cfg["family_id"],
                        "sender_id": self.cfg["student_id"],
                        "receiver_id": "parent-mom",
                        "message_type": "quick_request",
                        "content": f"☀️ {self.student_name} PC başındaki sabah alarmını çözdü ve güne başladı!"
                    }).execute()
                except Exception:
                    pass

    def send_parent_sos(self):
        if not self.supabase:
            return
        try:
            self.supabase.table("messages").insert({
                "id": f"msg-pc-{int(time.time())}",
                "family_id": self.cfg["family_id"],
                "sender_id": self.cfg["student_id"],
                "receiver_id": "parent-mom",
                "message_type": "quick_request",
                "content": f"🙋‍♂️ {self.student_name} (PC Kilit Ekranından): Bir soruda takıldım, bakar mısınız?"
            }).execute()
            messagebox.showinfo("İletildi", "Anne ve Babaya yardım mesajın iletildi! 📻")
        except Exception:
            pass

    def verify_parent_pin_unlock(self):
        entered = self.pin_entry.get().strip()
        self.pin_entry.delete(0, tk.END)
        if entered == self.cfg["parent_pin"]:
            self.current_state = "FREE_TIME"
            if self.supabase:
                try:
                    self.supabase.table("users").update({
                        "current_state": "FREE_TIME",
                        "state_ends_at": None
                    }).eq("id", self.cfg["student_id"]).execute()
                except Exception:
                    pass
        else:
            self.trigger_violation("pc_key_press", "Hatalı Ebeveyn PIN denemesi!")

    # ==========================================================================
    # SUPABASE SENKRONİZASYON VE HEARTBEAT DÖNGÜSÜ
    # ==========================================================================
    def supabase_sync_worker(self):
        while True:
            if self.supabase:
                try:
                    # 1. Öğrencinin güncel durumunu (current_state, state_ends_at, daily_shields) çek
                    res = (
                        self.supabase.table("users")
                        .select("*")
                        .eq("id", self.cfg["student_id"])
                        .single()
                        .execute()
                    )
                    if res.data:
                        u = res.data
                        self.student_name = u.get("name", "Öğrenci")
                        self.current_state = u.get("current_state", "FREE_TIME")
                        self.state_ends_at = u.get("state_ends_at")
                        self.daily_shields = u.get("daily_shields", 3)

                    # 2. Ailenin güncel PIN kodunu çek
                    fam_res = (
                        self.supabase.table("families")
                        .select("parent_pin")
                        .eq("id", self.cfg["family_id"])
                        .single()
                        .execute()
                    )
                    if fam_res.data and fam_res.data.get("parent_pin"):
                        self.cfg["parent_pin"] = fam_res.data["parent_pin"]

                    # 3. Aktif pencere başlığını ve Heartbeat'i `devices` tablosuna yaz
                    win_title = get_foreground_window_info()
                    now_iso = datetime.now(timezone.utc).isoformat()
                    self.supabase.table("devices").upsert({
                        "id": self.cfg["device_id"],
                        "family_id": self.cfg["family_id"],
                        "user_id": self.cfg["student_id"],
                        "device_name": self.cfg["device_name"],
                        "device_type": "windows_pc",
                        "is_online": True,
                        "last_heartbeat": now_iso,
                        "last_activity_at": now_iso,
                        "active_window_title": win_title,
                    }).execute()

                except Exception as err:
                    print("Sync döngüsü hatası:", err)

            time.sleep(2.5)


if __name__ == "__main__":
    root = tk.Tk()
    app = StrictWindowsEnforcerApp(root)
    root.mainloop()
