"""
===============================================================================
core/time_vault.py - AİLE İÇİ ZAMAN BANKASI VE TASARRUF MOTORU (SRP)
===============================================================================
Hafta içi kullanılmayan serbest zaman dakikalarını tasarruf eder,
hafta sonuna veya acil durumlara bakiye olarak devreder.
===============================================================================
"""

from __future__ import annotations
import json
import os
from typing import Dict, Any


class TimeVaultManager:
    """Zaman bankası yerel bakiye yöneticisi."""
    
    def __init__(self, cache_file: str = "time_vault_cache.json") -> None:
        self.cache_file = cache_file
        self._data: Dict[str, Any] = {
            "saved_minutes": 30,
            "borrowed_minutes": 0,
            "last_deposit_date": None,
        }
        self._load()

    def _load(self) -> None:
        if os.path.exists(self.cache_file):
            try:
                with open(self.cache_file, "r", encoding="utf-8") as f:
                    self._data.update(json.load(f))
            except Exception:
                pass

    def _save(self) -> None:
        try:
            with open(self.cache_file, "w", encoding="utf-8") as f:
                json.dump(self._data, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    @property
    def saved_minutes(self) -> int:
        return self._data.get("saved_minutes", 0)

    def deposit_minutes(self, minutes: int) -> int:
        """Kullanılmayan dakikayı bankaya ekler."""
        if minutes > 0:
            self._data["saved_minutes"] = self.saved_minutes + minutes
            self._save()
        return self.saved_minutes

    def withdraw_minutes(self, minutes: int) -> bool:
        """Bankadan dakika çeker."""
        if 0 < minutes <= self.saved_minutes:
            self._data["saved_minutes"] = self.saved_minutes - minutes
            self._save()
            return True
        return False

    def sync_from_remote(self, saved_minutes: int, borrowed_minutes: int = 0) -> None:
        self._data["saved_minutes"] = max(0, saved_minutes)
        self._data["borrowed_minutes"] = max(0, borrowed_minutes)
        self._save()
