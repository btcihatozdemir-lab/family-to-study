"""
===============================================================================
core/state_machine.py - AJAN DURUM MAKİNESİ VE ZAMANLAYICI (SRP & OCP)
===============================================================================
Öğrencinin çalışma ve kilit durumunu yönetir. Gözlemcileri (Observer)
durum değişimleri ve saniyelik sayaç vuruşlarıyla bilgilendirir.
===============================================================================
"""

from __future__ import annotations
import threading
import time
from typing import Any, Dict, List, Optional
from core.interfaces import AgentState, IStateObserver


class AgentStateMachine:
    """
    Öğrencinin durum makinesi.
    Single Responsibility: Sadece durum geçişlerini ve sayaç matematiğini yönetir.
    Open/Closed: Yeni gözlemciler (UI, Telemetri, Ses) koda dokunmadan eklenebilir.
    """

    def __init__(self, initial_state: AgentState = AgentState.FREE_TIME) -> None:
        self._current_state = initial_state
        self._observers: List[IStateObserver] = []
        self._lock = threading.RLock()

        # Süre ve Sayaç Değişkenleri
        self._remaining_seconds = 0
        self._total_seconds = 0
        self._timer_thread: Optional[threading.Thread] = None
        self._timer_running = False

        # Öğrenci Profil Bilgisi
        self._student_name = "Öğrenci"
        self._points_balance = 0
        self._daily_shields = 3
        self._streak_days = 0
        self._current_task_title = "Ders & Odak Çalışması"

    # --------------------------------------------------------------------------
    # OBSERVER REGISTRATION (GOF OBSERVER PATTERN)
    # --------------------------------------------------------------------------
    def register_observer(self, observer: IStateObserver) -> None:
        with self._lock:
            if observer not in self._observers:
                self._observers.append(observer)

    def unregister_observer(self, observer: IStateObserver) -> None:
        with self._lock:
            if observer in self._observers:
                self._observers.remove(observer)

    def _notify_state_changed(self, new_state: AgentState, old_state: AgentState, metadata: Dict[str, Any]) -> None:
        with self._lock:
            observers_copy = list(self._observers)
        for obs in observers_copy:
            try:
                obs.on_state_changed(new_state, old_state, metadata)
            except Exception as err:
                print(f"[StateMachine] Observer hatası: {err}")

    def _notify_tick(self, rem: int, tot: int) -> None:
        with self._lock:
            observers_copy = list(self._observers)
        for obs in observers_copy:
            try:
                obs.on_tick(rem, tot)
            except Exception:
                pass

    # --------------------------------------------------------------------------
    # DURUM GEÇİŞLERİ (TRANSITIONS)
    # --------------------------------------------------------------------------
    @property
    def current_state(self) -> AgentState:
        with self._lock:
            return self._current_state

    @property
    def is_locked(self) -> bool:
        with self._lock:
            return self._current_state in (
                AgentState.STUDY_TIME,
                AgentState.ROUTINE_TIME,
                AgentState.WAKE_UP_ALARM,
                AgentState.SLEEP_TIME,
                AgentState.OFFLINE_LOCK,
            )

    @property
    def remaining_seconds(self) -> int:
        with self._lock:
            return self._remaining_seconds

    @property
    def total_seconds(self) -> int:
        with self._lock:
            return self._total_seconds

    def update_student_profile(
        self,
        name: str,
        points: int,
        shields: int,
        streak: int,
    ) -> None:
        with self._lock:
            self._student_name = name
            self._points_balance = points
            self._daily_shields = max(0, min(3, shields))
            self._streak_days = streak

    def get_profile_summary(self) -> Dict[str, Any]:
        with self._lock:
            return {
                "name": self._student_name,
                "points": self._points_balance,
                "shields": self._daily_shields,
                "streak": self._streak_days,
                "state": self._current_state.value,
                "remaining_seconds": self._remaining_seconds,
                "task_title": self._current_task_title,
            }

    def transition_to(
        self,
        new_state: AgentState,
        duration_minutes: int = 0,
        task_title: str = "",
        extra_metadata: Optional[Dict[str, Any]] = None,
    ) -> None:
        with self._lock:
            if self._current_state == new_state and self._remaining_seconds > 0:
                return

            old_state = self._current_state
            self._current_state = new_state
            if task_title:
                self._current_task_title = task_title

            # Süre Kurulumu
            self._stop_timer()
            if duration_minutes > 0:
                self._total_seconds = duration_minutes * 60
                self._remaining_seconds = self._total_seconds
                self._start_timer()
            else:
                self._total_seconds = 0
                self._remaining_seconds = 0

            meta = extra_metadata or {}
            meta.update(self.get_profile_summary())

        # Gözlemcileri bilgilendir
        self._notify_state_changed(new_state, old_state, meta)

    # --------------------------------------------------------------------------
    # SAYAÇ İŞ PARÇACIĞI (TICK ENGINE)
    # --------------------------------------------------------------------------
    def _start_timer(self) -> None:
        self._timer_running = True
        self._timer_thread = threading.Thread(
            target=self._run_timer_loop,
            name="StateMachineTimer",
            daemon=True,
        )
        self._timer_thread.start()

    def _stop_timer(self) -> None:
        self._timer_running = False

    def _run_timer_loop(self) -> None:
        while self._timer_running:
            time.sleep(1.0)
            if not self._timer_running:
                break

            with self._lock:
                if self._remaining_seconds > 0:
                    self._remaining_seconds -= 1
                    rem = self._remaining_seconds
                    tot = self._total_seconds
                else:
                    rem = 0
                    tot = self._total_seconds

            self._notify_tick(rem, tot)

            # Süre dolduysa otomatik geçiş
            if rem <= 0:
                with self._lock:
                    self._timer_running = False
                    if self._current_state == AgentState.STUDY_TIME:
                        # Ders bitince 5 dakikalık aktif molaya veya serbest zamana geç
                        auto_state = AgentState.FREE_TIME
                    elif self._current_state == AgentState.ACTIVE_BREAK:
                        auto_state = AgentState.FREE_TIME
                    else:
                        auto_state = AgentState.FREE_TIME
                self.transition_to(auto_state)
                break
