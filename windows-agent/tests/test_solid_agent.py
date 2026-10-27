"""
===============================================================================
tests/test_solid_agent.py - SOLID MİMARİSİ VE AJAN BİRİM TESTLERİ
===============================================================================
Kapsam:
1) SOLID Prensip Doğrulaması (SRP, OCP, LSP, ISP, DIP)
2) Durum Makinesi ve Gözlemci (Observer) Bildirimleri
3) Kaçış ve İhlal Yakalama (Kalkan Kırma & Ceza)
4) Ebeveyn Acil Kilit Çözme (Master PIN SHA-256)
5) Serbest Zaman (Non-intrusive) vs Kilit Modu Ayrımı
===============================================================================
"""

from __future__ import annotations
import hashlib
import time
import unittest
from pathlib import Path
import sys

AGENT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(AGENT_DIR))

from core.interfaces import (
    AgentState,
    IStateObserver,
    ILockEnforcer,
    ISystemGuard,
    ITelemetryService,
    IWatchdogManager,
)
from core.state_machine import AgentStateMachine
from core.system_guard import FallbackSystemGuard
from core.telemetry_service import SupabaseTelemetryService
from agent_app import AgentApp
from config import LocalCacheManager


class MockObserver(IStateObserver):
    """Test Gözlemcisi (Observer Pattern Doğrulama)."""

    def __init__(self) -> None:
        self.state_changes = []
        self.ticks = []

    def on_state_changed(self, new_state: AgentState, old_state: AgentState, metadata: dict) -> None:
        self.state_changes.append((new_state, old_state, metadata))

    def on_tick(self, remaining_seconds: int, total_seconds: int) -> None:
        self.ticks.append((remaining_seconds, total_seconds))


class MockTelemetry(ITelemetryService):
    """Test Telemetri Servisi (DIP Doğrulama)."""

    def __init__(self) -> None:
        self.heartbeats = []
        self.violations = []

    def send_heartbeat(self, state: AgentState, active_window: str) -> bool:
        self.heartbeats.append((state, active_window))
        return True

    def report_violation(self, violation_type: str, penalty_points: int = 0) -> bool:
        self.violations.append((violation_type, penalty_points))
        return True

    def fetch_remote_state(self) -> dict:
        return {"current_state": "FREE_TIME"}


class MockLockEnforcer(ILockEnforcer):
    """Test Kilit Enforcer (LSP Doğrulama)."""

    def __init__(self) -> None:
        self.locked = False
        self.last_title = ""

    def lock_screen(self, state: AgentState, duration_minutes: int, title: str) -> None:
        self.locked = True
        self.last_title = title

    def unlock_screen(self) -> None:
        self.locked = False

    def is_locked(self) -> bool:
        return self.locked


