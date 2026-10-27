"""
===============================================================================
ui/focus_lock_overlay.py - ENGELLENEMEZ TAM EKRAN KİLİT ARAYÜZÜ (SRP & LSP)
===============================================================================
Ders ve Odak modunda tüm monitörleri kaplar, kaçış tuşlarını engeller,
geri sayım sayacını, aktif mola butonlarını ve acil ebeveyn kilidini gösterir.
Alt+F4 ve kapatma girişimlerini kesin olarak yutar.
===============================================================================
"""

from __future__ import annotations
from typing import Any, Callable, Dict, Optional

try:
    from PyQt6.QtCore import Qt, QTimer
    from PyQt6.QtWidgets import (
        QMainWindow,
        QWidget,
        QVBoxLayout,
        QHBoxLayout,
        QLabel,
        QFrame,
        QPushButton,
        QApplication,
    )
    from PyQt6.QtGui import QCloseEvent, QKeyEvent, QGuiApplication
    HAS_PYQT = True
except ImportError:
    HAS_PYQT = False

from core.interfaces import AgentState, ILockEnforcer, IStateObserver
from ui.theme import AgentTheme
from ui.active_break_widget import ActiveBreakWidget
from ui.parent_unlock_modal import ParentUnlockModal


class FocusLockOverlay(ILockEnforcer, IStateObserver):
    """
    Kapatılamayan Tam Ekran Kilit Arayüzü.
    ILockEnforcer & IStateObserver sözleşmelerini tam uygular (LSP).
    """

    def __init__(
        self,
        on_emergency_unlock: Optional[Callable[[], None]] = None,
        on_break_action: Optional[Callable[[str], None]] = None,
    ) -> None:
        self.on_emergency_unlock = on_emergency_unlock
        self.on_break_action = on_break_action

        self._window: Optional[Any] = None
        self._is_locked_state = False

        if HAS_PYQT:
            self._init_ui()

    def _init_ui(self) -> None:
        class UnclosableLockWindow(QMainWindow):
            def closeEvent(self, event: QCloseEvent) -> None:
                # Kapatma girişimini kesinlikle reddet (Anti-Kill / Anti-Close)
                event.ignore()

            def keyPressEvent(self, event: QKeyEvent) -> None:
                # Alt+F4 veya Esc ile kapatmayı engelle
                if event.key() in (Qt.Key.Key_Escape, Qt.Key.Key_F4):
                    event.ignore()
                else:
                    super().keyPressEvent(event)

        self._window = UnclosableLockWindow()
        self._window.setObjectName("LockOverlayRoot")
        self._window.setStyleSheet(AgentTheme.lock_overlay_stylesheet())

        # Tam ekran, çerçevesiz, her zaman en üstte
        self._window.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.BypassWindowManagerHint
        )

        # Ana Taşıyıcı
        center_widget = QWidget()
        center_layout = QVBoxLayout(center_widget)
        center_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        # Kart Kutusu
        card = QFrame()
        card.setObjectName("LockCenterCard")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(40, 36, 40, 36)
        card_layout.setSpacing(18)
        card_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        # Başlık ve İkon
        top_row = QHBoxLayout()
        icon_lbl = QLabel("🎯")
        icon_lbl.setStyleSheet("font-size: 38px;")
        top_row.addWidget(icon_lbl)

        self._title_lbl = QLabel("Ders ve Odak Zamanı")
        self._title_lbl.setStyleSheet(f"font-size: 24px; font-weight: 900; color: {AgentTheme.TEXT_WHITE};")
        top_row.addWidget(self._title_lbl)
        card_layout.addLayout(top_row)

        self._sub_lbl = QLabel("Ekran ders süresi boyunca kilitlidir. Dikkatini topla, kalkanlarını koru!")
        self._sub_lbl.setStyleSheet(f"font-size: 13px; color: {AgentTheme.TEXT_MUTED};")
        self._sub_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_layout.addWidget(self._sub_lbl)

        # Dev Sayaç (MM:SS)
        self._timer_lbl = QLabel("25:00")
        self._timer_lbl.setObjectName("TimerDisplay")
        self._timer_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_layout.addWidget(self._timer_lbl)

        # Kalkan Bilgisi
        self._shields_row = QLabel("🛡️ Günlük Kalkan: 3 / 3")
        self._shields_row.setStyleSheet(f"font-size: 13px; font-weight: bold; color: {AgentTheme.CYAN};")
        self._shields_row.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_layout.addWidget(self._shields_row)

        card_layout.addSpacing(10)

        # Aktif Mola Barı (Su İç, Camı Aç, Esne, Yürü)
        self._break_widget = ActiveBreakWidget(on_break_completed=self.on_break_action)
        break_ui = self._break_widget.build_widget()
        if break_ui:
            card_layout.addWidget(break_ui)

        card_layout.addSpacing(14)

        # Ebeveyn Acil Kilit Açma Butonu
        unlock_btn = QPushButton("🛡️ Ebeveyn Acil Kilit Çöz (Master PIN)")
        unlock_btn.setObjectName("EmergencyUnlockBtn")
        unlock_btn.clicked.connect(self._handle_emergency_unlock_click)
        card_layout.addWidget(unlock_btn)

        center_layout.addWidget(card)
        self._window.setCentralWidget(center_widget)

    def _handle_emergency_unlock_click(self) -> None:
        modal = ParentUnlockModal(on_unlock_success=self.on_emergency_unlock)
        modal.show_dialog(self._window)

    # --------------------------------------------------------------------------
    # ILockEnforcer IMPLEMENTATION
    # --------------------------------------------------------------------------
    def lock_screen(self, state: AgentState, duration_minutes: int, title: str) -> None:
        self._is_locked_state = True
        if not HAS_PYQT or not self._window:
            return

        if title:
            self._title_lbl.setText(title)

        mins = duration_minutes if duration_minutes > 0 else 25
        self._timer_lbl.setText(f"{mins:02d}:00")

        # Tüm monitör alanını kapla
        primary_screen = QGuiApplication.primaryScreen()
        if primary_screen:
            geo = primary_screen.geometry()
            self._window.setGeometry(geo)

        self._window.showFullScreen()
        self._window.raise_()
        self._window.activateWindow()

    def unlock_screen(self) -> None:
        self._is_locked_state = False
        if HAS_PYQT and self._window:
            self._window.hide()

    def is_locked(self) -> bool:
        return self._is_locked_state

    # --------------------------------------------------------------------------
    # IStateObserver IMPLEMENTATION
    # --------------------------------------------------------------------------
    def on_state_changed(self, new_state: AgentState, old_state: AgentState, metadata: Dict[str, Any]) -> None:
        shields = metadata.get("shields", 3)
        if HAS_PYQT and self._window:
            self._shields_row.setText(f"🛡️ Günlük Kalkan: {shields} / 3")

        if new_state in (AgentState.STUDY_TIME, AgentState.ROUTINE_TIME, AgentState.WAKE_UP_ALARM):
            rem_secs = metadata.get("remaining_seconds", 0)
            mins = rem_secs // 60 if rem_secs > 0 else 25
            task = metadata.get("task_title", "Ders & Odak Zamanı")
            self.lock_screen(new_state, mins, task)
        else:
            self.unlock_screen()

    def on_tick(self, remaining_seconds: int, total_seconds: int) -> None:
        if not HAS_PYQT or not self._window:
            return
        mins = remaining_seconds // 60
        secs = remaining_seconds % 60
        self._timer_lbl.setText(f"{mins:02d}:{secs:02d}")
