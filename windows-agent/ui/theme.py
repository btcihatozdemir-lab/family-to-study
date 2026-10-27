"""
===============================================================================
ui/theme.py - MODERN CYBERPUNK / COSMIC DARK TEMA VE STİLLERİ
===============================================================================
Kids uygulamasıyla %100 görsel uyum sağlayan renk paleti ve QSS stilleri.
===============================================================================
"""

from __future__ import annotations


class AgentTheme:
    """Modern Cosmic Dark Renk Paleti"""
    BG_MIDNIGHT = "#0A0F1D"
    BG_SURFACE = "#151D33"
    BG_ELEVATED = "#1E294B"

    # Vurgu Renkleri
    PRIMARY = "#6366F1"        # Kozmik İndigo
    PRIMARY_LIGHT = "#818CF8"
    CYAN = "#38BDF8"           # Gökyüzü Mavisi / Odak
    EMERALD = "#10B981"        # Canlı / Serbest Zaman / Su
    GOLD = "#F59E0B"           # Altın Puan & Hazine
    GOLD_LIGHT = "#FBBF24"
    ROSE = "#F43F5E"           # Alarm / İhlal / Kilit
    PURPLE = "#8B5CF6"         # Büyülü Gece

    # Metin Renkleri
    TEXT_WHITE = "#FFFFFF"
    TEXT_MUTED = "#94A3B8"
    TEXT_DIM = "#64748B"

    @classmethod
    def floater_stylesheet(cls) -> str:
        return f"""
        QWidget#FloaterRoot {{
            background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 {cls.BG_SURFACE}, stop:1 {cls.BG_MIDNIGHT});
            border: 1.5px solid {cls.PRIMARY}40;
            border-radius: 18px;
        }}
        QLabel {{
            color: {cls.TEXT_WHITE};
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
        }}
        """

    @classmethod
    def lock_overlay_stylesheet(cls) -> str:
        return f"""
        QWidget#LockOverlayRoot {{
            background-color: {cls.BG_MIDNIGHT};
        }}
        QFrame#LockCenterCard {{
            background-color: {cls.BG_SURFACE};
            border: 2px solid {cls.PRIMARY}60;
            border-radius: 28px;
        }}
        QLabel#TimerDisplay {{
            color: {cls.TEXT_WHITE};
            font-size: 72px;
            font-weight: 900;
            font-family: 'Consolas', 'Segoe UI', monospace;
            letter-spacing: 4px;
        }}
        QPushButton#EmergencyUnlockBtn {{
            background-color: {cls.BG_ELEVATED};
            color: {cls.TEXT_MUTED};
            border: 1px solid {cls.PRIMARY}40;
            border-radius: 12px;
            padding: 8px 16px;
            font-weight: bold;
            font-size: 12px;
        }}
        QPushButton#EmergencyUnlockBtn:hover {{
            color: {cls.TEXT_WHITE};
            border-color: {cls.GOLD};
        }}
        """

    @classmethod
    def break_card_stylesheet(cls, color_hex: str) -> str:
        return f"""
        QFrame#BreakCard {{
            background-color: {cls.BG_ELEVATED};
            border: 1.5px solid {color_hex}40;
            border-radius: 16px;
        }}
        QFrame#BreakCard:hover {{
            border-color: {color_hex};
            background-color: {color_hex}15;
        }}
        """
