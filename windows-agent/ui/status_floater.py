"""
===============================================================================
ui/status_floater.py - KULLANICIYI RAHATSIZ ETMEYEN SERBEST ZAMAN KAPSÜLÜ (SRP)
===============================================================================
Öğrenci serbest zamandayken (FREE_TIME) ekranı veya oyunları asla bölmez.
Sağ köşede duran, yarı saydam, odak çalmayan (non-intrusive) modern durum rozeti.
===============================================================================
"""

from __future__ import annotations
from typing import Any, Dict, Optional

try:
    from PyQt6.QtCore import Qt, QPoint, pyqtSignal, QObject
    from PyQt6.QtWidgets import (
        QWidget,
        QHBoxLayout,
        QVBoxLayout,
        QLabel,
        QFrame,
        QPushButton,
        QApplication,
    )
    from PyQt6.QtGui import QMouseEvent, QCursor
    HAS_PYQT = True
except ImportError:
    HAS_PYQT = False

from core.interfaces import AgentState, IStateObserver
from core.i18n import t
from ui.theme import AgentTheme


class StatusFloater(IStateObserver):
    """
    Kullanıcıyı rahatsız etmeyen, sürüklenebilir modern durum kapsülü.
    PyQt6 yüklüyse şık arayüzü çizer; değilse arka planda durum dinler.
    """

    def __init__(self, on_request_break: Optional[callable] = None) -> None:
        self._on_request_break = on_request_break
        self._widget: Optional[Any] = None
        self._drag_pos = None

        if HAS_PYQT:
            self._init_ui()

    def _init_ui(self) -> None:
        class DraggableCapsule(QWidget):
            def __init__(parent_self, outer_floater):
                super().__init__()
                parent_self.outer = outer_floater

            def mousePressEvent(parent_self, event: QMouseEvent):
                if event.button() == Qt.MouseButton.LeftButton:
                    parent_self.outer._drag_pos = event.globalPosition().toPoint() - parent_self.frameGeometry().topLeft()
                    event.accept()

            def mouseMoveEvent(parent_self, event: QMouseEvent):
                if parent_self.outer._drag_pos is not None and event.buttons() == Qt.MouseButton.LeftButton:
                    parent_self.move(event.globalPosition().toPoint() - parent_self.outer._drag_pos)
                    event.accept()

            def mouseReleaseEvent(parent_self, event: QMouseEvent):
                parent_self.outer._drag_pos = None

        self._widget = DraggableCapsule(self)
        self._widget.setObjectName("FloaterRoot")
        self._widget.setStyleSheet(AgentTheme.floater_stylesheet())
        self._widget.setToolTip("FamilyOS Öğrenci Durum Kapsülü (Sürükleyebilirsiniz)")

        # Çerçevesiz, her zaman üstte ve odak çalmayan pencere bayrakları
        self._widget.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self._widget.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self._widget.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)

        self._layout = QHBoxLayout(self._widget)
        self._layout.setContentsMargins(12, 6, 12, 6)
        self._layout.setSpacing(8)

        # 1. Avatar & Canlı İfade
        self._avatar_lbl = QLabel("🦁")
        self._avatar_lbl.setStyleSheet("font-size: 20px;")
        self._layout.addWidget(self._avatar_lbl)

        # 2. Öğrenci Adı ve Durum
        info_col = QVBoxLayout()
        info_col.setSpacing(1)
        self._name_lbl = QLabel("Öğrenci")
        self._name_lbl.setStyleSheet(f"font-weight: 900; font-size: 11px; color: {AgentTheme.TEXT_WHITE};")
        self._status_lbl = QLabel("🟢 Serbest Zaman")
        self._status_lbl.setStyleSheet(f"font-size: 10px; color: {AgentTheme.EMERALD}; font-weight: bold;")
        info_col.addWidget(self._name_lbl)
        info_col.addWidget(self._status_lbl)
        self._layout.addLayout(info_col)

        # 3. Altın Puan Hapı
        self._points_lbl = QLabel("🪙 0")
        self._points_lbl.setStyleSheet(
            f"background-color: {AgentTheme.BG_ELEVATED}; "
            f"border-radius: 9px; padding: 2px 7px; font-size: 11px; "
            f"font-weight: 900; color: {AgentTheme.GOLD}; border: 1px solid {AgentTheme.GOLD}40;"
        )
        self._layout.addWidget(self._points_lbl)

        # 4. Seri Ateşi (Streak)
        self._streak_lbl = QLabel("🔥 1g")
        self._streak_lbl.setStyleSheet(
            f"background-color: {AgentTheme.BG_ELEVATED}; "
            f"border-radius: 9px; padding: 2px 6px; font-size: 10px; "
            f"font-weight: 900; color: #FB923C; border: 1px solid #FB923C40;"
        )
        self._layout.addWidget(self._streak_lbl)

        # 5. Kalkanlar
        self._shields_lbl = QLabel("🛡️🛡️🛡️")
        self._shields_lbl.setStyleSheet("font-size: 11px;")
        self._layout.addWidget(self._shields_lbl)

        # 6. Zaman Bankası (Vault)
        self._vault_lbl = QLabel("🏦 30dk")
        self._vault_lbl.setToolTip("Zaman Bankası Tasarrufunuz")
        self._vault_lbl.setStyleSheet(
            f"background-color: {AgentTheme.BG_ELEVATED}; "
            f"border-radius: 9px; padding: 2px 6px; font-size: 10px; "
            f"font-weight: 900; color: {AgentTheme.CYAN}; border: 1px solid {AgentTheme.CYAN}40;"
        )
        self._layout.addWidget(self._vault_lbl)

        # Konumlandırma: Sağ üst köşeye yakın (Odak çalmadan)
        screen = QApplication.primaryScreen()
        if screen:
            geo = screen.availableGeometry()
            self._widget.move(geo.width() - 380, 24)
        self._widget.setFixedSize(365, 46)

    # --------------------------------------------------------------------------
    # IStateObserver IMPLEMENTATION
    # --------------------------------------------------------------------------
    def on_state_changed(self, new_state: AgentState, old_state: AgentState, metadata: Dict[str, Any]) -> None:
        name = metadata.get("name", "Öğrenci")
        points = metadata.get("points", 0)
        shields = metadata.get("shields", 3)
        streak = metadata.get("streak", 1)
        vault_mins = metadata.get("saved_minutes", 30)

        if not HAS_PYQT or not self._widget:
            return

        self._name_lbl.setText(name)
        self._points_lbl.setText(f"🪙 {points}")
        self._streak_lbl.setText(f"🔥 {streak}g")
        self._shields_lbl.setText("🛡️" * max(0, min(3, shields)))
        self._vault_lbl.setText(f"🏦 {vault_mins}dk")

        if new_state == AgentState.FREE_TIME:
            self._status_lbl.setText(f"🟢 {t('free_time')}")
            self._status_lbl.setStyleSheet(f"font-size: 10px; color: {AgentTheme.EMERALD}; font-weight: bold;")
            self._widget.show()
        else:
            # Ders ve kilit modundayken tam ekran kilit devralacağı için floater gizlenir
            self._widget.hide()

    def on_tick(self, remaining_seconds: int, total_seconds: int) -> None:
        pass

    def show(self) -> None:
        if self._widget:
            self._widget.show()

    def hide(self) -> None:
        if self._widget:
            self._widget.hide()