class TestSolidArchitecture(unittest.TestCase):
    """SOLID Tasarım Prensipleri ve Davranış Testleri."""

    def setUp(self) -> None:
        self.sm = AgentStateMachine(initial_state=AgentState.FREE_TIME)
        self.observer = MockObserver()
        self.sm.register_observer(self.observer)

    # --------------------------------------------------------------------------
    # 1. SINGLE RESPONSIBILITY & OBSERVER PATTERN (SRP & OCP)
    # --------------------------------------------------------------------------
    def test_state_machine_transition_and_observer_notification(self) -> None:
        """Durum geçişleri tüm gözlemcilere bildirim göndermelidir."""
        self.assertEqual(self.sm.current_state, AgentState.FREE_TIME)
        self.assertFalse(self.sm.is_locked)

        # 25 Dakikalık Ders Moduna Geç
        self.sm.transition_to(
            new_state=AgentState.STUDY_TIME,
            duration_minutes=25,
            task_title="Matematik Testi 10 Soru",
        )

        self.assertEqual(self.sm.current_state, AgentState.STUDY_TIME)
        self.assertTrue(self.sm.is_locked)
        self.assertEqual(self.sm.total_seconds, 25 * 60)
        self.assertEqual(self.sm.remaining_seconds, 25 * 60)

        # Gözlemci bildirimi aldı mı?
        self.assertEqual(len(self.observer.state_changes), 1)
        new_st, old_st, meta = self.observer.state_changes[0]
        self.assertEqual(new_st, AgentState.STUDY_TIME)
        self.assertEqual(old_st, AgentState.FREE_TIME)
        self.assertEqual(meta.get("task_title"), "Matematik Testi 10 Soru")

    def test_profile_update_and_summary(self) -> None:
        """Öğrencinin puan, kalkan ve serisi durum makinesinde tutarlı saklanmalıdır."""
        self.sm.update_student_profile(
            name="Ömer Asaf",
            points=120,
            shields=3,
            streak=5,
        )
        summary = self.sm.get_profile_summary()
        self.assertEqual(summary["name"], "Ömer Asaf")
        self.assertEqual(summary["points"], 120)
        self.assertEqual(summary["shields"], 3)
        self.assertEqual(summary["streak"], 5)

    # --------------------------------------------------------------------------
    # 2. LISKOV SUBSTITUTION & INTERFACE SEGREGATION (LSP & ISP)
    # --------------------------------------------------------------------------
    def test_fallback_guard_lsp_compliance(self) -> None:
        """FallbackSystemGuard, ISystemGuard sözleşmesini eksiksiz uygulamalıdır."""
        violations = []
        guard = FallbackSystemGuard(on_violation_callback=lambda v: violations.append(v))

        self.assertTrue(guard.start_hooks())
        self.assertIn("Test", guard.get_foreground_app_title())

        # Alt+F4 saldırı simülasyonu
        guard.simulate_alt_f4_attempt()
        self.assertEqual(len(violations), 1)
        self.assertEqual(violations[0], "simulated_alt_f4_attempt")

        guard.stop_hooks()

    # --------------------------------------------------------------------------
    # 3. DEPENDENCY INVERSION (DIP) & AGENT APP ORCHESTRATION
    # --------------------------------------------------------------------------
    def test_agent_app_event_wiring_and_shield_breaking(self) -> None:
        """Kaçış girişiminde AgentApp kalkan kırmalı ve telemetriye bildirmelidir."""
        telemetry = MockTelemetry()
        guard = FallbackSystemGuard()
        sm = AgentStateMachine(initial_state=AgentState.FREE_TIME)
        sm.update_student_profile(name="Ömer", points=100, shields=3, streak=2)

        app = AgentApp(
            state_machine=sm,
            system_guard=guard,
            telemetry=telemetry,
        )

        # Ders moduna geç
        sm.transition_to(AgentState.STUDY_TIME, duration_minutes=30)
        self.assertTrue(sm.is_locked)

        # İhlal tetikle (Kullanıcı kilidi kapatmaya çalıştı)
        app._handle_guard_violation("alt_f4_escape_attempt")

        # Telemetriye bildirildi mi?
        self.assertEqual(len(telemetry.violations), 1)
        self.assertEqual(telemetry.violations[0][0], "alt_f4_escape_attempt")

        # Kalkan kırıldı mı? (3 -> 2)
        summary = sm.get_profile_summary()
        self.assertEqual(summary["shields"], 2)

    # --------------------------------------------------------------------------
    # 4. EMERGENCY UNLOCK & SECURITY
    # --------------------------------------------------------------------------
    def test_emergency_unlock_resets_state_to_free_time(self) -> None:
        """Ebeveyn acil kilit çözme durumunda anında serbest zamana dönülmelidir."""
        sm = AgentStateMachine(initial_state=AgentState.STUDY_TIME)
        app = AgentApp(state_machine=sm, telemetry=MockTelemetry())

        self.assertTrue(sm.is_locked)
        app._handle_emergency_unlock()
        self.assertEqual(sm.current_state, AgentState.FREE_TIME)
        self.assertFalse(sm.is_locked)

    def test_active_break_completion_awards_points(self) -> None:
        """Aktif mola tamamlandığında öğrenciye +5 bonus puan eklenmelidir."""
        sm = AgentStateMachine(initial_state=AgentState.STUDY_TIME)
        sm.update_student_profile(name="Meryem", points=50, shields=3, streak=1)
        app = AgentApp(state_machine=sm, telemetry=MockTelemetry())

        app._handle_break_action("Su İç")
        summary = sm.get_profile_summary()
        self.assertEqual(summary["points"], 55)


if __name__ == "__main__":
    unittest.main()
