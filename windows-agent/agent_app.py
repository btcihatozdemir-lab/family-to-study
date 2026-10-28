"""
===============================================================================
agent_app.py - BAĞIMLILIK ENJEKSİYONU VE AJAN ORKESTRATÖRÜ (SOLID DIP & SRP)
===============================================================================
Tüm SOLID bileşenlerini (Durum Makinesi, Sistem Kancaları, Telemetri, Arayüz)
bir araya getirir ve aralarındaki olay akışını yönetir.
===============================================================================
"""

from __future__ import annotations
import os
import sys
import threading
import time
from pathlib import Path
from typing import Any, Optional

from config import (
    BASE_DIR,
    CONFIG,
    LOCAL_CACHE,
    load_device_auth,
)
from core.interfaces import (
    AgentState,
    ILockEnforcer,
    ISystemGuard,
    ITelemetryService,
    IWatchdogManager,
)
from core.state_machine import AgentStateMachine
from core.system_guard import create_system_guard
from core.telemetry_service import SupabaseTelemetryService
from core.watchdog_service import TwinWatchdogManager
from ui.status_floater import StatusFloater
from ui.focus_lock_overlay import FocusLockOverlay


class AgentApp:
    """
    FamilyToStudy Windows Endpoint Agent Orkestratörü.
    Dependency Inversion Principle (DIP): Bileşenleri arayüzleri üzerinden bağlar.
    """

    def __init__(
        self,
        state_machine: Optional[AgentStateMachine] = None,
        system_guard: Optional[ISystemGuard] = None,
        telemetry: Optional[ITelemetryService] = None,
        watchdog: Optional[IWatchdogManager] = None,
    ) -> None:
        self.state_machine = state_machine or AgentStateMachine()
        self.system_guard = system_guard or create_system_guard(on_violation=self._handle_guard_violation)
        self.watchdog = watchdog or TwinWatchdogManager(base_dir=BASE_DIR)

        # Cihaz ve Ebeveyn Yetkisi
        auth = load_device_auth()
        user_id = auth.get("user_id", CONFIG.user_id)
        family_id = auth.get("family_id", CONFIG.family_id)

        self.telemetry = telemetry or SupabaseTelemetryService(
            supabase_url=CONFIG.supabase_url,
            supabase_key=CONFIG.supabase_anon_key,
            user_id=user_id,
            family_id=family_id,
            device_id=CONFIG.device_id,
            on_remote_state_change=self._handle_remote_state_change,
        )

        # UI Katmanı (Gözlemciler)
        self.floater = StatusFloater()
        self.lock_overlay = FocusLockOverlay(
            on_emergency_unlock=self._handle_emergency_unlock,
            on_break_action=self._handle_break_action,
        )

        # Observer Kaydı
        self.state_machine.register_observer(self.floater)
        self.state_machine.register_observer(self.lock_overlay)
        self.state_machine.register_observer(self)

        self._heartbeat_thread: Optional[threading.Thread] = None
        self._running = False

    def start(self) -> None:
        """Ajanı ve tüm servisleri başlatır."""
        print("[AgentApp] FamilyToStudy Windows Endpoint Agent başlatılıyor...")
        self._running = True

        # 1. İkiz Nöbetçiyi Devreye Al
        self.watchdog.start_guard()

        # 2. Supabase Telemetri Dinleyicisini Başlat
        if hasattr(self.telemetry, "start_realtime_listener"):
            self.telemetry.start_realtime_listener()

        # 3. Canlı Kalp Atışı (Heartbeat) Döngüsünü Başlat
        self._heartbeat_thread = threading.Thread(
            target=self._run_heartbeat_loop,
            name="AgentHeartbeatWorker",
            daemon=True,
        )
        self._heartbeat_thread.start()

        # 4. Serbest Zaman Durum Kapsülünü Göster
        self.floater.show()

    def stop(self) -> None:
        self._running = False
        self.system_guard.stop_hooks()
        self.watchdog.stop_guard()
        if hasattr(self.telemetry, "stop_realtime_listener"):
            self.telemetry.stop_realtime_listener()
        print("[AgentApp] Ajan durduruldu.")

    # --------------------------------------------------------------------------
    # DURUM DİNLEYİCİSİ (STATE OBSERVER)
    # --------------------------------------------------------------------------
    def on_state_changed(self, new_state: AgentState, old_state: AgentState, metadata: dict) -> None:
        print(f"[AgentApp] Durum Değişti: {old_state.value} -> {new_state.value}")

        if new_state in (AgentState.STUDY_TIME, AgentState.ROUTINE_TIME, AgentState.WAKE_UP_ALARM):
            # Ders modunda kaçış tuşlarını ve Task Manager'ı anında kilitle
            self.system_guard.start_hooks()
        else:
            # Serbest zamanda öğrenciyi kesinlikle rahatsız etme, kancaları kaldır
            self.system_guard.stop_hooks()

    def on_tick(self, remaining_seconds: int, total_seconds: int) -> None:
        pass

    # --------------------------------------------------------------------------
    # OLAY YÖNETİCİLERİ (EVENT HANDLERS)
    # --------------------------------------------------------------------------
    def _handle_remote_state_change(self, target_state: AgentState, duration_minutes: int, title: str) -> None:
        """Ebeveynden gelen komut (Ders başlat, serbest zamana al vb.)."""
        if self.state_machine.current_state != target_state:
            self.state_machine.transition_to(
                new_state=target_state,
                duration_minutes=duration_minutes,
                task_title=title,
            )

    def _handle_guard_violation(self, violation_type: str) -> None:
        """Ders modundayken kapatma veya kaçış girişiminde kalkan kır."""
        print(f"[AgentApp] 🚨 KURAL İHLALİ TESPİT EDİLDİ: {violation_type}")
        self.telemetry.report_violation(violation_type)

        # Durum makinesindeki kalkanı eksilt
        summary = self.state_machine.get_profile_summary()
        current_shields = summary.get("shields", 3)
        new_shields = max(0, current_shields - 1)
        self.state_machine.update_student_profile(
            name=summary.get("name", "Öğrenci"),
            points=summary.get("points", 0),
            shields=new_shields,
            streak=summary.get("streak", 0),
        )

    def _handle_emergency_unlock(self) -> None:
        """Ebeveyn Master PIN ile acil kilit açıldığında."""
        print("[AgentApp] 🛡️ Ebeveyn Master PIN ile kilit kaldırıldı. Serbest zamana geçildi.")
        self.state_machine.transition_to(AgentState.FREE_TIME)

    def _handle_break_action(self, break_title: str) -> None:
        """Öğrenci aktif mola kartını tamamladığında."""
        print(f"[AgentApp] ✨ Aktif Mola Tamamlandı: {break_title}")
        summary = self.state_machine.get_profile_summary()
        # +5 Bonus puan ekle
        self.state_machine.update_student_profile(
            name=summary.get("name", "Öğrenci"),
            points=summary.get("points", 0) + 5,
            shields=summary.get("shields", 3),
            streak=summary.get("streak", 0),
        )

    def _run_heartbeat_loop(self) -> None:
        while self._running:
            try:
                active_win = self.system_guard.get_foreground_app_title()
                cur_state = self.state_machine.current_state
                self.telemetry.send_heartbeat(cur_state, active_win)
            except Exception:
                pass
            time.sleep(3.0)
