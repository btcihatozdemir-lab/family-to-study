import os
import json
import locale
from typing import Dict, Any, List

class I18n:
    _current_lang: str = "tr"
    _translations: Dict[str, Dict[str, Any]] = {}
    _is_initialized: bool = False

    @classmethod
    def init(cls, force_lang: str = None) -> None:
        """Dil sözlüklerini yükler ve aktif dili belirler."""
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        locales_dir = os.path.join(base_dir, "locales")

        # 1. Desteklenen dilleri yükle (tr, en, de)
        for lang in ["tr", "en", "de"]:
            filepath = os.path.join(locales_dir, f"{lang}.json")
            if os.path.exists(filepath):
                try:
                    with open(filepath, "r", encoding="utf-8") as f:
                        cls._translations[lang] = json.load(f)
                except Exception as e:
                    print(f"[I18n] {lang}.json yükleme hatası: {e}")
                    cls._translations[lang] = {}

        # 2. Aktif dili belirle
        if force_lang and force_lang in cls._translations:
            cls._current_lang = force_lang
        else:
            cls._current_lang = cls._detect_system_language()

        cls._is_initialized = True
        print(f"[I18n] Aktif Dil: {cls._current_lang.upper()}")

    @classmethod
    def _detect_system_language(cls) -> str:
        """Sistem dilini tespit eder (tr, en, de)."""
        try:
            # Ortam değişkeni veya sistem varsayılan dili
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

        # Fallback: Türkçe veya İngilizce
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
