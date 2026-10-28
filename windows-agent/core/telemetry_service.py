"""
===============================================================================
core/telemetry_service.py - SUPABASE REALTIME & TELEMETRİ SERVİSİ (SRP & DIP)
===============================================================================
Merkezi veritabanı ile çift yönlü iletişim:
1) Öğrencinin canlı durumunu dinler (Ebeveyn kilidi açınca/kapatınca anında yakalar).
2) Aktif pencere başlığını ve kalp atışını (Heartbeat) iletir.
3) Kural ihlali durumunda kalkan kırma ve ebeveyne alarm bildirimini tetikler.
===============================================================================
"""

from __future__ import annotations
import threading
import time
from datetime import datetime, timezone
from typing import Any, Callable, Dict, Optional

try:
    from supabase import create_client, Client
except ImportError:
    create_client = None
    Client = None

from core.interfaces import AgentState, ITelemetryService


class SupabaseTelemetryService(ITelemetryService):
    """
    Supabase Realtime ve REST iletişim servisi.
    Single Responsibility: Yalnızca sunucuyla veri alışverişini yönetir.
    """

    def __init__(
        self,
        supabase_url: str,
        supabase_key: str,
        user_id: str,
        family_id: str,
        device_id: str,
        device_token: Optional[str] = None,
        on_remote_state_change: Optional[Callable[[AgentState, int, str], None]] = None,
    ) -> None:
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.user_id = user_id
        self.family_id = family_id
        self.device_id = device_id
        self.device_token = device_token or ""
        self._on_remote_state_change = on_remote_state_change

        self._client: Optional[Any] = None
        self._listener_running = False
        self._listener_thread: Optional[threading.Thread] = None

        if create_client and supabase_url and supabase_key:
            try:
                self._client = create_client(supabase_url, supabase_key)
                if self._client and self.device_token:
                    # RLS resolver'a x-device-token header'ını iliştir
                    if hasattr(self._client, "postgrest") and hasattr(self._client.postgrest, "headers"):
                        self._client.postgrest.headers["x-device-token"] = self.device_token
                    elif hasattr(self._client, "options") and hasattr(self._client.options, "headers"):
                        self._client.options.headers["x-device-token"] = self.device_token
            except Exception as e:
                print(f"[TelemetryService] Supabase başlatma uyarısı: {e}")

    def start_realtime_listener(self) -> None:
        """Ebeveynin panelden vereceği durum emirlerini periyodik/realtime dinler."""
        if self._listener_running:
            return
        self._listener_running = True
        self._listener_thread = threading.Thread(
            target=self._run_listener_loop,
            name="SupabaseTelemetryListener",
            daemon=True,
        )
        self._listener_thread.start()

    def stop_realtime_listener(self) -> None:
        self._listener_running = False

    def _run_listener_loop(self) -> None:
        while self._listener_running:
            try:
                remote_data = self.fetch_remote_state()
                if remote_data and self._on_remote_state_change:
                    raw_state = remote_data.get("current_state", "FREE_TIME")
                    title = remote_data.get("current_task_title", "Ders & Odak Modu")
                    ends_at = remote_data.get("state_ends_at")

                    # Kalan dakikayı hesapla
                    dur_mins = 0
                    if ends_at:
                        try:
                            target_dt = datetime.fromisoformat(ends_at.replace("Z", "+00:00"))
                            now_dt = datetime.now(timezone.utc)
                            diff = (target_dt - now_dt).total_seconds()
                            if diff > 0:
                                dur_mins = int(diff // 60)
                        except Exception:
                            dur_mins = 25

                    # Enum eşleştirme
                    target_state = AgentState.FREE_TIME
                    if raw_state == "STUDY_TIME":
                        target_state = AgentState.STUDY_TIME
                    elif raw_state == "ROUTINE_TIME":
                        target_state = AgentState.ROUTINE_TIME
                    elif raw_state == "WAKE_UP_ALARM":
                        target_state = AgentState.WAKE_UP_ALARM
                    elif raw_state == "SLEEP_TIME":
                        target_state = AgentState.SLEEP_TIME

                    self._on_remote_state_change(target_state, dur_mins, title)

            except Exception as err:
                pass

            time.sleep(2.5)

    def fetch_remote_state(self) -> Optional[Dict[str, Any]]:
        if not self._client or not self.user_id:
            return None
        try:
            res = (
                self._client.from_("users")
                .select("id, current_state, state_ends_at, points_balance, daily_shields, streak_days")
                .eq("id", self.user_id)
                .limit(1)
                .execute()
            )
            if res.data and len(res.data) > 0:
                return res.data[0]
        except Exception:
            pass
        return None

    def send_heartbeat(self, state: AgentState, active_window: str) -> bool:
        if not self._client or not self.user_id:
            return False
        try:
            self._client.from_("devices").upsert({
                "id": self.device_id,
                "user_id": self.user_id,
                "family_id": self.family_id,
                "current_state": state.value,
                "active_window_title": active_window[:200] if active_window else "Masaüstü",
                "last_heartbeat": datetime.now(timezone.utc).isoformat(),
            }, on_conflict="id").execute()
            return True
        except Exception:
            return False

    def report_violation(self, violation_type: str, penalty_points: int = 0) -> bool:
        if not self._client or not self.user_id:
            return False
        try:
            # 1. RPC çağrısı: kalkan kır ve ebeveyne bildir
            self._client.rpc("record_violation_and_break_shield", {
                "p_user_id": self.user_id,
                "p_family_id": self.family_id,
                "p_violation_type": violation_type,
                "p_details": f"Windows Agent Koruma İhlali: {violation_type}",
            }).execute()
            return True
        except Exception:
            try:
                # RPC yoksa violations tablosuna doğrudan insert fallback
                self._client.from_("violations").insert({
                    "user_id": self.user_id,
                    "family_id": self.family_id,
                    "type": violation_type,
                    "created_at": datetime.now(timezone.utc).isoformat(),
                }).execute()
                return True
            except Exception:
                return False
