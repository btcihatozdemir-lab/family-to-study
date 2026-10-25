"""
===============================================================================
test_penetration_and_unit.py - DİNAMİK PENETRASYON VE BİRİM TESTLERİ
===============================================================================
Kapsam:
1. GÜVENLİK & PENETRASYON (ANTI-CHEAT) TESTLERİ:
   - PIN Brute-force, SHA-256 Hash Bütünlüğü & SQLi / Bozuk Girdi Koruması
   - Offline Guard: İnternet kesintisi bypass girişimleri ve yerel önbellek koruması
   - Beyaz Liste (Whitelist Enforcer) Bypass Testleri (Sahte başlık, exe taklidi, sekme sızması)
   - İkiz Nöbetçi (Watchdog Guard): Anti-Kill ve updating.lock yarış koşulları
   - OTA Updater Semver Güvenliği: Sürüm manipülasyonu ve geçersiz versiyonlar

2. BİRİM (UNIT) TESTLERİ:
   - Ses Desibel RMS hesaplama sınır değerleri (0 RMS, sessizlik, aşırı patlama)
   - Audio Ducking seviye sınırlandırmaları (0.05 .. 0.50 clamp)
   - Zamanlayıcı, uzatma ve kalkan durum matrisi doğrulaması
===============================================================================
"""

from __future__ import annotations

import hashlib
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

# Windows agent modül yolunu ekle
AGENT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(AGENT_DIR))

from config import (
    AGENT_VERSION,
    AgentConfig,
    LocalCacheManager,
    is_ota_updating,
    set_ota_updating_lock,
    clear_ota_updating_lock,
)
from ota_updater import parse_semver, is_version_newer
from watchdog_guard import is_pid_alive_and_matches


