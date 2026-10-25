"""
===============================================================================
1. config.py - FAMILY-TO-STUDY WINDOWS ENDPOINT AGENT YAPILANDIRMASI
===============================================================================
Merkezi Supabase veritabanı, PWA arayüz adresi, cihaz kimliği, ses ve sensör
eşik değerlerini yönetir. Ayarları hem ortam değişkenlerinden hem de yerel
`agent_config.json` dosyasından okur/günceller.
===============================================================================
"""

from __future__ import annotations

import ctypes
import hashlib
import json
import os
import socket
import sys
import time
import uuid
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Optional

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

BASE_DIR = Path(__file__).resolve().parent

# .env dosyasını agent dizininden de yükle (varsa)
try:
    if "load_dotenv" in locals():
        load_dotenv(BASE_DIR / ".env")
except Exception:
    pass

# GitHub Actions derleme anında oluşturulabilen build_secrets.py modülü (gitignored)
try:
    from build_secrets import BUILD_SUPABASE_URL, BUILD_SUPABASE_ANON_KEY, BUILD_PWA_URL
except ImportError:
    BUILD_SUPABASE_URL = ""
    BUILD_SUPABASE_ANON_KEY = ""
    BUILD_PWA_URL = ""

CONFIG_FILE_PATH = BASE_DIR / "agent_config.json"
LOCAL_CACHE_FILE_PATH = BASE_DIR / "local_cache.json"
LOCK_FILE_PATH = BASE_DIR / "updating.lock"
SCREENSHOT_TEMP_DIR = BASE_DIR / "temp_screenshots"
SCREENSHOT_TEMP_DIR.mkdir(parents=True, exist_ok=True)

# Faz 5: Versiyon ve Güncelleme Kilit Dosyası
AGENT_VERSION = "1.0.0"

# Varsayılan 6 Haneli Offline Master PIN: "145300" -> SHA-256 özeti
DEFAULT_OFFLINE_PIN_HASH = hashlib.sha256(b"145300").hexdigest()


