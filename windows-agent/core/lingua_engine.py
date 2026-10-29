"""
===============================================================================
core/lingua_engine.py - GÜNÜN KELİMESİ / DEYİMİ VE KİLİT BULMACA MOTORU (SRP)
===============================================================================
Çok dilli (TR / EN / DE) etimolojik kelime ve Türkçe Deyim/Atasözü havuzunu tutar.
Türkçe ve İngilizce öğretmenlerinin beklediği kelime & deyim tahlillerini üretir.
===============================================================================
"""

from __future__ import annotations
import random
from typing import Dict, Any, List, Optional


class LinguaEngine:
    """Günün kelimesi, deyimi ve mikro-öğrenme kilit bulmaca motoru."""

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
            },
            {
                "word": "Curiosity",
                "meaning": "A strong desire to know or learn something new.",
                "etymology": "Latin 'curiositas' from cura (care).",
                "sentence": "Scientific discoveries begin with boundless curiosity.",
                "question": "What is the meaning of 'Curiosity'?",
                "options": ["Desire to learn new things", "Being lazy", "Ignoring homework"],
                "correct_index": 0
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

    # Türkçe Öğretmenlerinin İstediği Deyimler & Atasözleri Havuzu
    IDIOMS_DB: List[Dict[str, Any]] = [
        {
            "idiom": "Pireyi deve yapmak",
            "meaning": "Önemsiz, küçük bir olayı aşırı büyütüp mesele haline getirmek.",
            "type": "deyim",
            "sentence": "Sadece bir soruyu yanlış yaptı diye pireyi deve yapmaya gerek yok.",
            "question": "'Pireyi deve yapmak' deyiminin anlamı nedir?",
            "options": ["Küçük bir şeyi çok büyütmek", "Çok ucuza alışveriş yapmak", "Hayvanları çok sevmek"],
            "correct_index": 0
        },
        {
            "idiom": "Damlaya damlaya göl olur",
            "meaning": "Küçük birikimler zamanla birleşerek büyük kazanç veya başarı haline gelir.",
            "type": "atasozu",
            "sentence": "Her gün çözdüğün 20 soru damlaya damlaya göl olur, LGS'de derece getirir.",
            "question": "'Damlaya damlaya göl olur' atasözü neyi vurgular?",
            "options": ["Sabır ve düzenli birikimin gücünü", "Yağmurlu günlerde dışarı çıkmamayı", "Suyu boşa akıtmamayı"],
            "correct_index": 0
        },
        {
            "idiom": "Ağaç yaşken eğilir",
            "meaning": "İnsanlar küçük yaşlarda daha kolay eğitilir ve güzel alışkanlıklar kazanır.",
            "type": "atasozu",
            "sentence": "Kitap okuma alışkanlığı için ağaç yaşken eğilir ilkesi geçerlidir.",
            "question": "'Ağaç yaşken eğilir' sözü ne anlama gelir?",
            "options": ["Eğitimin küçük yaşta başlaması gerektiğini", "Ağaç dikmenin önemini", "Ormanları korumayı"],
            "correct_index": 0
        },
        {
            "idiom": "Göz boyamak",
            "meaning": "Bir şeyi aslında olduğundan daha iyi veya kusursuz göstermeye çalışmak, aldatmak.",
            "type": "deyim",
            "sentence": "Ödevini özenle yapmalı, sadece göz boyamak için karalamamalısın.",
            "question": "'Göz boyamak' ne demektir?",
            "options": ["Bir şeyi iyiymiş gibi gösterip kandırmak", "Resim dersinde göz çizmek", "Gözlük takmak"],
            "correct_index": 0
        }
    ]

    @classmethod
    def get_word_of_the_day(cls, lang: str = "tr") -> Dict[str, Any]:
        """Günün kelimesini ve test sorusunu döner."""
        words = cls.WORDS_DB.get(lang, cls.WORDS_DB["tr"])
        import datetime
        day_of_year = datetime.datetime.now().timetuple().tm_yday
        return words[day_of_year % len(words)]

    @classmethod
    def get_idiom_of_the_day(cls) -> Dict[str, Any]:
        """Günün Deyimini / Atasözünü ve sorusunu döner."""
        import datetime
        day_of_year = datetime.datetime.now().timetuple().tm_yday
        return cls.IDIOMS_DB[day_of_year % len(cls.IDIOMS_DB)]

    @classmethod
    def verify_answer(cls, word_data: Dict[str, Any], selected_index: int) -> bool:
        """Kullanıcının cevabını doğrular."""
        return selected_index == word_data.get("correct_index", 0)
