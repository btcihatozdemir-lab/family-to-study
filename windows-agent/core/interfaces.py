"""
===============================================================================
core/interfaces.py - SOLID ARAYÜZ TANIMLARI (INTERFACE SEGREGATION & DIP)
===============================================================================
FamilyToStudy Windows Endpoint Agent mimarisinin soyut sözleşmeleri.
Tüm bileşenler bu arayüzler üzerinden haberleşir; somut sınıflara doğrudan
bağımlılık (tight coupling) engellenir.
===============================================================================
"""

from __future__ import annotations
from abc import ABC, abstractmethod
from enum import Enum
from typing import Any, Callable, Dict, List, Optional


class AgentState(str, Enum):
    """Ajanın ve öğrencinin çalışma durumları."""
    FREE_TIME = "FREE_TIME"           # Serbest zaman: kullanıcıyı rahatsız etmeyen mini floater
    STUDY_TIME = "STUDY_TIME"         # Ders ve odak modu: engellenemez tam ekran kilit
    ROUTINE_TIME = "ROUTINE_TIME"     # Rutin hazırlık modu: tam ekran kilit
    ACTIVE_BREAK = "ACTIVE_BREAK"     # 20-20-20 veya aktif mola: göz, su, cam, esneme
    WAKE_UP_ALARM = "WAKE_UP_ALARM"   # Sabah uyanma alarmı: sesli + bilmeceli kilit
    SLEEP_TIME = "SLEEP_TIME"         # Gece uyku modu: tam ekran kilit
    OFFLINE_LOCK = "OFFLINE_LOCK"     # İnternet kesilince korunan çevrimdışı kilit


class IStateObserver(ABC):
    """Durum ve sayaç güncellemelerini dinleyen gözlemci arayüzü (Observer Pattern)."""

    @abstractmethod
    def on_state_changed(self, new_state: AgentState, old_state: AgentState, metadata: Dict[str, Any]) -> None:
        """Ajanın çalışma durumu değiştiğinde tetiklenir."""
        pass

    @abstractmethod
    def on_tick(self, remaining_seconds: int, total_seconds: int) -> None:
        """Her 1 saniyelik geri sayım darbesinde tetiklenir."""
        pass


class ILockEnforcer(ABC):
    """Ekran kilitleme ve serbest bırakma sorumluluğunu taşıyan arayüz (SRP)."""

    @abstractmethod
    def lock_screen(self, state: AgentState, duration_minutes: int, title: str) -> None:
        """Ekranı kapatılamayan ve engellenemeyen tam ekran kilit moduna alır."""
        pass

    @abstractmethod
    def unlock_screen(self) -> None:
        """Ekran kilidini kaldırır ve kullanıcıyı rahatsız etmeyen mini durum moduna döner."""
        pass

    @abstractmethod
    def is_locked(self) -> bool:
        """Ekranın şu anda kilitli olup olmadığını döndürür."""
        pass


class ISystemGuard(ABC):
    """İşletim sistemi düzeyindeki düşük seviyeli kanca ve koruma arayüzü (Win32 / Fallback)."""

    @abstractmethod
    def start_hooks(self) -> bool:
        """Düşük seviyeli klavye kancasını (Alt+Tab, Alt+F4, WinKey) başlatır."""
        pass

    @abstractmethod
    def stop_hooks(self) -> None:
        """Kancaları serbest bırakır."""
        pass

    @abstractmethod
    def terminate_task_manager(self) -> bool:
        """Çalışan Görev Yöneticisi sürecini tespit edip sonlandırır."""
        pass

    @abstractmethod
    def enforce_window_topmost(self, window_handle: Any) -> None:
        """Pencereyi tüm monitörlerin ve oyunların en üstünde kalmaya zorlar."""
        pass

    @abstractmethod
    def get_foreground_app_title(self) -> str:
        """Öğrencinin ekranda aktif kullandığı pencerenin başlığını döndürür."""
        pass


class ITelemetryService(ABC):
    """Merkezi Supabase ağı ile gerçek zamanlı iletişim arayüzü."""

    @abstractmethod
    def send_heartbeat(self, state: AgentState, active_window: str) -> bool:
        """Ebeveyne canlı telemetri ve cihazın açık olduğu bilgisini iletir."""
        pass

    @abstractmethod
    def report_violation(self, violation_type: str, penalty_points: int = 0) -> bool:
        """Kural ihlali (Alt+F4 girişimi, kilitten kaçış, izinsiz tuş) bildirir ve kalkan kırar."""
        pass

    @abstractmethod
    def fetch_remote_state(self) -> Optional[Dict[str, Any]]:
        """Veritabanından öğrencinin son durumunu çeker."""
        pass


class IWatchdogManager(ABC):
    """İkiz nöbetçi / anti-kill proses bekçisi arayüzü."""

    @abstractmethod
    def start_guard(self) -> None:
        """Nöbetçi sürecini başlatır."""
        pass

    @abstractmethod
    def stop_guard(self) -> None:
        """Nöbetçi sürecini durdurur."""
        pass

    @abstractmethod
    def is_guard_alive(self) -> bool:
        """Nöbetçinin hayatta olup olmadığını kontrol eder."""
        pass