@dataclass
class AgentConfig:
    # Supabase Merkezi Veritabanı Bilgileri (Yalnızca Public Anon Key kullanılır)
    supabase_url: str = (
        os.getenv("NEXT_PUBLIC_SUPABASE_URL")
        or BUILD_SUPABASE_URL
        or "https://pljxviezoilirlsoavto.supabase.co"
    )
    supabase_anon_key: str = (
        os.getenv("NEXT_PUBLIC_SUPABASE_ANON_KEY")
        or BUILD_SUPABASE_ANON_KEY
        or "sb_publishable_J9zEygp-UY48F0QYIM0gKg_BFg3KlTD"
    )

    # Gömülü QWebEngineView içinde gösterilecek PWA Adresi
    pwa_url: str = (
        os.getenv("PWA_PRODUCTION_URL")
        or os.getenv("FAMILY_PWA_URL")
        or BUILD_PWA_URL
        or "http://localhost:3000"
    )

    # Çoklu Aile (Multi-Tenant) ve Öğrenci/Cihaz Kimlikleri
    family_id: str = os.getenv("FAMILY_ID", "fam-ozdemir")
    user_id: str = os.getenv("STUDENT_USER_ID", "child-omer")
    device_id: str = os.getenv("DEVICE_ID", "dev-omer-pc")
    device_name: str = os.getenv(
        "DEVICE_NAME",
        f"{socket.gethostname()} (Windows PC)",
    )
    parent_receiver_id: str = os.getenv("PARENT_RECEIVER_ID", "parent-mom")
    parent_emergency_pin: str = os.getenv("NEXT_PUBLIC_PARENT_PIN", "1234")

    # Widget & Tam Ekran Boyut/Konum Ayarları
    widget_width: int = 350
    widget_height: int = 120
    widget_expanded_width: int = 900
    widget_expanded_height: int = 650
    overlay_popup_width: int = 600
    overlay_popup_height: int = 350
    # Faz 4 Otomatik Popup Boyutları ve Süreleri
    race_popup_width: int = 500
    race_popup_height: int = 260
    race_popup_duration_sec: int = 12
    appeal_popup_width: int = 550
    appeal_popup_height: int = 380
    appeal_popup_duration_sec: int = 15
    break_roulette_width: int = 800
    break_roulette_height: int = 600
    widget_margin_top: int = 24
    widget_margin_right: int = 24
    widget_opacity: float = 0.93

    # Zamanlayıcılar ve Sensör Cooldown Süreleri
    heartbeat_interval_sec: int = 15
    state_poll_interval_sec: int = 2
    violation_cooldown_sec: int = 30  # Spam önlemek için maksimum 30 saniyede bir ihlal kaydı
    noise_violation_cooldown_sec: int = 60  # Gürültü ihlali için 60 saniye cooldown
    noise_sustained_seconds: float = 8.0  # 8 saniye kesintisiz yüksek gürültü eşiği
    default_noise_threshold_db: int = 75  # Varsayılan dB eşiği
    eye_break_interval_sec: int = 1200  # 20 dakikada bir (1200 sn) 20-20-20 Göz ve Duruş molası
    eye_break_duration_sec: int = 20  # 20 saniye mola süresi
    input_idle_threshold_ms: int = 450  # Son girdi eşiği (ms)
    enforcer_tick_ms: int = 150  # Topmost ve Taskmgr kontrol sıklığı (ms)

    # Faz 2: Beyaz Liste (COMPUTER_STUDY) & Offline Guard Ayarları
    whitelist_check_interval_ms: int = 1500  # 1.5 saniyede bir aktif pencere/süreç denetimi
    offline_timeout_sec: int = 60  # 60 sn boyunca Supabase'e ulaşılamazsa OFFLINE_LOCK
    offline_pin_unlock_duration_sec: int = 3600  # Ebeveyn PIN girildiğinde 1 saat serbest kullanım

    # Donanım Ses Kontrolü (WAKE_UP_ALARM ve BREAK_TIME için %80) & Faz 4 Audio Ducking (%20)
    alarm_target_volume_scalar: float = 0.80
    audio_ducking_scalar: float = 0.20
    user_agent_signature: str = "FamilyOS-Windows-Agent/1.0"

    # Faz 5: Versiyon & OTA Otomatik Güncelleyici
    agent_version: str = AGENT_VERSION
    ota_check_interval_sec: int = 1800  # Her 30 dakikada bir sürüm denetimi

    # Supabase Storage Bucket İsimleri
    screenshot_bucket: str = "task-proofs"

    def save(self) -> None:
        """Güncel yapılandırmayı diske kaydeder."""
        try:
            with open(CONFIG_FILE_PATH, "w", encoding="utf-8") as f:
                json.dump(asdict(self), f, indent=2, ensure_ascii=False)
        except Exception as err:
            print(f"[Config] Kaydetme hatası: {err}")

    @classmethod
    def load(cls) -> "AgentConfig":
        """Diskte kayıtlı ayar varsa yükler, yoksa varsayılanları oluşturur."""
        instance = cls()
        if CONFIG_FILE_PATH.exists():
            try:
                with open(CONFIG_FILE_PATH, "r", encoding="utf-8") as f:
                    raw = json.load(f)
                for key, value in raw.items():
                    if hasattr(instance, key):
                        setattr(instance, key, value)
            except Exception as err:
                print(f"[Config] Okuma hatası, varsayılanlar kullanılıyor: {err}")
        else:
            instance.save()
        return instance

    @property
    def realtime_websocket_url(self) -> str:
        """Supabase Realtime WebSocket uç noktasını döndürür."""
        base = self.supabase_url.replace("https://", "wss://").replace("http://", "ws://")
        return f"{base}/realtime/v1/websocket?apikey={self.supabase_anon_key}&vsn=1.0.0"


