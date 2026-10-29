import os
import sys
import json
import locale
from typing import Dict, Any, List

# .EXE İçinde Dosyalar Silinse Bile Patlamayan Gömülü Fallback Sözlükleri
EMBEDDED_FALLBACKS: Dict[str, Dict[str, Any]] = {
    "tr": {
        "focus_mode": "Odaklanma Saati",
        "break_time": "Mola Vakti",
        "free_time": "Serbest Zaman",
        "wake_up_alarm": "Uyanma Vakti",
        "active_break": "Aktif Mola",
        "study_mode_active": "Ders Saati Aktif! Ekran Kilitlendi.",
        "shield_desc": "Kalkanını korumak için dersine odaklan.",
        "unlock_with_pin": "🛡️ Ebeveyn Master PIN ile Kilit Aç",
        "coins": "Altın",
        "shield": "Kalkan",
        "streak_days": "{days} Gün Seri"
    },
    "en": {
        "focus_mode": "Study & Focus Mode",
        "break_time": "Break Time",
        "free_time": "Free Time",
        "wake_up_alarm": "Wake Up Alarm",
        "active_break": "Active Break",
        "study_mode_active": "Study Mode Active! Screen Locked.",
        "shield_desc": "Focus on your tasks to maintain your shield.",
        "unlock_with_pin": "🛡️ Unlock with Parent Master PIN",
        "coins": "Gold Coins",
        "shield": "Shield",
        "streak_days": "{days} Day Streak"
    },
    "de": {
        "focus_mode": "Lern- & Fokuszeit",
        "break_time": "Pause",
        "free_time": "Freizeit",
        "wake_up_alarm": "Aufwach-Alarm",
        "active_break": "Aktive Pause",
        "study_mode_active": "Lernmodus aktiv! Bildschirm gesperrt.",
        "shield_desc": "Konzentriere dich, um dein Schutzschild zu bewahren.",
        "unlock_with_pin": "🛡️ Mit Eltern-Master-PIN entsperren",
        "coins": "Goldmünzen",
        "shield": "Schutzschild",
        "streak_days": "{days} Tage Serie"
    }
}

class I18n:
    _current_lang: str = "tr"
    _translations: Dict[str, Dict[str, Any]] = {}
    _is_initialized: bool = False

    @classmethod
    def init(cls, force_lang: str = None) -> None:
        """Dil sözlüklerini yükler ve aktif dili belirler (.EXE ve script uyumlu)."""
        # PyInstaller .EXE (sys._MEIPASS) veya geliştirici ortamı tespiti
        if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
            base_dir = getattr(sys, "_MEIPASS")
        else:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

        locales_dir = os.path.join(base_dir, "locales")

        # 1. Desteklenen dilleri yükle (tr, en, de)
        for lang in ["tr", "en", "de"]:
            cls._translations[lang] = dict(EMBEDDED_FALLBACKS.get(lang, {}))
            filepath = os.path.join(locales_dir, f"{lang}.json")
            if os.path.exists(filepath):
                try:
                    with open(filepath, "r", encoding="utf-8") as f:
                        file_dict = json.load(f)
                        cls._translations[lang].update(file_dict)
                except Exception as e:
                    print(f"[I18n] {lang}.json okuma uyarısı: {e}")

        # 2. Aktif dili belirle
        if force_lang and force_lang in cls._translations:
            cls._current_lang = force_lang
        else:
            cls._current_lang = cls._detect_system_language()

        cls._is_initialized = True
        print(f"[I18n] Aktif Dil: {cls._current_lang.upper()} (.EXE Uyumluluğu Aktif)")

    @classmethod
    def _detect_system_language(cls) -> str:
        """Windows sistem dilini otomatik tespit eder."""
        try:
            lang_env = os.environ.get("LANG", "") or os.environ.get("LANGUAGE", "")
            if not lang_env:
                default_locale, _ = locale.getdefaultlocale()
                lang_env = default_locale or ""

            lang_env = lang_env.lower()
            if "de" in lang_env:
                return "de"
            elif "en" in lang_env:
                return "en"
            else:
                return "tr"
        except Exception:
            return "tr"

    @classmethod
    def set_language(cls, lang: str) -> None:
        if lang in cls._translations:
            cls._current_lang = lang

    @classmethod
    def get_language(cls) -> str:
        return cls._current_lang

    @classmethod
    def t(cls, key: str, **kwargs) -> Any:
        """Anahtara ait çeviriyi döner. Format değişkenleri kwargs ile verilebilir."""
        if not cls._is_initialized:
            cls.init()

        lang_dict = cls._translations.get(cls._current_lang, {})
        val = lang_dict.get(key)

        # Fallback zinciri: Seçili Dil -> İngilizce -> Türkçe -> Doğrudan Key
        if val is None:
            val = cls._translations.get("en", {}).get(key)
        if val is None:
            val = cls._translations.get("tr", {}).get(key, key)

        if isinstance(val, str) and kwargs:
            try:
                return val.format(**kwargs)
            except Exception:
                return val
        return val


def t(key: str, **kwargs) -> Any:
    return I18n.t(key, **kwargs)