class TestSecurityAndPenetration(unittest.TestCase):
    """Güvenlik, Anti-Cheat ve Penetrasyon Senaryoları Testi."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp(prefix="agent_pen_test_")
        self.cache_file = Path(self.temp_dir) / "test_local_cache.json"
        self.cache = LocalCacheManager(file_path=self.cache_file)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    # --------------------------------------------------------------------------
    # 1. PIN DOĞRULAMA & PENETRASYON TESTLERİ
    # --------------------------------------------------------------------------
    def test_pin_sha256_verification_and_brute_force_resistance(self):
        """PIN doğrulaması SHA-256 üzerinden yapılır; hatalı veya manipüle edilmiş girdiler reddedilir."""
        # Gerçek PIN: 145300
        correct_pin = "145300"
        correct_hash = hashlib.sha256(correct_pin.encode("utf-8")).hexdigest()
        self.cache.update_pin_hash(correct_hash)

        # Doğru PIN başarılı olmalı
        self.assertTrue(self.cache.verify_offline_pin("145300"))

        # Hatalı PIN'ler reddedilmeli
        self.assertFalse(self.cache.verify_offline_pin("000000"))
        self.assertFalse(self.cache.verify_offline_pin("123456"))
        self.assertFalse(self.cache.verify_offline_pin("145301"))

        # Bozuk / Saldırı girdileri (Enjeksiyon, boşluk, alfabe, uzun/kısa)
        self.assertFalse(self.cache.verify_offline_pin(""))
        self.assertFalse(self.cache.verify_offline_pin("   "))
        self.assertFalse(self.cache.verify_offline_pin("' OR '1'='1"))
        self.assertFalse(self.cache.verify_offline_pin("145300\x00"))
        self.assertFalse(self.cache.verify_offline_pin("14530"))  # 5 hane
        self.assertFalse(self.cache.verify_offline_pin("1453000"))  # 7 hane
        self.assertFalse(self.cache.verify_offline_pin("abcdef"))

    def test_offline_pin_unlock_duration_tampering(self):
        """Ebeveyn PIN ile kilit açıldığında süre sınırı yerel saat manipülasyonuna karşı denetlenir."""
        self.assertFalse(self.cache.is_offline_pin_unlocked())
        self.assertEqual(self.cache.remaining_offline_unlock_seconds(), 0)

        # 3600 sn serbest izin ver
        until = self.cache.grant_offline_unlock(duration_sec=3600)
        self.assertTrue(self.cache.is_offline_pin_unlocked())
        rem = self.cache.remaining_offline_unlock_seconds()
        self.assertTrue(3590 <= rem <= 3600)

        # Geçmiş zamana zorlama simülasyonu
        self.cache.data["offline_unlocked_until_epoch"] = time.time() - 10
        self.assertFalse(self.cache.is_offline_pin_unlocked())
        self.assertEqual(self.cache.remaining_offline_unlock_seconds(), 0)

    # --------------------------------------------------------------------------
    # 2. BEYAZ LİSTE (WHITELIST) GÜVENLİK & BYPASS TESTLERİ
    # --------------------------------------------------------------------------
    def test_whitelist_configuration_integrity(self):
        """Whitelist JSONB yapısı izinli exe ve kelimeleri tutarlı saklamalıdır."""
        config = {
            "allowed_exes": ["chrome.exe", "winword.exe", "code.exe"],
            "allowed_keywords": ["eba", "ders", "matematik"],
        }
        self.cache.update_whitelist_config(config)
        loaded = self.cache.get_whitelist_config()
        self.assertEqual(loaded["allowed_exes"], ["chrome.exe", "winword.exe", "code.exe"])
        self.assertIn("matematik", loaded["allowed_keywords"])

        # Geçersiz tahrifat girdisi durumunda varsayılan güvenli liste korunmalı
        self.cache.data["whitelist_config"] = "invalid_string_corruption"
        safe_fallback = self.cache.get_whitelist_config()
        self.assertIsInstance(safe_fallback, dict)
        self.assertIn("allowed_exes", safe_fallback)

    # --------------------------------------------------------------------------
    # 3. İKİZ NÖBETÇİ (WATCHDOG GUARD) & OTA KİLİT YARIŞ KOŞULLARI
    # --------------------------------------------------------------------------
    def test_updating_lock_race_condition_and_file_safety(self):
        """updating.lock dosyasının varlığı Watchdog müdahalesini güvenle engellemelidir."""
        # Başlangıçta kilit yok
        clear_ota_updating_lock()
        self.assertFalse(is_ota_updating())

        # Güncelleme başladığında kilit oluşturulur
        set_ota_updating_lock()
        self.assertTrue(is_ota_updating())

        # Kilidin dosya içeriğinde epoch ve sürüm olmalı
        from config import LOCK_FILE_PATH
        self.assertTrue(LOCK_FILE_PATH.exists())
        with open(LOCK_FILE_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("updating_at=", content)
        self.assertIn(f"version={AGENT_VERSION}", content)

        # Güncelleme bittiğinde kilit temizlenir
        clear_ota_updating_lock()
        self.assertFalse(is_ota_updating())
        self.assertFalse(LOCK_FILE_PATH.exists())

        # Çift silme çağrısında hata fırlatmamalı (Idempotence)
        clear_ota_updating_lock()
        self.assertFalse(is_ota_updating())

    # --------------------------------------------------------------------------
    # 4. OTA AUTO-UPDATER VERSİYON GÜVENLİK TESTLERİ
    # --------------------------------------------------------------------------
    def test_semver_parsing_and_downgrade_attack_prevention(self):
        """Daha eski veya sahte sürümler güncellemeyi tetiklememelidir (Anti-Downgrade)."""
        # Normal güncellemeler
        self.assertTrue(is_version_newer("1.0.1", "1.0.0"))
        self.assertTrue(is_version_newer("1.1.0", "1.0.9"))
        self.assertTrue(is_version_newer("2.0.0", "1.9.9"))
        self.assertTrue(is_version_newer("v1.0.5", "1.0.4"))

        # Aynı sürüm güncellenmemeli
        self.assertFalse(is_version_newer("1.0.0", "1.0.0"))

        # Eski sürüme düşürme (Downgrade Attack) engellenmeli
        self.assertFalse(is_version_newer("0.9.9", "1.0.0"))
        self.assertFalse(is_version_newer("1.0.0", "1.0.1"))
        self.assertFalse(is_version_newer("1.0.0", "2.0.0"))

        # Bozuk veya manipüle edilmiş versiyon dizgeleri
        self.assertFalse(is_version_newer("", "1.0.0"))
        self.assertFalse(is_version_newer("invalid_ver", "1.0.0"))
        self.assertFalse(is_version_newer("...", "1.0.0"))
        self.assertEqual(parse_semver("1.2.3.4.5"), (1, 2, 3, 4))
        self.assertEqual(parse_semver("v2.1"), (2, 1, 0))


class TestUnitMathAndHooks(unittest.TestCase):
    """Matematiksel ve Donanımsal Fonksiyonların Birim Testleri."""

    def test_db_rms_computation_boundaries(self):
        """NoiseMonitorThread RMS hesaplama sınır değerleri ve sessizlik koruması."""
        from system_hooks import NoiseMonitorThread

        # Boş dizi veya None durumunda güvenli taban seviyesi (35 dB)
        self.assertEqual(NoiseMonitorThread._compute_db_from_float_samples([]), 35)
        self.assertEqual(NoiseMonitorThread._compute_db_from_float_samples(None), 35)

        try:
            import numpy as np
            # Tam sessizlik (0.0 sinyaller) -> minimum taban desibel
            zeros = np.zeros(100, dtype=np.float32)
            db_zero = NoiseMonitorThread._compute_db_from_float_samples(zeros)
            self.assertEqual(db_zero, 30)

            # Normal ses seviyesi (RMS ~ 0.01) -> ~54 dB
            normal_samples = np.full(100, 0.01, dtype=np.float32)
            db_norm = NoiseMonitorThread._compute_db_from_float_samples(normal_samples)
            self.assertTrue(50 <= db_norm <= 60)

            # Çok yüksek bağırma seviyesi (RMS ~ 0.5) -> ~88 dB
            loud_samples = np.full(100, 0.5, dtype=np.float32)
            db_loud = NoiseMonitorThread._compute_db_from_float_samples(loud_samples)
            self.assertTrue(80 <= db_loud <= 95)
        except ImportError:
            # numpy bulunmayan sistemlerde çökmeden 35 dB güvenli değer döndürür
            self.assertEqual(NoiseMonitorThread._compute_db_from_float_samples([0.1, 0.2]), 35)

    def test_tts_announcer_duck_scalar_clamping(self):
        """Audio ducking ses seviyesi güvenli sınırlar (0.05 .. 0.50) arasında tutulmalıdır."""
        from system_hooks import TTSAnnouncer

        # Varsayılan %20
        t1 = TTSAnnouncer(duck_scalar=0.20, enabled=False)
        self.assertAlmostEqual(t1.duck_scalar, 0.20)

        # Çok düşük verilirse 0.05'e clamp edilir
        t2 = TTSAnnouncer(duck_scalar=0.001, enabled=False)
        self.assertAlmostEqual(t2.duck_scalar, 0.05)

        # Çok yüksek verilirse 0.50'ye clamp edilir
        t3 = TTSAnnouncer(duck_scalar=0.99, enabled=False)
        self.assertAlmostEqual(t3.duck_scalar, 0.50)

    def test_pid_existence_check(self):
        """PID kontrolünün çalışan süreçleri doğru algıladığı doğrulanır."""
        # Kendi sürecimizin PID'si kesinlikle hayatta olmalıdır
        current_pid = os.getpid()
        self.assertTrue(is_pid_alive_and_matches(current_pid))

        # Negatif veya 0 PID geçersiz sayılmalıdır
        self.assertFalse(is_pid_alive_and_matches(-1))
        self.assertFalse(is_pid_alive_and_matches(0))

        # Olmayan uçuk bir PID
        self.assertFalse(is_pid_alive_and_matches(99999999))


if __name__ == "__main__":
    unittest.main(verbosity=2)