# ==============================================================================
# FAZ 2: YEREL PIN VE DURUM ÖNBELLEĞİ (local_cache.json)
# ==============================================================================
class LocalCacheManager:
    """
    Ajan internete bağlıyken `family_settings.offline_master_pin_hash` ve
    öğrencinin `whitelist_config` / son durum verilerini yerel `local_cache.json`
    dosyasına kaydeder. İnternet kesildiğinde (Offline Guard) 6 haneli Ebeveyn
    PIN doğrulaması bu yerel önbellek üzerinden SHA-256 ile yapılır.
    """

    FILE_ATTRIBUTE_HIDDEN = 0x02

    def __init__(self, file_path: Path = LOCAL_CACHE_FILE_PATH) -> None:
        self.file_path = file_path
        self.data: dict[str, Any] = {
            "offline_master_pin_hash": DEFAULT_OFFLINE_PIN_HASH,
            "last_known_state": "FREE_TIME",
            "offline_unlocked_until_epoch": 0.0,
            "whitelist_config": {
                "allowed_exes": ["chrome.exe", "msedge.exe", "winword.exe", "acrord32.exe", "code.exe"],
                "allowed_keywords": ["eba", "ders", "ödev", "morpa", "tonguç", "matematik", "fen", "ingilizce"],
            },
            "noise_threshold_db": 75,
            "tts_announcements_enabled": True,
            "last_daily_reset_date": "",
            "updated_at_epoch": time.time(),
        }
        self.load()

    def _set_hidden_attribute_on_windows(self) -> None:
        if sys.platform == "win32" and self.file_path.exists():
            try:
                ctypes.windll.kernel32.SetFileAttributesW(
                    str(self.file_path), self.FILE_ATTRIBUTE_HIDDEN
                )
            except Exception:
                pass

    def _clear_hidden_attribute_on_windows(self) -> None:
        if sys.platform == "win32" and self.file_path.exists():
            try:
                # FILE_ATTRIBUTE_NORMAL = 0x80
                ctypes.windll.kernel32.SetFileAttributesW(str(self.file_path), 0x80)
            except Exception:
                pass

    def load(self) -> None:
        if not self.file_path.exists():
            self.save()
            return
        try:
            with open(self.file_path, "r", encoding="utf-8") as f:
                raw = json.load(f)
            if isinstance(raw, dict):
                self.data.update(raw)
        except Exception as err:
            print(f"[LocalCache] Okuma hatası: {err}")

    def save(self) -> None:
        try:
            self._clear_hidden_attribute_on_windows()
            self.data["updated_at_epoch"] = time.time()
            with open(self.file_path, "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=2, ensure_ascii=False)
            self._set_hidden_attribute_on_windows()
        except Exception as err:
            print(f"[LocalCache] Kaydetme hatası: {err}")

    def update_pin_hash(self, pin_hash: Optional[str]) -> None:
        if pin_hash and len(pin_hash.strip()) >= 32:
            cleaned = pin_hash.strip().lower()
            if self.data.get("offline_master_pin_hash") != cleaned:
                self.data["offline_master_pin_hash"] = cleaned
                self.save()

    def get_pin_hash(self) -> str:
        return str(self.data.get("offline_master_pin_hash") or DEFAULT_OFFLINE_PIN_HASH).lower()

    def verify_offline_pin(self, entered_pin: str) -> bool:
        """Girilen 6 haneli PIN'in SHA-256 özetini yerel önbellekle karşılaştırır."""
        try:
            cleaned = entered_pin.strip()
            if not cleaned:
                return False
            entered_hash = hashlib.sha256(cleaned.encode("utf-8")).hexdigest().lower()
            return entered_hash == self.get_pin_hash()
        except Exception:
            return False

    def grant_offline_unlock(self, duration_sec: int = 3600) -> float:
        """Ebeveyn doğru PIN girdiğinde 1 saatlik (3600 sn) yerel serbest kullanım izni tanımlar."""
        until_epoch = time.time() + max(60, duration_sec)
        self.data["offline_unlocked_until_epoch"] = until_epoch
        self.data["last_known_state"] = "FREE_TIME"
        self.save()
        return until_epoch

    def is_offline_pin_unlocked(self) -> bool:
        until_epoch = float(self.data.get("offline_unlocked_until_epoch") or 0.0)
        return time.time() < until_epoch

    def remaining_offline_unlock_seconds(self) -> int:
        until_epoch = float(self.data.get("offline_unlocked_until_epoch") or 0.0)
        return max(0, int(until_epoch - time.time()))

    def update_last_known_state(self, state_name: str) -> None:
        if state_name and self.data.get("last_known_state") != state_name:
            self.data["last_known_state"] = state_name
            self.save()

    def get_last_known_state(self) -> str:
        return str(self.data.get("last_known_state") or "FREE_TIME")

    def update_whitelist_config(self, whitelist_cfg: Optional[dict]) -> None:
        if isinstance(whitelist_cfg, dict):
            self.data["whitelist_config"] = whitelist_cfg
            self.save()

    def get_whitelist_config(self) -> dict:
        cfg = self.data.get("whitelist_config")
        if isinstance(cfg, dict):
            return cfg
        return {
            "allowed_exes": ["chrome.exe", "winword.exe"],
            "allowed_keywords": ["eba", "ders", "ödev"],
        }

    def update_noise_threshold_db(self, threshold_db: Optional[int]) -> None:
        if isinstance(threshold_db, (int, float)) and 40 <= int(threshold_db) <= 120:
            val = int(threshold_db)
            if self.data.get("noise_threshold_db") != val:
                self.data["noise_threshold_db"] = val
                self.save()

    def get_noise_threshold_db(self) -> int:
        val = self.data.get("noise_threshold_db")
        if isinstance(val, (int, float)) and 40 <= int(val) <= 120:
            return int(val)
        return 75

    def get_last_daily_reset_date(self) -> str:
        return str(self.data.get("last_daily_reset_date") or "")

    def set_last_daily_reset_date(self, date_str: str) -> None:
        if date_str and self.data.get("last_daily_reset_date") != date_str:
            self.data["last_daily_reset_date"] = date_str
            self.save()

    def update_tts_announcements_enabled(self, enabled: Optional[bool]) -> None:
        if isinstance(enabled, bool):
            if self.data.get("tts_announcements_enabled") != enabled:
                self.data["tts_announcements_enabled"] = enabled
                self.save()

    def get_tts_announcements_enabled(self) -> bool:
        val = self.data.get("tts_announcements_enabled")
        if isinstance(val, bool):
            return val
        return True


# Global tekil yapılandırma ve yerel önbellek nesneleri
CONFIG = AgentConfig.load()
LOCAL_CACHE = LocalCacheManager()


def is_ota_updating() -> bool:
    """OTA Güncelleme Bayrağı (`updating.lock`) aktif mi kontrol eder."""
    return LOCK_FILE_PATH.exists()


def set_ota_updating_lock() -> None:
    """OTA Güncelleme sırasında Watchdog müdahalesini engellemek için updating.lock oluşturur."""
    try:
        with open(LOCK_FILE_PATH, "w", encoding="utf-8") as f:
            f.write(f"updating_at={time.time()}\nversion={AGENT_VERSION}\n")
    except Exception as err:
        print(f"[Config] updating.lock oluşturma hatası: {err}")


def clear_ota_updating_lock() -> None:
    """OTA Güncelleme tamamlandığında updating.lock dosyasını temizler."""
    try:
        if LOCK_FILE_PATH.exists():
            LOCK_FILE_PATH.unlink()
    except Exception as err:
        print(f"[Config] updating.lock silme hatası: {err}")

