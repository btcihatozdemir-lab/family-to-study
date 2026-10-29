"""
===============================================================================
core/lingua_engine.py - GÜNÜN KELİMESİ / DEYİMİ VE KİLİT BULMACA MOTORU (SRP)
===============================================================================
Çok dilli (TR / EN / DE) etimolojik kelime havuzunu tutar.
Kilit ekranında 3 şıklı mini soru üretir; doğru bilinince puan/süre kazandırır.
===============================================================================
"""

from __future__ import annotations
import random
from typing import Dict, Any, List, Optional


class LinguaEngine:
    """Günün kelimesi ve mikro-öğrenme kilit bulmaca motoru."""

    # Çevrimdışı ve Hızlı Erişim İçin Zengin Kelime Havuzu
    WORDS_DB: Dict[str, List[Dict[str, Any]]] = {
        "tr": [
            {
                "word": "Serendipiti",
                "meaning": "Şans eseri değerli bir şeyi tesadüfen keşfetme yeteneği.",
                "etymology": "İngilizce Serendipity kelimesinden (Seylan Masalları).",
                "sentence": "Penisilinin keşfi tarihteki en büyük serendipiti örneğidir.",
                "question": "'Serendipiti' kelimesinin anlamı nedir?",
                "options": ["Tesadüfen güzel keşifler yapma", "Dersleri erteleme alışkanlığı", "Sürekli bilgisayar oynama"],
                "correct_index": 0
            },
            {
                "word": "Metanet",
                "meaning": "Zorluklar ve acılar karşısında dayanma, sarsılmama gücü.",
                "etymology": "Arapça 'mtn' kökünden sağlamlık, dayanıklılık.",
                "sentence": "Zorlu sınav döneminde gösterdiği metanet herkesi hayran bıraktı.",
                "question": "'Metanet' ne anlama gelir?",
                "options": ["Hemen pes etmek", "Zorluklara karşı dayanma gücü", "Çok hızlı koşmak"],
                "correct_index": 1
            },
            {
                "word": "Muvaffakiyet",
                "meaning": "Bir işte hedeflenen başarıya ulaşma, üstesinden gelme.",
                "etymology": "Arapça uygun bulma, başarı sağlama.",
                "sentence": "Planlı çalışma her zaman muvaffakiyet getirir.",
                "question": "'Muvaffakiyet' kelimesinin eş anlamlısı nedir?",
                "options": ["Başarı", "Tembellik", "Kararsızlık"],
                "correct_index": 0
            }
        ],
        "en": [
            {
                "word": "Resilience",
                "meaning": "The capacity to recover quickly from difficulties; toughness.",
                "etymology": "Latin 'resilire' (to leap back or rebound).",
                "sentence": "Her resilience helped her overcome the challenging math test.",
                "question": "What does 'Resilience' mean?",
                "options": ["Ability to bounce back from challenges", "Sleeping all day long", "Giving up immediately"],
                "correct_index": 0
            },
            {
                "word": "Perseverance",
                "meaning": "Persistence in doing something despite difficulty or delay.",
                "etymology": "Latin 'perseverantia' (steadfastness).",
                "sentence": "Through hard work and perseverance, he mastered coding.",
                "question": "What is 'Perseverance'?",
                "options": ["Quitting easily", "Steadfast persistence", "Watching videos"],
                "correct_index": 1
            }
        ],
        "de": [
            {
                "word": "Weggefährte",
                "meaning": "Eine Person, die jemanden auf einem Weg oder Lebensabschnitt begleitet.",
                "etymology": "Aus Weg und Gefährte (Fahren/Reisen).",
                "sentence": "Ein treuer Weggefährte unterstützt dich auch bei schweren Aufgaben.",
                "question": "Was bedeutet 'Weggefährte'?",
                "options": ["Ein treuer Lebensbegleiter", "Ein schneller Computer", "Ein strenger Lehrer"],
                "correct_index": 0
            }
        ]
    }

    @classmethod
    def get_word_of_the_day(cls, lang: str = "tr") -> Dict[str, Any]:
        """Günün kelimesini ve test sorusunu döner."""
        words = cls.WORDS_DB.get(lang, cls.WORDS_DB["tr"])
        # Günün tarihine göre deterministik veya rastgele seç
        import datetime
        day_of_year = datetime.datetime.now().timetuple().tm_yday
        return words[day_of_year % len(words)]

    @classmethod
    def verify_answer(cls, word_data: Dict[str, Any], selected_index: int) -> bool:
        """Kullanıcının cevabını doğrular."""
        return selected_index == word_data.get("correct_index", 0)
