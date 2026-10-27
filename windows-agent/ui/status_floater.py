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
from ui.theme import AgentTheme


class StatusFloater(IStateObserver):
    """
    Kullanıcıyı rahatsız etmeyen durum kapsülü.
    PyQt6 yüklüyse şık arayüzü çizer; değilse arka planda durum dinler.
    """

    def __init__(self, on_request_break: Optional[callable] = None) -> None:
        self._on_request_break = on_request_break
        self._widget: Optional[Any] = None

        if HAS_PYQT:
            self._init_ui()

    def _init_ui(self) -> None:
        self._widget = QWidget()
        self._widget.setObjectName("FloaterRoot")
        self._widget.setStyleSheet(AgentTheme.floater_stylesheet())

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
        self._layout.setSpacing(10)

        # Avatar & Seviye
        self._avatar_lbl = QLabel("🦁")
        self._avatar_lbl.setStyleSheet("font-size: 20px;")
        self._layout.addWidget(self._avatar_lbl)

        # Öğrenci Adı ve Durum
        info_col = QVBoxLayout()
        info_col.setSpacing(1)
        self._name_lbl = QLabel("Öğrenci")
        self._name_lbl.setStyleSheet(f"font-weight: 900; font-size: 12px; color: {AgentTheme.TEXT_WHITE};")
        self._status_lbl = QLabel("🟢 Serbest Zaman")
        self._status_lbl.setStyleSheet(f"font-size: 10px; color: {AgentTheme.EMERALD}; font-weight: bold;")
        info_col.addWidget(self._name_lbl)
        info_col.addWidget(self._status_lbl)
        self._layout.addLayout(info_col)

        # Altın Puan Hapı
        self._points_lbl = QLabel("🪙 0")
        self._points_lbl.setStyleSheet(
            f"background-color: {AgentTheme.BG_ELEVATED}; "
            f"border-radius: 10px; padding: 3px 8px; font-size: 11px; "
            f"font-weight: 900; color: {AgentTheme.GOLD};"
        )
        self._layout.addWidget(self._points_lbl)

        # Kalkanlar
        self._shields_lbl = QLabel("🛡️🛡️🛡️")
        self._shields_lbl.setStyleSheet("font-size: 12px;")
        self._layout.addWidget(self._shields_lbl)

        # Konumlandırma: Sağ üst köşeye yakın (Odak çalmadan)
        screen = QApplication.primaryScreen()
        if screen:
            geo = screen.availableGeometry()
            self._widget.move(geo.width() - 280, 24)
        self._widget.setFixedSize(260, 44)

    # --------------------------------------------------------------------------
    # IStateObserver IMPLEMENTATION
    # --------------------------------------------------------------------------
    def on_state_changed(self, new_state: AgentState, old_state: AgentState, metadata: Dict[str, Any]) -> None:
        name = metadata.get("name", "Öğrenci")
        points = metadata.get("points", 0)
        shields = metadata.get("shields", 3)

        if not HAS_PYQT or not self._widget:
            return

        self._name_lbl.setText(name)
        self._points_lbl.setText(f"🪙 {points}")
        self._shields_lbl.setText("🛡️" * max(0, min(3, shields)))

        if new_state == AgentState.FREE_TIME:
            self._status_lbl.setText("🟢 Serbest Zaman")
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
