"""
===============================================================================
ui/active_break_widget.py - AKTİF MOLA VE SAĞLIK KONTROLLERİ (SRP)
===============================================================================
Kids uygulamasıyla birebir aynı 4 Aktif Mola aracı:
1) 💧 Su İç (Hidrasyon)
2) 🪟 Camı Aç / Oksijen Al (Taze Hava)
3) 🧘 20-20-20 Göz & Boyun Esnemesi
4) 🚶 2 Dk Hareket Et / Yürü
===============================================================================
"""

from __future__ import annotations
from typing import Any, Callable, Dict, List, Optional

try:
    from PyQt6.QtCore import Qt, pyqtSignal
    from PyQt6.QtWidgets import (
        QWidget,
        QHBoxLayout,
        QVBoxLayout,
        QLabel,
        QFrame,
        QPushButton,
    )
    HAS_PYQT = True
except ImportError:
    HAS_PYQT = False

from ui.theme import AgentTheme


class ActiveBreakWidget:
    """Aktif Mola ve Canlandırıcı Sağlık Paneli."""

    BREAK_ITEMS = [
        {"icon": "💧", "title": "Su İç", "sub": "1 Bardak Su", "color": AgentTheme.CYAN},
        {"icon": "🪟", "title": "Camı Aç", "sub": "Taze Oksijen Al", "color": AgentTheme.EMERALD},
        {"icon": "🧘", "title": "20-20-20", "sub": "Gözünü Dinlendir", "color": AgentTheme.PURPLE},
        {"icon": "🚶", "title": "Hareket Et", "sub": "Ayağa Kalk & Esne", "color": AgentTheme.GOLD},
    ]

    def __init__(self, on_break_completed: Optional[Callable[[str], None]] = None) -> None:
        self.on_break_completed = on_break_completed
        self._container: Optional[Any] = None

    def build_widget(self) -> Any:
        if not HAS_PYQT:
            return None

        self._container = QFrame()
        layout = QHBoxLayout(self._container)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        for item in self.BREAK_ITEMS:
            card = self._create_card(item)
            layout.addWidget(card)

        return self._container

    def _create_card(self, item: Dict[str, str]) -> Any:
        card = QFrame()
        card.setObjectName("BreakCard")
        card.setStyleSheet(AgentTheme.break_card_stylesheet(item["color"]))
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(14, 12, 14, 12)
        card_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        icon_lbl = QLabel(item["icon"])
        icon_lbl.setStyleSheet("font-size: 28px;")
        icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)

        title_lbl = QLabel(item["title"])
        title_lbl.setStyleSheet(f"font-weight: 900; font-size: 13px; color: {item['color']};")
        title_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)

        sub_lbl = QLabel(item["sub"])
        sub_lbl.setStyleSheet(f"font-size: 10px; color: {AgentTheme.TEXT_MUTED};")
        sub_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)

        btn = QPushButton("Tamamla ✨")
        btn.setStyleSheet(
            f"background-color: {item['color']}25; color: {item['color']}; "
            f"border: 1px solid {item['color']}60; border-radius: 8px; "
            f"padding: 4px 8px; font-size: 10px; font-weight: bold;"
        )
        btn.clicked.connect(lambda _, t=item["title"]: self._handle_complete(t))

        card_layout.addWidget(icon_lbl)
        card_layout.addWidget(title_lbl)
        card_layout.addWidget(sub_lbl)
        card_layout.addSpacing(4)
        card_layout.addWidget(btn)

        return card

    def _handle_complete(self, title: str) -> None:
        if self.on_break_completed:
            self.on_break_completed(title)
