"""
===============================================================================
core/subject_tracker.py - DERS & BRANŞ ÇALIŞMA VE METRİK TAKİP MOTORU (SRP)
===============================================================================
Masaüstü ortamında öğrencinin çalıştığı dersi (Matematik, Türkçe, İngilizce, Fen)
takip eder; süre, soru, net, kitap sayfası ve kelime/deyim kazanımlarını kaydeder.
Supabase 'log_subject_activity' RPC'si ile bulut veritabanına aktarır.
===============================================================================
"""

from __future__ import annotations
import time
from typing import Dict, Any, Optional


class SubjectStudyTracker:
    """Masaüstü ajanında branş bazlı ders oturumlarını ve akademik metrikleri yönetir."""

    VALID_SUBJECTS = ("matematik", "turkce", "ingilizce", "fen", "sosyal", "lgs_genel")

    def __init__(self, default_subject: str = "matematik") -> None:
        self.active_subject: str = default_subject.lower() if default_subject.lower() in self.VALID_SUBJECTS else "matematik"
        self._session_start_time: Optional[float] = None
        self.questions_solved: int = 0
        self.correct_count: int = 0
        self.wrong_count: int = 0
        self.pages_read: int = 0
        self.words_learned: int = 0
        self.idioms_learned: int = 0
        self.total_duration_minutes: int = 0

    def set_subject(self, subject: str) -> None:
        """Aktif çalışma branşını değiştirir."""
        sub = subject.lower().strip()
        if sub in self.VALID_SUBJECTS:
            self.active_subject = sub

    def start_session(self) -> None:
        """Ders modu çalışma kronometresini başlatır."""
        self._session_start_time = time.time()

    def end_session(self) -> int:
        """Ders modunu sonlandırır ve geçen süreyi (dakika) ekler."""
        if self._session_start_time is None:
            return 0
        elapsed_seconds = time.time() - self._session_start_time
        elapsed_minutes = max(1, int(elapsed_seconds / 60))
        self.total_duration_minutes += elapsed_minutes
        self._session_start_time = None
        return elapsed_minutes

    def record_math_score(self, questions: int, correct: int, wrong: int) -> float:
        """Matematik / Fen için soru, doğru, yanlış ekler ve neti döner."""
        self.questions_solved += max(0, questions)
        self.correct_count += max(0, correct)
        self.wrong_count += max(0, wrong)
        return self.calculate_net()

    def record_turkish_reading(self, pages: int, idioms: int = 0, words: int = 0) -> None:
        """Türkçe için okunan kitap sayfası ve öğrenilen deyim/kelimeleri ekler."""
        self.pages_read += max(0, pages)
        self.idioms_learned += max(0, idioms)
        self.words_learned += max(0, words)

    def record_english_vocab(self, words: int, questions: int = 0) -> None:
        """İngilizce için yeni kelime haznesi ve soru sayısını ekler."""
        self.words_learned += max(0, words)
        self.questions_solved += max(0, questions)

    def calculate_net(self) -> float:
        """LGS 3 Yanlış 1 Doğru kuralına göre net hesaplar."""
        net = self.correct_count - (self.wrong_count / 3.0)
        return round(max(0.0, net), 2)

    def get_summary(self) -> Dict[str, Any]:
        """Aktif oturum metrik özetini döner."""
        return {
            "subject": self.active_subject,
            "questions_solved": self.questions_solved,
            "correct_count": self.correct_count,
            "wrong_count": self.wrong_count,
            "net_score": self.calculate_net(),
            "pages_read": self.pages_read,
            "words_learned": self.words_learned,
            "idioms_learned": self.idioms_learned,
            "duration_minutes": self.total_duration_minutes,
        }

    def sync_to_supabase(self, client: Any, student_user_id: str, family_id: str) -> bool:
        """Buluta 'log_subject_activity' RPC'si ile aktarır."""
        if not client or not student_user_id or not family_id:
            return False
        try:
            params = {
                "p_student_user_id": student_user_id,
                "p_family_id": family_id,
                "p_subject": self.active_subject,
                "p_questions": self.questions_solved,
                "p_correct": self.correct_count,
                "p_wrong": self.wrong_count,
                "p_pages_read": self.pages_read,
                "p_words_learned": self.words_learned,
                "p_idioms_learned": self.idioms_learned,
                "p_duration_minutes": self.total_duration_minutes,
            }
            res = client.rpc("log_subject_activity", params).execute()
            return res.data is not None and res.data.get("success") is True
        except Exception as e:
            print(f"[SubjectStudyTracker] Senkronizasyon hatası: {e}")
            return False
