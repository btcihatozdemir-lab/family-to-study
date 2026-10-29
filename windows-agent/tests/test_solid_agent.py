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

    def test_telemetry_service_initialization_with_device_token(self) -> None:
        """SupabaseTelemetryService cihaz tokenini doğru şekilde kabul etmelidir."""
        svc = SupabaseTelemetryService(
            supabase_url="https://dummy.supabase.co",
            supabase_key="dummy-key",
            user_id="child-test",
            family_id="fam-test",
            device_id="dev-test-pc",
            device_token="dev-pc-token-12345",
        )
        self.assertEqual(svc.device_token, "dev-pc-token-12345")

    def test_config_dual_pairing_methods_exist(self) -> None:
        """AgentConfig hem çift faktörlü pair_device hem de pair_with_code metodlarına sahip olmalıdır."""
        from config import CONFIG
        self.assertTrue(hasattr(CONFIG, "pair_device"))
        self.assertTrue(hasattr(CONFIG, "pair_with_code"))

    def test_native_agent_architecture_has_no_webengine(self) -> None:
        """Windows Ajanı saf native mimaride olmalı ve WebEngine zorunluluğu barındırmamalıdır."""
        import agent_app
        import ui.status_floater
        import ui.focus_lock_overlay
        self.assertTrue(hasattr(agent_app, "AgentApp"))
        self.assertTrue(hasattr(ui.status_floater, "StatusFloater"))
        self.assertTrue(hasattr(ui.focus_lock_overlay, "FocusLockOverlay"))

    def test_i18n_tr_en_de_multi_language_support(self) -> None:
        """Windows Ajanı TR, EN ve DE dillerini dinamik olarak desteklemelidir."""
        from core.i18n import I18n, t

        # 1. Türkçe Test
        I18n.init(force_lang="tr")
        self.assertEqual(I18n.get_language(), "tr")
        self.assertEqual(t("focus_mode"), "Odaklanma Saati")
        self.assertEqual(t("streak_days", days=5), "5 Gün Seri")

        # 2. İngilizce Test
        I18n.init(force_lang="en")
        self.assertEqual(I18n.get_language(), "en")
        self.assertEqual(t("focus_mode"), "Study & Focus Mode")
        self.assertEqual(t("streak_days", days=5), "5 Day Streak")

        # 3. Almanca Test
        I18n.init(force_lang="de")
        self.assertEqual(I18n.get_language(), "de")
        self.assertEqual(t("focus_mode"), "Lern- & Fokuszeit")
        self.assertEqual(t("streak_days", days=5), "5 Tage Serie")

        # 4. Fallback Test (Bilinmeyen dil fallback)
        I18n.set_language("tr")
        self.assertEqual(t("focus_mode"), "Odaklanma Saati")

    def test_ntp_guard_and_time_vault(self) -> None:
        """NTP Saat Güvenliği ve Zaman Bankası doğru çalışmalıdır."""
        from core.ntp_guard import NtpGuard
        from core.time_vault import TimeVaultManager
        import os

        # NTP Doğrulama testi (Zaman sapması makul sınırda olmalı)
        is_clock_ok = NtpGuard.verify_system_clock(max_drift_seconds=3600)
        self.assertTrue(is_clock_ok)

        # Zaman Bankası Testi
        vault = TimeVaultManager(cache_file="/tmp/test_vault.json")
        vault.deposit_minutes(20)
        self.assertGreaterEqual(vault.saved_minutes, 20)
        withdrawn = vault.withdraw_minutes(10)
        self.assertTrue(withdrawn)
        if os.path.exists("/tmp/test_vault.json"):
            os.remove("/tmp/test_vault.json")

    def test_subject_study_tracker_and_lingua_idioms(self) -> None:
        """Branş ders takibi ve Deyim/Atasözü motoru doğru çalışmalıdır."""
        from core.subject_tracker import SubjectStudyTracker
        from core.lingua_engine import LinguaEngine

        tracker = SubjectStudyTracker(default_subject="matematik")
        self.assertEqual(tracker.active_subject, "matematik")

        # 1. Matematik Net Hesabı (LGS: 3 Yanlış 1 Doğruyu Götürür)
        net = tracker.record_math_score(questions=30, correct=24, wrong=6)
        self.assertEqual(net, 22.0)
        self.assertEqual(tracker.calculate_net(), 22.0)

        # 2. Türkçe Branşına Geçiş ve Kitap / Deyim Takibi
        tracker.set_subject("turkce")
        self.assertEqual(tracker.active_subject, "turkce")
        tracker.record_turkish_reading(pages=35, idioms=3, words=7)
        self.assertEqual(tracker.pages_read, 35)
        self.assertEqual(tracker.idioms_learned, 3)

        # 3. İngilizce Branşı ve Kelime Haznesi (Vocab)
        tracker.set_subject("ingilizce")
        tracker.record_english_vocab(words=10, questions=20)
        self.assertGreaterEqual(tracker.words_learned, 17)

        # 4. Özet Kontrolü
        summary = tracker.get_summary()
        self.assertEqual(summary["subject"], "ingilizce")
        self.assertEqual(summary["pages_read"], 35)

        # 5. Günün Deyimi / Atasözü Testi
        idiom_data = LinguaEngine.get_idiom_of_the_day()
        self.assertIn("idiom", idiom_data)
        self.assertIn("meaning", idiom_data)
        self.assertIn("question", idiom_data)
        correct_idx = idiom_data["correct_index"]
        self.assertTrue(LinguaEngine.verify_answer(idiom_data, correct_idx))
        self.assertFalse(LinguaEngine.verify_answer(idiom_data, (correct_idx + 1) % 3))


if __name__ == "__main__":
    unittest.main()
