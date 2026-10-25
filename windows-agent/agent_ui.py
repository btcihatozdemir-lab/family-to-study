"""
===============================================================================
3. agent_ui.py - PYQT6 WEBENGINE WIDGET / TAM EKRAN KİLİT & SUPABASE REALTIME
===============================================================================
İçerik:
- QWebEngineView ile merkezi PWA'yı gömülü çalıştırma (mikrofon, kamera ve
  otomatik ses çalma izinleri dahil).
- İki Ana Görünüm Modu + Faz 3 Oyun Üstü (Top-Most Overlay) Genişletme:
  1) FREE_TIME (Widget Modu): Sağ üst köşede 350x120 px yarı saydam, çerçevesiz,
     her zaman üstte duran masaüstü widget'ı (tıklanınca 440x620 px genişler).
  2) Oyun Üstü (Top-Most Overlay - 600x350 px): Süre bitimine 2 dk / 30 sn
     kaldığında (+3 Dk Uzatma Jokeri) veya 20-20-20 Göz/Duruş Molası
     tetiklendiğinde ekranın tam ortasına 600x350 px olarak gelir ve
     SetWindowPos(hwnd, HWND_TOPMOST, ..., SWP_NOACTIVATE) ile odak çalmadan
     (oyunu alta atmadan) gösterilir; mola bitince veya uzatma alınınca tekrar
     sağ üstteki 350x120 px boyutuna küçülür.
  3) STUDY_TIME / SLEEP_TIME / WAKE_UP_ALARM / OFFLINE_LOCK (Tam Ekran Kilit):
     Tüm ekranı/monitörleri kaplar, düşük seviyeli klavye kancasını aktif eder,
     Görev Yöneticisi'ni engeller ve PWA kilit ekranını gösterir.
- Donanımsal Gürültü / Bağırma Sensörü (NoiseMonitorThread + NoiseWarningBanner):
  8 saniye kesintisiz `noise_threshold_db` aşılırsa 5 saniyelik yarı saydam
  uyarı bandı gösterir ve 60 sn cooldown ile `high_noise_detected` kaydeder.
- Gece 00:00 ve Sabah İlk Açılış Günlük Sıfırlama (`grace_used_today` & `daily_shields=3`).
===============================================================================
"""

from __future__ import annotations

import base64
from datetime import datetime, timezone
import threading
import time
from typing import Optional

from PyQt6.QtCore import (
    Qt,
    QUrl,
    QTimer,
    pyqtSignal,
    QObject,
    QPoint,
)
from PyQt6.QtGui import QGuiApplication, QCloseEvent, QKeyEvent
from PyQt6.QtWidgets import (
    QMainWindow,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QFrame,
    QDialog,
    QLineEdit,
)
from PyQt6.QtWebEngineWidgets import QWebEngineView
from PyQt6.QtWebEngineCore import QWebEnginePage, QWebEngineSettings

try:
    from supabase import create_client, Client
except ImportError:
    create_client = None
    Client = None

from config import CONFIG, LOCAL_CACHE
from system_hooks import (
    InputActivityTracker,
    LowLevelKeyboardBlocker,
    WhitelistEnforcer,
    NoiseMonitorThread,
    TTSAnnouncer,
    terminate_task_manager_if_running,
    force_window_to_foreground,
    set_window_topmost_no_activate,
    enforce_master_volume,
    prevent_deep_sleep_allow_monitor_off,
    wake_up_monitor_for_alarm,
    get_active_window_title,
    capture_screen_to_png_bytes,
)
from ota_updater import OTAUpdaterThread


# ==============================================================================
# ARKA PLAN İŞ PARÇACIKLARI İLE PYQT6 ANA THREAD ARASI SİNYAL KÖPRÜSÜ
# ==============================================================================
class AgentSignalBridge(QObject):
    state_updated = pyqtSignal(dict)
    remote_screenshot_requested = pyqtSignal(str)
    connection_status_changed = pyqtSignal(bool)
    high_noise_detected = pyqtSignal(int)
    race_task_detected = pyqtSignal(dict)
    appeal_prompt_requested = pyqtSignal(str)
    tts_announcement_requested = pyqtSignal(str)


# ==============================================================================
# FAZ 2: 4 SANİYELİK HER ŞEYİN ÜSTÜNDE DURAN UYARI BALONCUĞU (COMPUTER_STUDY)
# ==============================================================================
class WhitelistWarningBubble(QWidget):
    """
    `COMPUTER_STUDY` modunda izin verilmeyen bir uygulama veya sekme açılıp
    `SW_MINIMIZE` ile küçültüldüğünde 4 saniye boyunca her şeyin üstünde
    görünen uyarı baloncuğu.
    """

    def __init__(self) -> None:
        super().__init__(None)
        self.setWindowTitle("Bilgisayarlı Ders Uyarısı")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.card = QFrame(self)
        self.card.setStyleSheet(
            """
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #7f1d1d, stop:0.5 #991b1b, stop:1 #450a0a);
                border: 2px solid #fbbf24;
                border-radius: 16px;
            }
            """
        )
        card_layout = QVBoxLayout(self.card)
        card_layout.setContentsMargins(20, 14, 20, 14)
        card_layout.setSpacing(6)

        self.lbl_main = QLabel(
            "⚠️ Bilgisayarlı Ders Modundasın! Sadece izin verilen ders araçları kullanılabilir."
        )
        self.lbl_main.setWordWrap(True)
        self.lbl_main.setStyleSheet(
            "font-size: 14px; font-weight: 900; color: #fef08a; border: none;"
        )
        card_layout.addWidget(self.lbl_main)

        self.lbl_sub = QLabel("")
        self.lbl_sub.setStyleSheet(
            "font-size: 12px; font-weight: 700; color: #fecaca; border: none;"
        )
        card_layout.addWidget(self.lbl_sub)

        layout.addWidget(self.card)

        self._hide_timer = QTimer(self)
        self._hide_timer.setSingleShot(True)
        self._hide_timer.timeout.connect(self.hide)

    def show_warning(self, blocked_app_name: str, duration_ms: int = 4000) -> None:
        self.lbl_sub.setText(
            f"🚫 Küçültülen İzinsiz Uygulama/Sekme: {blocked_app_name}"
        )
        w, h = 620, 92
        screen = QGuiApplication.primaryScreen()
        if screen:
            avail = screen.availableGeometry()
            x = avail.left() + (avail.width() - w) // 2
            y = avail.top() + 36
            self.setGeometry(x, y, w, h)
        else:
            self.resize(w, h)

        self.show()
        self.raise_()
        try:
            set_window_topmost_no_activate(
                int(self.winId()),
                self.x(),
                self.y(),
                self.width(),
                self.height(),
            )
        except Exception:
            pass
        self._hide_timer.start(duration_ms)


# ==============================================================================
# FAZ 3: 5 SANİYELİK YARI SAYDAM GÜRÜLTÜ / BAĞIRMA UYARI BANDI (NoiseWarningBanner)
# ==============================================================================
class NoiseWarningBanner(QWidget):
    """
    Odadaki ses seviyesi 8 saniye boyunca kesintisiz olarak `noise_threshold_db`
    eşiğini aştığında ekranda 5 saniye boyunca yarı saydam ve odak çalmadan
    görünen PyQt6 uyarı bandı.
    """

    def __init__(self) -> None:
        super().__init__(None)
        self.setWindowTitle("Yüksek Gürültü Uyarısı")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setWindowOpacity(0.92)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.card = QFrame(self)
        self.card.setStyleSheet(
            """
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #881337, stop:0.5 #9f1239, stop:1 #4c0519);
                border: 2px solid #fda4af;
                border-radius: 16px;
            }
            """
        )
        card_layout = QVBoxLayout(self.card)
        card_layout.setContentsMargins(20, 14, 20, 14)
        card_layout.setSpacing(5)

        self.lbl_title = QLabel(
            "🔊 Ses seviyesi çok yükseldi! Lütfen daha sakin olalım."
        )
        self.lbl_title.setWordWrap(True)
        self.lbl_title.setStyleSheet(
            "font-size: 15px; font-weight: 900; color: #ffffff; border: none;"
        )
        card_layout.addWidget(self.lbl_title)

        self.lbl_detail = QLabel("")
        self.lbl_detail.setStyleSheet(
            "font-size: 12px; font-weight: 700; color: #fecdd3; border: none;"
        )
        card_layout.addWidget(self.lbl_detail)

        layout.addWidget(self.card)

        self._hide_timer = QTimer(self)
        self._hide_timer.setSingleShot(True)
        self._hide_timer.timeout.connect(self.hide)

    def show_noise_warning(
        self,
        measured_db: int,
        threshold_db: int,
        duration_ms: int = 5000,
    ) -> None:
        self.lbl_detail.setText(
            f"Ölçülen Anlık Gürültü: {measured_db} dB (Aile Eşiği: {threshold_db} dB) • Gizlilik: Ses kaydedilmez."
        )
        w, h = 620, 88
        screen = QGuiApplication.primaryScreen()
        if screen:
            avail = screen.availableGeometry()
            x = avail.left() + (avail.width() - w) // 2
            y = avail.top() + 34
            self.setGeometry(x, y, w, h)
        else:
            self.resize(w, h)

        self.show()
        self.raise_()
        try:
            set_window_topmost_no_activate(
                int(self.winId()),
                self.x(),
                self.y(),
                self.width(),
                self.height(),
            )
        except Exception:
            pass
        self._hide_timer.start(duration_ms)


# ==============================================================================
# FAZ 2: EBEVEYN 6 HANELİ OFFLINE PIN GİRİŞ DİYALOĞU ("🔑 Ebeveyn PIN")
# ==============================================================================
class OfflinePinDialog(QDialog):
    """
    Tam ekran kilit modundayken (normal kilit veya internet kesintisi kilidi)
    sağ alt köşedeki '🔑 Ebeveyn PIN' butonuna tıklandığında açılan 6 haneli
    SHA-256 doğrulamalı yerel kurtarma penceresi.
    """

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("🔑 Ebeveyn Çevrimdışı Kurtarma PIN Kodu")
        self.setWindowFlags(
            Qt.WindowType.Dialog
            | Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
        )
        self.setModal(True)
        self.setFixedSize(410, 240)
        self.setStyleSheet(
            """
            QDialog {
                background-color: #0f172a;
                border: 2px solid #f59e0b;
                border-radius: 18px;
                color: #f8fafc;
            }
            """
        )

        layout = QVBoxLayout(self)
        layout.setContentsMargins(22, 20, 22, 20)
        layout.setSpacing(10)

        title = QLabel("🔑 6 Haneli Ebeveyn Kurtarma PIN Kodu")
        title.setStyleSheet("font-size: 15px; font-weight: 900; color: #fbbf24;")
        layout.addWidget(title)

        desc = QLabel(
            "İnternet kesik olsa bile yerel SHA-256 önbelleği ile doğrulama yapar "
            "ve 1 saatlik serbest kullanım (FREE_TIME) izni tanımlar."
        )
        desc.setWordWrap(True)
        desc.setStyleSheet("font-size: 11px; color: #cbd5e1;")
        layout.addWidget(desc)

        self.pin_input = QLineEdit(self)
        self.pin_input.setMaxLength(6)
        self.pin_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.pin_input.setPlaceholderText("•••••• (6 Haneli PIN)")
        self.pin_input.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.pin_input.setStyleSheet(
            """
            QLineEdit {
                background-color: #020617;
                border: 2px solid #475569;
                border-radius: 12px;
                padding: 10px;
                font-size: 18px;
                font-weight: 900;
                letter-spacing: 6px;
                color: #ffffff;
            }
            QLineEdit:focus {
                border-color: #fbbf24;
            }
            """
        )
        layout.addWidget(self.pin_input)

        self.lbl_error = QLabel("")
        self.lbl_error.setStyleSheet(
            "font-size: 11px; font-weight: 700; color: #fb7185;"
        )
        layout.addWidget(self.lbl_error)

        btn_row = QHBoxLayout()
        btn_cancel = QPushButton("İptal")
        btn_cancel.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_cancel.setStyleSheet(
            """
            QPushButton {
                background-color: #1e293b;
                color: #cbd5e1;
                font-size: 12px;
                font-weight: 800;
                padding: 9px 16px;
                border-radius: 10px;
                border: 1px solid #334155;
            }
            """
        )
        btn_cancel.clicked.connect(self.reject)

        btn_unlock = QPushButton("🔓 Kilidi Aç (1 Saat Serbest)")
        btn_unlock.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_unlock.setStyleSheet(
            """
            QPushButton {
                background-color: #f59e0b;
                color: #020617;
                font-size: 12px;
                font-weight: 900;
                padding: 9px 16px;
                border-radius: 10px;
                border: none;
            }
            QPushButton:hover {
                background-color: #fbbf24;
            }
            """
        )
        btn_unlock.clicked.connect(self._on_verify_clicked)

        btn_row.addWidget(btn_cancel)
        btn_row.addWidget(btn_unlock)
        layout.addLayout(btn_row)

    def _on_verify_clicked(self) -> None:
        entered = self.pin_input.text().strip()
        if len(entered) != 6 or not entered.isdigit():
            self.lbl_error.setText("⚠️ Lütfen 6 haneli sayısal PIN kodunu girin.")
            return
        if LOCAL_CACHE.verify_offline_pin(entered):
            self.accept()
        else:
            self.lbl_error.setText("❌ Hatalı Ebeveyn PIN kodu! Tekrar deneyin.")
            self.pin_input.clear()


# ==============================================================================
# ÖZEL QWebEnginePage (KAMERA, MİKROFON VE OTOMATİK SES İZİNLERİ)
# ==============================================================================
class FamilyWebEnginePage(QWebEnginePage):
    """
    PWA içindeki Bas-Konuş Telsiz (Mikrofon) ve Fotoğraf Kanıtı (Kamera)
    isteklerini kullanıcıya sorup kilit ekranını bozmadan otomatik onaylar.
    """

    def __init__(self, parent: Optional[QObject] = None) -> None:
        super().__init__(parent)
        self.featurePermissionRequested.connect(self._on_feature_permission)

    def _on_feature_permission(
        self,
        security_origin: QUrl,
        feature: QWebEnginePage.Feature,
    ) -> None:
        allowed_features = (
            QWebEnginePage.Feature.MediaAudioCapture,
            QWebEnginePage.Feature.MediaVideoCapture,
            QWebEnginePage.Feature.MediaAudioVideoCapture,
            QWebEnginePage.Feature.Notifications,
        )
        if feature in allowed_features:
            self.setFeaturePermission(
                security_origin,
                feature,
                QWebEnginePage.PermissionPolicy.PermissionGrantedByUser,
            )
        else:
            self.setFeaturePermission(
                security_origin,
                feature,
                QWebEnginePage.PermissionPolicy.PermissionDeniedByUser,
            )


# ==============================================================================
# ANA ENDPOINT AGENT PENCERESİ (WIDGET & TAM EKRAN KİLİT)
# ==============================================================================
class StudentEndpointWindow(QMainWindow):
    # Faz 4 & Faz 5 Durum (State) Matrisi Kontrolü:
    # Tam Ekran Kilitlenenler (showFullScreen + Kısayol Engelleme Aktif):
    LOCKED_STATES = (
        "STUDY_TIME",
        "ROUTINE_TIME",
        "SLEEP_TIME",
        "WAKE_UP_ALARM",
        "OFFLINE_LOCK",
        "CO_STUDY_MODE",
    )
    # Masaüstü Widget Olarak Duranlar (350x120 px + FAMILYOS_UI_EXPAND ile Büyüyebilenler):
    WIDGET_STATES = (
        "FREE_TIME",
        "BREAK_TIME",
        "COMPUTER_STUDY",
        "GUEST_MODE",
        "FROZEN_HOLIDAY",
    )
    PASSIVE_EXEMPT_STATES = ("GUEST_MODE", "FROZEN_HOLIDAY")
    AUDIO_BOOST_STATES = ("WAKE_UP_ALARM", "BREAK_TIME")

    def __init__(self) -> None:
        super().__init__()
        self.signals = AgentSignalBridge()
        self.signals.state_updated.connect(self._apply_student_state)
        self.signals.remote_screenshot_requested.connect(self._handle_remote_screenshot)
        self.signals.connection_status_changed.connect(self._on_connection_status)
        self.signals.high_noise_detected.connect(self._on_high_noise_detected)
        self.signals.race_task_detected.connect(self._on_race_task_detected)
        self.signals.appeal_prompt_requested.connect(self._on_appeal_prompt_requested)
        self.signals.tts_announcement_requested.connect(self._on_tts_announcement_requested)

        # Durum değişkenleri
        self.current_state: str = "FREE_TIME"
        self.previous_state: str = "FREE_TIME"
        self.state_ends_at: Optional[str] = None
        self.student_name: str = "Ömer"
        self.points_balance: int = 145
        self.daily_shields: int = 3
        self.grace_used_today: bool = False
        self.appeal_used_today: bool = False
        self.tts_announcements_enabled: bool = LOCAL_CACHE.get_tts_announcements_enabled()
        self.is_widget_expanded: bool = False
        self.is_overlay_popup_active: bool = False
        self.overlay_popup_mode: Optional[str] = None
        self._active_race_task: Optional[dict] = None
        self._last_violation_reason_for_appeal: str = ""
        self._warned_2min_for_session: bool = False
        self._prompted_30sec_for_session: bool = False
        self._grace_extended_in_session: bool = False
        self._eye_break_elapsed_sec: int = 0
        self._eye_break_countdown_sec: int = 0
        self.allow_exit: bool = False
        self._drag_offset: Optional[QPoint] = None
        self._last_violation_epoch: float = 0.0
        self._last_whitelist_violation_epoch: float = 0.0
        self._last_noise_violation_epoch: float = 0.0
        self._last_supabase_ok_epoch: float = time.time()
        self._processed_command_ids: set[str] = set()
        self._seen_race_task_ids: set[str] = set()
        self._seen_approved_submission_ids: set[str] = set()
        self._seen_approved_appeal_ids: set[str] = set()
        self._last_announced_happy_hour_key: str = ""
        self._poller_bootstrapped: bool = False

        # Supabase istemcisi
        self.supabase: Optional[Client] = None
        self._init_supabase_client()

        # Faz 3 Modül 3: Sabah İlk Açılış veya Gece 00:00 Günlük Sıfırlama Kontrolü
        self._ensure_daily_reset_if_new_day()

        # Sistem Kancaları (Klavye Engelleyici, Girdi Sensörü, Whitelist, Gürültü Sensörü, TTS & Derin Uyku Engeli)
        self.input_tracker = InputActivityTracker()
        self.whitelist_enforcer = WhitelistEnforcer(LOCAL_CACHE.get_whitelist_config())
        self.warning_bubble = WhitelistWarningBubble()
        self.noise_banner = NoiseWarningBanner()
        self.noise_monitor = NoiseMonitorThread(
            threshold_db=LOCAL_CACHE.get_noise_threshold_db(),
            sustained_seconds=CONFIG.noise_sustained_seconds,
            on_high_noise_callback=lambda db: self.signals.high_noise_detected.emit(db),
        )
        self.noise_monitor.start()
        self.tts_announcer = TTSAnnouncer(
            duck_scalar=CONFIG.audio_ducking_scalar,
            enabled=self.tts_announcements_enabled,
        )
        self.tts_announcer.start()
        prevent_deep_sleep_allow_monitor_off()
        self.keyboard_blocker = LowLevelKeyboardBlocker(
            on_blocked_shortcut_callback=self._on_blocked_os_shortcut
        )
        self.keyboard_blocker.start()

        # Pencere ve Arayüz Kurulumu
        self._setup_window_flags()
        self._build_ui()
        self._transition_to_widget_mode(expanded=False)

        # Zamanlayıcıları Başlat
        self._setup_timers()

        # Arka Plan Supabase Senkronizasyon & Heartbeat Thread'lerini Başlat
        self._running = True
        threading.Thread(
            target=self._supabase_state_listener_loop,
            name="SupabaseStatePoller",
            daemon=True,
        ).start()
        threading.Thread(
            target=self._heartbeat_worker_loop,
            name="DeviceHeartbeatWorker",
            daemon=True,
        ).start()

        # Faz 5 Modül 2: OTA Uzaktan Otomatik Güncelleyici
        self.ota_updater = OTAUpdaterThread(
            supabase_client_getter=lambda: self.supabase,
            check_interval_sec=CONFIG.ota_check_interval_sec,
            on_update_started_callback=lambda ver: self.signals.tts_announcement_requested.emit(
                f"Sistem yeni sürüme (v{ver}) güncelleniyor, lütfen bekleyin."
            ),
        )
        self.ota_updater.start()

        # Faz 5 Modül 3.2: Açılışta Günlük Otomatik Görev ve Kalkan Üretimi
        self._spawn_daily_recurring_tasks_rpc()

    # --------------------------------------------------------------------------
    # 1. SUPABASE BAĞLANTISI VE YENİDEN BAĞLANMA MEKANİZMASI
    # --------------------------------------------------------------------------
    def _init_supabase_client(self) -> None:
        if not create_client:
            print("[AgentUI] Uyarı: supabase-py paketi yüklü değil.")
            return
        try:
            self.supabase = create_client(CONFIG.supabase_url, CONFIG.supabase_anon_key)
            self._last_supabase_ok_epoch = time.time()
            self.signals.connection_status_changed.emit(True)
        except Exception as err:
            print(f"[AgentUI] Supabase ilk bağlantı hatası: {err}")
            self.signals.connection_status_changed.emit(False)

    # --------------------------------------------------------------------------
    # 2. PENCERE VE GÖMÜLÜ QWebEngineView ARAYÜZ KURULUMU
    # --------------------------------------------------------------------------
    def _setup_window_flags(self) -> None:
        self.setWindowTitle("FamilyToStudy Endpoint Agent")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, False)

    def _build_ui(self) -> None:
        central = QWidget(self)
        central.setStyleSheet(
            """
            QWidget {
                background-color: #020617;
                color: #f8fafc;
                font-family: 'Segoe UI', sans-serif;
            }
            """
        )
        self.setCentralWidget(central)

        self.root_layout = QVBoxLayout(central)
        self.root_layout.setContentsMargins(0, 0, 0, 0)
        self.root_layout.setSpacing(0)

        # A) WIDGET ÜST KONTROL KARTI (FREE_TIME / COMPUTER_STUDY / GUEST_MODE / FROZEN_HOLIDAY modlarında)
        self.widget_header = QFrame(central)
        self.widget_header.setStyleSheet(
            """
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #1e1b4b, stop:0.5 #312e81, stop:1 #0f172a);
                border: 2px solid #6366f1;
                border-radius: 14px;
            }
            """
        )
        header_layout = QVBoxLayout(self.widget_header)
        header_layout.setContentsMargins(14, 10, 14, 10)
        header_layout.setSpacing(6)

        # Üst Satır: Öğrenci Adı, Mod Rozeti, Kalan Süre
        top_row = QHBoxLayout()
        self.lbl_student = QLabel("🦁 Ömer • Serbest Zaman")
        self.lbl_student.setStyleSheet("font-size: 13px; font-weight: 800; color: #ffffff; border: none;")
        top_row.addWidget(self.lbl_student)

        top_row.addStretch()

        self.lbl_timer = QLabel("🟢 FREE")
        self.lbl_timer.setStyleSheet(
            "font-size: 13px; font-weight: 900; color: #34d399; background: #020617; "
            "padding: 3px 8px; border-radius: 8px; border: 1px solid #10b981;"
        )
        top_row.addWidget(self.lbl_timer)
        header_layout.addLayout(top_row)

        # Orta Satır: Puan, Kalkanlar ve Genişlet/Küçült Butonu
        bottom_row = QHBoxLayout()
        self.lbl_stats = QLabel("⭐ 145 Puan   |   🛡️🛡️🛡️ 3 Kalkan")
        self.lbl_stats.setStyleSheet("font-size: 12px; font-weight: 700; color: #fbbf24; border: none;")
        bottom_row.addWidget(self.lbl_stats)

        bottom_row.addStretch()

        self.btn_toggle_expand = QPushButton("💬 Görev & Telsiz Aç")
        self.btn_toggle_expand.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_toggle_expand.setStyleSheet(
            """
            QPushButton {
                background-color: #4f46e5;
                color: #ffffff;
                font-size: 11px;
                font-weight: 800;
                padding: 5px 10px;
                border-radius: 8px;
                border: none;
            }
            QPushButton:hover {
                background-color: #6366f1;
            }
            """
        )
        self.btn_toggle_expand.clicked.connect(self._toggle_widget_expansion)
        bottom_row.addWidget(self.btn_toggle_expand)

        header_layout.addLayout(bottom_row)
        self.root_layout.addWidget(self.widget_header)

        # A2) FAZ 3: OYUN ÜSTÜ (TOP-MOST OVERLAY - 600x350) SAĞLIK VE UZATMA JOKERİ KARTI
        self.game_overlay_card = QFrame(central)
        self.game_overlay_card.setStyleSheet(
            """
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #0f172a, stop:0.5 #1e1b4b, stop:1 #31102f);
                border: 2px solid #f59e0b;
                border-radius: 16px;
            }
            """
        )
        overlay_card_layout = QVBoxLayout(self.game_overlay_card)
        overlay_card_layout.setContentsMargins(18, 12, 18, 12)
        overlay_card_layout.setSpacing(8)

        self.lbl_overlay_badge = QLabel("⚡ OYUN ÜSTÜ AKILLI ASİSTAN BİLDİRİMİ")
        self.lbl_overlay_badge.setStyleSheet(
            "font-size: 11px; font-weight: 900; color: #fbbf24; border: none;"
        )
        overlay_card_layout.addWidget(self.lbl_overlay_badge)

        self.lbl_overlay_title = QLabel("")
        self.lbl_overlay_title.setWordWrap(True)
        self.lbl_overlay_title.setStyleSheet(
            "font-size: 15px; font-weight: 900; color: #ffffff; border: none;"
        )
        overlay_card_layout.addWidget(self.lbl_overlay_title)

        self.lbl_overlay_desc = QLabel("")
        self.lbl_overlay_desc.setWordWrap(True)
        self.lbl_overlay_desc.setStyleSheet(
            "font-size: 12px; font-weight: 600; color: #e2e8f0; border: none;"
        )
        overlay_card_layout.addWidget(self.lbl_overlay_desc)

        overlay_btn_row = QHBoxLayout()
        self.btn_grace_extend = QPushButton(
            "⏱️ Oyunu Kaydetmek İçin +3 Dk Uzatma Al (10 Puan)"
        )
        self.btn_grace_extend.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_grace_extend.setStyleSheet(
            """
            QPushButton {
                background-color: #f59e0b;
                color: #020617;
                font-size: 12px;
                font-weight: 900;
                padding: 8px 14px;
                border-radius: 10px;
                border: none;
            }
            QPushButton:hover {
                background-color: #fbbf24;
            }
            """
        )
        self.btn_grace_extend.clicked.connect(self._on_claim_grace_extension_clicked)
        overlay_btn_row.addWidget(self.btn_grace_extend)

        self.btn_voluntary_exit = QPushButton(
            "✅ Kaydettim, Kendi İsteğimle Çıkıyorum (+15 Puan!)"
        )
        self.btn_voluntary_exit.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_voluntary_exit.setStyleSheet(
            """
            QPushButton {
                background-color: #10b981;
                color: #020617;
                font-size: 12px;
                font-weight: 900;
                padding: 8px 14px;
                border-radius: 10px;
                border: none;
            }
            QPushButton:hover {
                background-color: #34d399;
            }
            """
        )
        self.btn_voluntary_exit.clicked.connect(self._on_voluntary_early_exit_clicked)
        overlay_btn_row.addWidget(self.btn_voluntary_exit)

        self.btn_claim_race_task = QPushButton("🏃‍♂️ Ben Yaparım!")
        self.btn_claim_race_task.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_claim_race_task.setStyleSheet(
            """
            QPushButton {
                background-color: #f59e0b;
                color: #020617;
                font-size: 13px;
                font-weight: 900;
                padding: 8px 16px;
                border-radius: 10px;
                border: none;
            }
            QPushButton:hover {
                background-color: #fbbf24;
            }
            """
        )
        self.btn_claim_race_task.clicked.connect(self._on_claim_race_task_clicked)
        self.btn_claim_race_task.hide()
        overlay_btn_row.addWidget(self.btn_claim_race_task)

        self.btn_open_appeal = QPushButton("⚖️ Haksızlık mı oldu? İtiraz Et")
        self.btn_open_appeal.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_open_appeal.setStyleSheet(
            """
            QPushButton {
                background-color: #8b5cf6;
                color: #ffffff;
                font-size: 12px;
                font-weight: 900;
                padding: 8px 16px;
                border-radius: 10px;
                border: none;
            }
            QPushButton:hover {
                background-color: #a78bfa;
            }
            """
        )
        self.btn_open_appeal.clicked.connect(self._on_open_appeal_clicked)
        self.btn_open_appeal.hide()
        overlay_btn_row.addWidget(self.btn_open_appeal)

        self.btn_overlay_dismiss = QPushButton("Küçült (Sağ Üst Widget)")
        self.btn_overlay_dismiss.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_overlay_dismiss.setStyleSheet(
            """
            QPushButton {
                background-color: #1e293b;
                color: #cbd5e1;
                font-size: 11px;
                font-weight: 800;
                padding: 8px 12px;
                border-radius: 10px;
                border: 1px solid #475569;
            }
            """
        )
        self.btn_overlay_dismiss.clicked.connect(self._shrink_from_overlay_popup)
        overlay_btn_row.addWidget(self.btn_overlay_dismiss)

        overlay_card_layout.addLayout(overlay_btn_row)
        self.game_overlay_card.hide()
        self.root_layout.addWidget(self.game_overlay_card)

        # B) FAZ 2: OFFLINE GUARD YEREL TAM EKRAN KİLİT PANELİ (İnternet Kesildiğinde Gösterilir)
        self.offline_lock_panel = QFrame(central)
        self.offline_lock_panel.setStyleSheet(
            """
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #020617, stop:0.5 #450a0a, stop:1 #0f172a);
                border: none;
            }
            """
        )
        offline_layout = QVBoxLayout(self.offline_lock_panel)
        offline_layout.setContentsMargins(40, 40, 40, 40)
        offline_layout.setSpacing(18)
        offline_layout.addStretch()

        lbl_offline_icon = QLabel("🌐🔒")
        lbl_offline_icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lbl_offline_icon.setStyleSheet("font-size: 64px; background: transparent;")
        offline_layout.addWidget(lbl_offline_icon)

        self.lbl_offline_title = QLabel(
            "🌐 İnternet Bağlantısı Kesildi!\n"
            "Bağlantı gelene veya Ebeveyn PIN kodu girilene kadar bilgisayar güvenli kilide alındı."
        )
        self.lbl_offline_title.setWordWrap(True)
        self.lbl_offline_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_offline_title.setStyleSheet(
            "font-size: 24px; font-weight: 900; color: #fef08a; background: transparent;"
        )
        offline_layout.addWidget(self.lbl_offline_title)

        lbl_offline_sub = QLabel(
            "Anti-Cheat Offline Guard aktif: Modemin kapatılması veya Wi-Fi'nin kesilmesi kilit ekranını devre dışı bırakamaz.\n"
            "İnternet yeniden bağlandığında otomatik olarak normal moda dönülecektir."
        )
        lbl_offline_sub.setWordWrap(True)
        lbl_offline_sub.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lbl_offline_sub.setStyleSheet(
            "font-size: 14px; font-weight: 600; color: #fecaca; background: transparent;"
        )
        offline_layout.addWidget(lbl_offline_sub)

        offline_layout.addStretch()
        self.offline_lock_panel.hide()
        self.root_layout.addWidget(self.offline_lock_panel, stretch=1)

        # C) GÖMÜLÜ PWA WEBENGINE GÖRÜNÜMÜ
        self.web_view = QWebEngineView(central)
        self.web_page = FamilyWebEnginePage(self.web_view)
        self.web_view.setPage(self.web_page)

        # Faz 4 Modül 1 (Özel User-Agent Tanımlama):
        # QWebEngineView profilini başlatırken "FamilyOS-Windows-Agent/1.0" olarak
        # özel User-Agent tanımla. Böylece PWA, Windows Ajanı içinde çalıştığını
        # anlayıp kendi Web TTS ve Web Desibel ölçerini kapatacak, kontrolü
        # tamamen Python ajanına bırakacaktır.
        try:
            profile = self.web_page.profile()
            profile.setHttpUserAgent(CONFIG.user_agent_signature)
        except Exception as err:
            print(f"[AgentUI] User-Agent ayarlama uyarısı: {err}")

        # Faz 4 Modül 3 (PWA <-> Python Akıllı Pencere Boyutlandırma Köprüsü):
        # PWA içinde `document.title = "FAMILYOS_UI_EXPAND"` veya
        # `"FAMILYOS_UI_COLLAPSE"` değişimini yakalayıp pencereyi 900x650 <-> 350x120
        # boyutlarına otomatik geçir:
        self.web_view.titleChanged.connect(self.on_title_changed)

        # Web Audio API'nin (Uyandırma Alarmı & Mola Zilleri) kullanıcı tıklaması
        # beklemeden doğrudan çalabilmesi için zorunlu ayar:
        settings = self.web_view.settings()
        settings.setAttribute(
            QWebEngineSettings.WebAttribute.PlaybackRequiresUserGesture,
            False,
        )
        settings.setAttribute(
            QWebEngineSettings.WebAttribute.LocalStorageEnabled,
            True,
        )
        settings.setAttribute(
            QWebEngineSettings.WebAttribute.JavascriptCanAccessClipboard,
            True,
        )

        self.web_view.setUrl(QUrl(CONFIG.pwa_url))
        self.root_layout.addWidget(self.web_view, stretch=1)

        # D) FAZ 2: TAM EKRAN KİLİT MODU SAĞ ALT YEREL "🔑 Ebeveyn PIN" ÇUBUĞU
        self.lock_bottom_bar = QFrame(central)
        self.lock_bottom_bar.setStyleSheet(
            """
            QFrame {
                background-color: #020617;
                border-top: 1px solid #1e293b;
            }
            """
        )
        lock_bar_layout = QHBoxLayout(self.lock_bottom_bar)
        lock_bar_layout.setContentsMargins(20, 8, 20, 8)

        self.lbl_lock_footer_info = QLabel(
            "🛡️ FamilyToStudy Endpoint Kalkanı Aktif • İnternet kopsa bile yerel SHA-256 PIN ile açılabilir"
        )
        self.lbl_lock_footer_info.setStyleSheet(
            "font-size: 11px; font-weight: 700; color: #94a3b8;"
        )
        lock_bar_layout.addWidget(self.lbl_lock_footer_info)
        lock_bar_layout.addStretch()

        self.btn_parent_offline_pin = QPushButton("🔑 Ebeveyn PIN")
        self.btn_parent_offline_pin.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_parent_offline_pin.setStyleSheet(
            """
            QPushButton {
                background-color: #f59e0b;
                color: #020617;
                font-size: 12px;
                font-weight: 900;
                padding: 7px 16px;
                border-radius: 10px;
                border: none;
            }
            QPushButton:hover {
                background-color: #fbbf24;
            }
            """
        )
        self.btn_parent_offline_pin.clicked.connect(self._open_offline_pin_dialog)
        lock_bar_layout.addWidget(self.btn_parent_offline_pin)

        self.lock_bottom_bar.hide()
        self.root_layout.addWidget(self.lock_bottom_bar)

    # --------------------------------------------------------------------------
    # 3. MOD GEÇİŞLERİ: WIDGET (350x120), AKILLI KÖPRÜ (900x650), POPUP'LAR & TAM EKRAN KİLİT
    # --------------------------------------------------------------------------
    def _transition_to_widget_mode(
        self,
        expanded: bool = False,
        custom_size: Optional[tuple[int, int]] = None,
        grant_focus: bool = False,
    ) -> None:
        """
        FREE_TIME / BREAK_TIME / COMPUTER_STUDY / GUEST_MODE / FROZEN_HOLIDAY
        modlarında ekranın sağ üst köşesinde yarı saydam, her zaman üstte duran
        masaüstü widget'ına (350x120 px) veya genişletilmiş etkileşim boyutuna
        (900x650 px / 800x600 px) geçer.
        """
        self.keyboard_blocker.set_blocking(False)
        self.is_widget_expanded = expanded
        self.is_overlay_popup_active = False
        self.overlay_popup_mode = None
        self.offline_lock_panel.hide()
        self.lock_bottom_bar.hide()
        self.game_overlay_card.hide()
        self.widget_header.show()

        if expanded:
            self.web_view.show()
            w = custom_size[0] if custom_size else CONFIG.widget_expanded_width
            h = custom_size[1] if custom_size else CONFIG.widget_expanded_height
            self.btn_toggle_expand.setText("🔼 Küçült (350x120)")
            self.setWindowOpacity(0.98)
        else:
            self.web_view.hide()
            w = CONFIG.widget_width
            h = CONFIG.widget_height
            self.btn_toggle_expand.setText("💬 Görev & Telsiz Aç")
            self.setWindowOpacity(CONFIG.widget_opacity)

        self.showNormal()
        screen = QGuiApplication.primaryScreen()
        if screen:
            avail = screen.availableGeometry()
            if expanded:
                # Sağ üstten ekranın ortasına doğru 900x650 (veya 800x600) genişlet
                x = avail.left() + max(20, (avail.width() - w) // 2)
                y = avail.top() + max(20, (avail.height() - h) // 2)
            else:
                x = avail.right() - w - CONFIG.widget_margin_right
                y = avail.top() + CONFIG.widget_margin_top
            self.setGeometry(x, y, w, h)
        else:
            self.resize(w, h)

        self.raise_()
        if grant_focus or expanded:
            self.activateWindow()
            try:
                force_window_to_foreground(int(self.winId()))
            except Exception:
                pass
        else:
            try:
                set_window_topmost_no_activate(
                    int(self.winId()),
                    self.x(),
                    self.y(),
                    self.width(),
                    self.height(),
                )
            except Exception:
                pass

    def on_title_changed(self, new_title: str) -> None:
        """
        Faz 4 Modül 3 (PWA <-> Python Akıllı Pencere Boyutlandırma Köprüsü):
        1. `title == "FAMILYOS_UI_EXPAND"` (Genişletilmiş Etkileşim Modu):
           Sağ üstte 350x120 px olan pencereyi ekranın ortasına doğru 900x650 px
           boyutuna genişletir ve klavye/fare odağını verir (`activateWindow()`).
        2. `title == "FAMILYOS_UI_COLLAPSE"` (Mini Widget Modu):
           Etkileşim bittiğinde (ve mevcut mod tam ekran kilit modu değilse) pencereyi
           tekrar sağ üst köşedeki 350x120 px kompakt Widget boyutuna küçültür.
        """
        if self.current_state in self.LOCKED_STATES:
            return
        title_clean = (new_title or "").strip().upper()
        if "FAMILYOS_UI_EXPAND" in title_clean:
            self._transition_to_widget_mode(
                expanded=True,
                custom_size=(CONFIG.widget_expanded_width, CONFIG.widget_expanded_height),
                grant_focus=True,
            )
        elif "FAMILYOS_UI_COLLAPSE" in title_clean:
            if self.current_state == "BREAK_TIME":
                # BREAK_TIME bittiğinde veya çark kapatıldığında 350x120'ye dönebilir
                self._transition_to_widget_mode(expanded=False, grant_focus=False)
            elif self.is_widget_expanded and not self.is_overlay_popup_active:
                self._transition_to_widget_mode(expanded=False, grant_focus=False)

    # Geriye dönük uyumluluk için alias
    _on_web_title_changed = on_title_changed

    def _expand_for_break_roulette(self) -> None:
        """
        Faz 4 Modül 4.3 (Aktif Mola Ruleti - BREAK_TIME):
        Durum `BREAK_TIME` olduğunda (Aktif Mola Çarkı dönerken) pencereyi
        otomatik olarak `800x600 px` etkileşimli boyuta getirir.
        """
        if self.current_state in self.LOCKED_STATES:
            return
        self._transition_to_widget_mode(
            expanded=True,
            custom_size=(CONFIG.break_roulette_width, CONFIG.break_roulette_height),
            grant_focus=True,
        )

    def _expand_to_center_overlay_popup(self, mode: str) -> None:
        """
        Faz 3 Modül 1 & Faz 4 Modül 4 (Dinamik Pencere Genişletme - Popup Expansion):
        - `grace_2min` / `grace_30sec` / `eye_break`: 600x350 px (Merkez Top-Most, odak çalmadan)
        - `race_quest`: 12 saniyeliğine 500x260 px (`HWND_TOPMOST`) -> "🏃‍♂️ Ben Yaparım!"
        - `appeal_prompt`: 15 saniyeliğine 550x380 px (`HWND_TOPMOST`) -> "⚖️ Haksızlık mı oldu? İtiraz Et"
        """
        if self.current_state in self.LOCKED_STATES and mode != "appeal_prompt":
            return

        self.is_overlay_popup_active = True
        self.overlay_popup_mode = mode
        self.widget_header.show()
        self.game_overlay_card.show()
        self.web_view.show()

        self.btn_grace_extend.hide()
        self.btn_voluntary_exit.hide()
        self.btn_claim_race_task.hide()
        self.btn_open_appeal.hide()

        w = CONFIG.overlay_popup_width  # 600 px
        h = CONFIG.overlay_popup_height  # 350 px

        if mode == "grace_2min":
            self.lbl_overlay_badge.setText("⏳ SÜRE BİTİMİ ÖN UYARISI (2 DAKİKA KALDI)")
            self.lbl_overlay_title.setText(
                "⏳ Serbest zamanının bitmesine 2 dakika kaldı!"
            )
            self.lbl_overlay_desc.setText(
                "Oyununu kaydetmeye ve güvenli bir noktada durdurmaya hazırlan. "
                "Son 30 saniyede ihtiyaç duyarsan +3 Dakika Uzatma Jokeri açılacak."
            )
            self.btn_voluntary_exit.setVisible(self._grace_extended_in_session)
            self.btn_overlay_dismiss.setText("👍 Anladım, Küçült (350x120)")
        elif mode == "grace_30sec":
            self.lbl_overlay_badge.setText(
                "🚨 KRİZ ÖNLEYİCİ UZATMA JOKERİ & İRADE EĞİTİMİ"
            )
            self.lbl_overlay_title.setText(
                "🚨 Süren Bitiyor! Oyununu Kaydetmek İçin +3 Dakika Uzatma Jokeri"
            )
            self.lbl_overlay_desc.setText(
                "Oyunun en heyecanlı yerinde yarıda kalmasın: Günde 1 kez 10 Puan "
                "karşılığında +3 dakika uzatma alabilirsin. Uzatma bitmeden kendi "
                "isteğinle çıkarsan 10 puanın iade edilir ve +5 İrade Bonusu kazanırsın!"
            )
            can_extend = (not self.grace_used_today) and (self.points_balance >= 10)
            self.btn_grace_extend.setVisible(can_extend)
            self.btn_voluntary_exit.setVisible(self._grace_extended_in_session)
            self.btn_overlay_dismiss.setText("Küçült (350x120)")
        elif mode == "eye_break":
            self.lbl_overlay_badge.setText(
                "👁️ 20-20-20 GÖZ & DİK OTURUŞ KALKANI (+2 SAĞLIK PUANI)"
            )
            self.lbl_overlay_title.setText(
                f"👁️ Gözlerini Dinlendir & Sırtını Dikleştir! ({self._eye_break_countdown_sec} sn)"
            )
            self.lbl_overlay_desc.setText(
                "20 dakikadır ekrana bakıyorsun! Şimdi 20 saniye boyunca 6 metre "
                "uzağa bak, omuzlarını geriye al ve dik otur. Süre bitince pencere "
                "otomatik olarak sağ üst köşeye küçülecek ve +2 Sağlık Puanı kazanacaksın!"
            )
            self.btn_overlay_dismiss.setText("Küçült (350x120)")
        elif mode == "race_quest":
            w = CONFIG.race_popup_width  # 500 px
            h = CONFIG.race_popup_height  # 260 px
            task_title = (
                self._active_race_task.get("title", "Sürpriz Yarış Görevi")
                if isinstance(self._active_race_task, dict)
                else "Sürpriz Yarış Görevi"
            )
            task_pts = (
                int(self._active_race_task.get("reward_points", 50))
                if isinstance(self._active_race_task, dict)
                else 50
            )
            self.lbl_overlay_badge.setText("⚡ İLK KAPAR KARDEŞ YARIŞ GÖREVİ (12 SANİYE)")
            self.lbl_overlay_title.setText(f"⚡ {task_title} (+{task_pts} Puan!)")
            self.lbl_overlay_desc.setText(
                "Yeni bir yarış görevi açıldı! Kardeşinden önce '🏃‍♂️ Ben Yaparım!' "
                "butonuna tıkla ve görevi kendi üzerine kilitle!"
            )
            self.btn_claim_race_task.show()
            self.btn_overlay_dismiss.setText("Kapat (350x120)")
        elif mode == "appeal_prompt":
            w = CONFIG.appeal_popup_width  # 550 px
            h = CONFIG.appeal_popup_height  # 380 px
            self.lbl_overlay_badge.setText("⚖️ ADALET DİVANI (15 SANİYE İTİRAZ HAKKI)")
            self.lbl_overlay_title.setText("⚖️ Kalkanın Kırıldı! Haksızlık mı oldu?")
            self.lbl_overlay_desc.setText(
                f"Tespit edilen ihlal: {self._last_violation_reason_for_appeal or 'Sistem Kalkan İhlali'}.\n"
                "Eğer yanlışlıkla veya haklı bir sebeple olduğuna inanıyorsan günde 1 kez "
                "15 saniyelik sesli savunma veya açıklama göndererek kalkanını geri kazanabilirsin!"
            )
            self.btn_open_appeal.show()
            self.btn_overlay_dismiss.setText("İtiraz Etme, Kapat")

        self.setWindowOpacity(0.97)
        self.showNormal()

        screen = QGuiApplication.primaryScreen()
        if screen:
            avail = screen.availableGeometry()
            if mode == "race_quest":
                # Sağ üstteki Widget penceresini 500x260 px boyutuna genişlet
                x = avail.right() - w - CONFIG.widget_margin_right
                y = avail.top() + CONFIG.widget_margin_top
            else:
                x = avail.left() + (avail.width() - w) // 2
                y = avail.top() + (avail.height() - h) // 2
            self.setGeometry(x, y, w, h)
        else:
            self.resize(w, h)

        self.raise_()
        try:
            set_window_topmost_no_activate(
                int(self.winId()),
                self.x(),
                self.y(),
                self.width(),
                self.height(),
            )
        except Exception:
            pass

    def _on_race_task_detected(self, task_row: dict) -> None:
        """
        Faz 4 Modül 4.1 ("⚡ İlk Kapar" Yarış Görevi Bildirimi):
        `tasks` tablosuna `is_first_come_race = True` ve `claimed_by = None` olan
        yeni bir görev düştüğünde; öğrenci `FREE_TIME` modunda tam ekran oyun
        oynuyor olsa bile sağ üstteki Widget penceresini 12 saniyeliğine
        `500x260 px` boyutuna (`HWND_TOPMOST`) genişletir.
        """
        if self.current_state in self.PASSIVE_EXEMPT_STATES:
            return
        self._active_race_task = task_row
        self.tts_announcer.announce(
            "Dikkat! Yeni bir yarış görevi açıldı, kardeşinden önce kap!"
        )
        if self.current_state not in self.LOCKED_STATES:
            self._expand_to_center_overlay_popup("race_quest")
            QTimer.singleShot(
                CONFIG.race_popup_duration_sec * 1000,
                lambda: (
                    self._shrink_from_overlay_popup()
                    if self.overlay_popup_mode == "race_quest"
                    else None
                ),
            )

    def _on_claim_race_task_clicked(self) -> None:
        """
        Öğrenci 500x260 px yarış popup'ındaki '🏃‍♂️ Ben Yaparım!' butonuna
        tıkladığında `claim_race_task_atomic` RPC'sini çağırır ve görevi kapar.
        """
        task = self._active_race_task
        self._shrink_from_overlay_popup()
        if not isinstance(task, dict) or not task.get("id"):
            return
        task_id = str(task["id"])

        def _worker():
            if not self.supabase:
                return
            try:
                res = self.supabase.rpc(
                    "claim_race_task_atomic",
                    {"p_task_id": task_id, "p_user_id": CONFIG.user_id},
                ).execute()
                data = res.data if isinstance(res.data, dict) else {}
                if data.get("ok", True):
                    self.signals.tts_announcement_requested.emit(
                        f"Tebrikler {self.student_name}! Yarış görevini kardeşinden önce sen kaptın!"
                    )
                else:
                    self.signals.tts_announcement_requested.emit(
                        "Maalesef bu yarış görevini kardeşin senden önce kaptı!"
                    )
            except Exception as err:
                print(f"[AgentUI] Yarış görevi kapma RPC hatası: {err}")

        threading.Thread(target=_worker, daemon=True).start()

    def _on_appeal_prompt_requested(self, violation_reason: str) -> None:
        """
        Faz 4 Modül 4.2 (Kalkan Kırılma Anında "Adalet Divanı (İtiraz)" Popup'ı):
        Ajan bir ihlal tespit edip kalkan kırdığında; eğer öğrencinin
        `appeal_used_today == False` ise pencereyi 15 saniyeliğine `550x380 px`
        boyutuna genişleterek "⚖️ Haksızlık mı oldu? İtiraz Et" arayüzünü gösterir.
        """
        if self.current_state in self.PASSIVE_EXEMPT_STATES:
            return
        if self.appeal_used_today:
            return
        self._last_violation_reason_for_appeal = violation_reason
        if self.current_state not in self.LOCKED_STATES:
            self._expand_to_center_overlay_popup("appeal_prompt")
            QTimer.singleShot(
                CONFIG.appeal_popup_duration_sec * 1000,
                lambda: (
                    self._shrink_from_overlay_popup()
                    if self.overlay_popup_mode == "appeal_prompt"
                    else None
                ),
            )

    def _on_open_appeal_clicked(self) -> None:
        """
        Öğrenci '⚖️ Haksızlık mı oldu? İtiraz Et' butonuna tıkladığında
        pencereyi 900x650 etkileşim moduna genişletip klavye/fare odağı verir.
        """
        self._transition_to_widget_mode(
            expanded=True,
            custom_size=(CONFIG.widget_expanded_width, CONFIG.widget_expanded_height),
            grant_focus=True,
        )

    def _on_tts_announcement_requested(self, message: str) -> None:
        if self.current_state in self.PASSIVE_EXEMPT_STATES:
            return
        self.tts_announcer.announce(message)

    def _shrink_from_overlay_popup(self) -> None:
        """
        20 saniyelik göz molası bittiğinde veya öğrenci '+3 Dk Uzatma Al' butonuna
        tıkladığında pencereyi tekrar sağ üst köşedeki küçük Widget boyutuna
        (`350x120 px`) küçültür.
        """
        if self.current_state in self.LOCKED_STATES:
            return
        self._transition_to_widget_mode(expanded=False)

    def _on_claim_grace_extension_clicked(self) -> None:
        """
        Öğrenci '+3 Dk Uzatma Al (10 Puan)' butonuna tıkladığında:
        1) Supabase `use_grace_period_extension` RPC'sini çağırır.
        2) Pencereyi hemen sağ üst köşedeki küçük Widget boyutuna (`350x120 px`) küçültür.
        """
        self.grace_used_today = True
        self._grace_extended_in_session = True
        self._shrink_from_overlay_popup()

        def _worker():
            if not self.supabase:
                return
            try:
                self.supabase.rpc(
                    "use_grace_period_extension",
                    {"p_user_id": CONFIG.user_id},
                ).execute()
            except Exception as err:
                print(f"[AgentUI] +3 Dk Uzatma RPC hatası: {err}")

        threading.Thread(target=_worker, daemon=True).start()

    def _on_voluntary_early_exit_clicked(self) -> None:
        """
        Öğrenci uzatma süresi bitmeden 'Kaydettim, Kendi İsteğimle Çıkıyorum'
        butonuna tıkladığında 10 puan iade + 5 irade bonusu (+15 puan) verir ve
        STUDY_TIME kilit moduna geçer.
        """
        self._grace_extended_in_session = False

        def _worker():
            if not self.supabase:
                return
            try:
                self.supabase.rpc(
                    "voluntary_early_lock_refund",
                    {"p_user_id": CONFIG.user_id},
                ).execute()
            except Exception as err:
                print(f"[AgentUI] İrade Eğitimi İade RPC hatası: {err}")

        threading.Thread(target=_worker, daemon=True).start()

    def _award_eye_break_health_points(self) -> None:
        """20 saniyelik göz ve duruş molası tamamlandığında +2 Sağlık Puanı verir."""
        def _worker():
            if not self.supabase:
                return
            try:
                new_pts = self.points_balance + 2
                self.supabase.table("users").update(
                    {"points_balance": new_pts}
                ).eq("id", CONFIG.user_id).execute()
            except Exception as err:
                print(f"[AgentUI] Göz molası puan ödülü hatası: {err}")

        threading.Thread(target=_worker, daemon=True).start()

    def _transition_to_fullscreen_lock_mode(self, is_offline_lock: bool = False) -> None:
        """
        STUDY_TIME, SLEEP_TIME, WAKE_UP_ALARM veya OFFLINE_LOCK moduna geçildiği anda
        tüm ekranı (çoklu monitör dahil) kaplar ve kısayolları kilitler.
        Sağ alt köşede '🔑 Ebeveyn PIN' butonunu gösterir.
        """
        self.keyboard_blocker.set_blocking(True)
        self.is_overlay_popup_active = False
        self.overlay_popup_mode = None
        self.widget_header.hide()
        self.game_overlay_card.hide()
        self.lock_bottom_bar.show()

        if is_offline_lock:
            self.web_view.hide()
            self.offline_lock_panel.show()
        else:
            self.offline_lock_panel.hide()
            self.web_view.show()

        self.setWindowOpacity(1.0)

        # Çoklu monitör varsa tüm sanal masaüstünü kapla, yoksa tam ekran aç
        screens = QGuiApplication.screens()
        if len(screens) > 1:
            virtual_rect = screens[0].virtualGeometry()
            self.showNormal()
            self.setGeometry(virtual_rect)
        else:
            self.showFullScreen()

        self.raise_()
        self.activateWindow()
        try:
            force_window_to_foreground(int(self.winId()))
        except Exception:
            pass

    def _toggle_widget_expansion(self) -> None:
        if self.current_state in self.LOCKED_STATES:
            return
        self._transition_to_widget_mode(expanded=not self.is_widget_expanded)

    def _open_offline_pin_dialog(self) -> None:
        """
        Sağ alt köşedeki '🔑 Ebeveyn PIN' butonuna tıklandığında 6 haneli
        SHA-256 doğrulamalı yerel kurtarma penceresini açar.
        """
        dlg = OfflinePinDialog(self)
        if dlg.exec() == QDialog.DialogCode.Accepted:
            # 1 saatlik (3600 sn) yerel serbest kullanım izni tanımla
            LOCAL_CACHE.grant_offline_unlock(CONFIG.offline_pin_unlock_duration_sec)
            self.previous_state = self.current_state
            self.current_state = "FREE_TIME"
            self.lbl_student.setText(f"🦁 {self.student_name} • 🔓 PIN İle Serbest (1 Saat)")
            self._transition_to_widget_mode(expanded=False)

            # İnternet varsa Supabase üzerinde de durumu FREE_TIME yap
            def _sync_unlock():
                if not self.supabase:
                    return
                try:
                    self.supabase.table("users").update(
                        {"current_state": "FREE_TIME", "state_ends_at": None}
                    ).eq("id", CONFIG.user_id).execute()
                except Exception:
                    pass

            threading.Thread(target=_sync_unlock, daemon=True).start()

    # --------------------------------------------------------------------------
    # 4. DURUM GÜNCELLEME VE DONANIM SES KONTROLÜ (PYCAW)
    # --------------------------------------------------------------------------
    def _apply_student_state(self, user_row: dict) -> None:
        remote_state = user_row.get("current_state", "FREE_TIME")

        # Eğer yerel Ebeveyn Offline PIN ile 1 saatlik serbest izin aktifse ve
        # uzaktan yeni bir kilit gelmediyse (veya çevrimdışı kilitteysek) koru:
        if LOCAL_CACHE.is_offline_pin_unlocked() and remote_state == "OFFLINE_LOCK":
            remote_state = "FREE_TIME"

        new_state = remote_state
        LOCAL_CACHE.update_last_known_state(new_state)

        # Whitelist yapılandırmasını güncelle ve yerel önbelleğe kaydet
        whitelist_cfg = user_row.get("whitelist_config")
        if isinstance(whitelist_cfg, dict):
            self.whitelist_enforcer.update_config(whitelist_cfg)
            LOCAL_CACHE.update_whitelist_config(whitelist_cfg)

        self.student_name = user_row.get("name", self.student_name)
        self.points_balance = int(user_row.get("points_balance", self.points_balance))
        self.daily_shields = int(user_row.get("daily_shields", self.daily_shields))
        self.grace_used_today = bool(user_row.get("grace_used_today", False))
        self.appeal_used_today = bool(user_row.get("appeal_used_today", False))
        new_ends_at = user_row.get("state_ends_at")
        if new_ends_at != self.state_ends_at:
            self._warned_2min_for_session = False
            self._prompted_30sec_for_session = False
        self.state_ends_at = new_ends_at

        shields_str = "🛡️" * self.daily_shields + "💔" * max(0, 3 - self.daily_shields)
        self.lbl_student.setText(f"🦁 {self.student_name} • {new_state}")
        self.lbl_stats.setText(
            f"⭐ {self.points_balance} Puan   |   {shields_str} ({self.daily_shields}/3)"
        )

        # Eğer durum WAKE_UP_ALARM olduysa:
        # 1) Kapalı monitörü uyandır (SetThreadExecutionState 0x80000003 + SC_MONITORPOWER + 1px mouse_event)
        # 2) pycaw ile Windows Master Volume'ü Mute'dan çıkar ve %80'e yükselt!
        state_changed = new_state != self.current_state
        if state_changed:
            if new_state == "WAKE_UP_ALARM":
                wake_up_monitor_for_alarm(self.input_tracker)
                enforce_master_volume(CONFIG.alarm_target_volume_scalar)
            elif new_state in self.AUDIO_BOOST_STATES:
                enforce_master_volume(CONFIG.alarm_target_volume_scalar)
            else:
                # WAKE_UP_ALARM dışındaki modlarda sistem derin uykuya girmesin (0x80000001)
                # ancak gece monitör ışığı doğal kapanabilsin:
                prevent_deep_sleep_allow_monitor_off()

            # Faz 4 Modül 2.4: Mod değişimlerinde Türkçe Sesli Anons (Audio Ducking ile)
            if new_state not in self.PASSIVE_EXEMPT_STATES:
                if new_state == "STUDY_TIME":
                    self.tts_announcer.announce(
                        f"Dikkat {self.student_name}! Odaklanma ve ders çalışma saati başladı. Başarılar dilerim!"
                    )
                elif new_state == "BREAK_TIME":
                    self.tts_announcer.announce(
                        f"Mola zamanı {self.student_name}! Aktif mola çarkını çevirmeyi unutma."
                    )
                elif new_state == "FREE_TIME" and self.current_state != "FREE_TIME":
                    self.tts_announcer.announce(
                        f"Serbest zaman başladı {self.student_name}! İyi eğlenceler."
                    )
                elif new_state == "ROUTINE_TIME":
                    self.tts_announcer.announce(
                        f"Günlük rutin zamanı başladı {self.student_name}!"
                    )
                elif new_state == "COMPUTER_STUDY":
                    self.tts_announcer.announce(
                        f"Bilgisayarlı ders modu başladı {self.student_name}. Sadece izin verilen ders araçları açık kalabilir."
                    )
                elif new_state == "CO_STUDY_MODE":
                    self.tts_announcer.announce(
                        f"Arkadaşla ders modu başladı {self.student_name}! Birlikte verimli çalışmalar."
                    )

        # Faz 4 Modül 5 - Tüm Fazların Durum (State) Matrisi Kontrolü:
        # - Tam Ekran Kilitlenenler: STUDY_TIME, ROUTINE_TIME, SLEEP_TIME, WAKE_UP_ALARM, OFFLINE_LOCK
        # - Masaüstü Widget Olarak Duranlar: FREE_TIME, BREAK_TIME (800x600 başlar), COMPUTER_STUDY, GUEST_MODE, FROZEN_HOLIDAY
        was_locked = self.current_state in self.LOCKED_STATES
        is_now_locked = new_state in self.LOCKED_STATES
        self.previous_state = self.current_state
        self.current_state = new_state

        if is_now_locked:
            self._transition_to_fullscreen_lock_mode(
                is_offline_lock=(new_state == "OFFLINE_LOCK")
            )
        elif new_state == "BREAK_TIME" and state_changed:
            # Faz 4 Modül 4.3 & 5: Durum BREAK_TIME olduğunda Aktif Mola Ruleti için 800x600 px başlar
            self._expand_for_break_roulette()
        elif was_locked and not is_now_locked:
            self._transition_to_widget_mode(expanded=False)

    # --------------------------------------------------------------------------
    # 5. ZAMANLAYICILAR: TOPMOST ZORLAMA, BEYAZ LİSTE, SAYAC VE İHLAL SENSÖRÜ
    # --------------------------------------------------------------------------
    def _setup_timers(self) -> None:
        # 1) Her 150ms'de bir Görev Yöneticisi kapatma & Topmost zorlama
        self.enforcer_timer = QTimer(self)
        self.enforcer_timer.timeout.connect(self._on_enforcer_tick)
        self.enforcer_timer.start(CONFIG.enforcer_tick_ms)

        # 2) Her 1 saniyede bir sayaç, GetLastInputInfo sensörü ve Offline Guard kontrolü
        self.second_timer = QTimer(self)
        self.second_timer.timeout.connect(self._on_second_tick)
        self.second_timer.start(1000)

        # 3) Faz 2: Her 1.5 saniyede bir COMPUTER_STUDY Beyaz Liste (Whitelist) denetimi
        self.whitelist_timer = QTimer(self)
        self.whitelist_timer.timeout.connect(self._on_whitelist_tick)
        self.whitelist_timer.start(CONFIG.whitelist_check_interval_ms)

    def _on_enforcer_tick(self) -> None:
        if self.current_state not in self.LOCKED_STATES:
            return

        # Görev Yöneticisi (Taskmgr.exe) açıldıysa anında kapat ve ihlal yaz!
        if terminate_task_manager_if_running():
            self._record_violation_with_cooldown("pc_key_press")

        # Pencereyi zorla en üstte tut
        try:
            force_window_to_foreground(int(self.winId()))
        except Exception:
            pass

    def _on_whitelist_tick(self) -> None:
        """
        Faz 2 Modül 1 & 2:
        - GUEST_MODE veya FROZEN_HOLIDAY aktifken Beyaz Liste denetleyicisi tamamen durur.
        - Sadece COMPUTER_STUDY modundayken her 1.5 saniyede bir aktif pencereyi denetler.
        """
        if self.current_state in self.PASSIVE_EXEMPT_STATES:
            return
        if self.current_state != "COMPUTER_STUDY":
            return

        own_hwnds: set[int] = set()
        try:
            own_hwnds.add(int(self.winId()))
            own_hwnds.add(int(self.warning_bubble.winId()))
            own_hwnds.add(int(self.noise_banner.winId()))
        except Exception:
            pass

        violation = self.whitelist_enforcer.inspect_and_enforce(own_hwnds=own_hwnds)
        if violation:
            blocked_app = violation.get("display_app", "İzinsiz Uygulama")
            # 1) Pencere zaten WhitelistEnforcer içinde SW_MINIMIZE ile aşağı indirildi.
            # 2) PyQt6 üzerinden ekranda 4 saniyelik her şeyin üstünde duran uyarı baloncuğu göster:
            self.warning_bubble.show_warning(blocked_app, duration_ms=4000)
            # 3) 30 saniye cooldown ile Supabase violation_logs tablosuna `unauthorized_app_opened`
            #    kaydı ve açılan uygulamanın adını gönder:
            self._record_unauthorized_app_violation(blocked_app)

    def _on_second_tick(self) -> None:
        # 0) Faz 3 Modül 3: Gece 00:00 (veya yeni gün) olduğunda grace_used_today ve
        #    daily_shields (3 Kalkan) değerlerinin sıfırlandığından emin ol
        self._ensure_daily_reset_if_new_day()

        # A) Anti-Cheat: İnternet Kesintisi Koruması (Offline Guard - 60 sn)
        elapsed_offline = time.time() - self._last_supabase_ok_epoch
        last_known = LOCAL_CACHE.get_last_known_state()
        if (
            elapsed_offline >= CONFIG.offline_timeout_sec
            and self.current_state != "OFFLINE_LOCK"
            and last_known != "FROZEN_HOLIDAY"
            and not LOCAL_CACHE.is_offline_pin_unlocked()
        ):
            print(
                f"[OfflineGuard] {int(elapsed_offline)} saniyedir Supabase'e ulaşılamıyor! "
                "OFFLINE_LOCK güvenli kilit ekranı devreye alınıyor..."
            )
            self.previous_state = self.current_state
            self.current_state = "OFFLINE_LOCK"
            self._transition_to_fullscreen_lock_mode(is_offline_lock=True)
            return

        # B) Geri sayım etiketi güncelleme & Faz 3 Oyun Üstü Uzatma Jokeri Overlay kontrolü
        if self.current_state == "OFFLINE_LOCK":
            self.lbl_timer.setText("🌐 OFFLINE KİLİT")
        elif self.current_state == "GUEST_MODE":
            self.lbl_timer.setText("🎮 MİSAFİR")
        elif self.current_state == "FROZEN_HOLIDAY":
            self.lbl_timer.setText("🏖️ TATİL")
        elif self.state_ends_at:
            try:
                end_dt = datetime.fromisoformat(self.state_ends_at.replace("Z", "+00:00"))
                rem = max(0, int((end_dt - datetime.now(timezone.utc)).total_seconds()))
                mins, secs = divmod(rem, 60)
                prefix = "💻" if self.current_state == "COMPUTER_STUDY" else "⏱️"
                self.lbl_timer.setText(f"{prefix} {mins:02d}:{secs:02d}")

                # Faz 3 Modül 1 & Faz 4 Modül 2.4: FREE_TIME bitimine 2 dakika (120 sn) ve 30 saniye kaldığında
                # odak çalmadan 600x350 merkezî Top-Most Overlay aç ve Türkçe TTS anonsu yap!
                if self.current_state == "FREE_TIME":
                    if 115 <= rem <= 120 and not self._warned_2min_for_session:
                        self._warned_2min_for_session = True
                        self.tts_announcer.announce(
                            f"Dikkat {self.student_name}! Serbest zamanın bitmesine iki dakika kaldı, oyununu kaydetmeye hazırlan."
                        )
                        self._expand_to_center_overlay_popup("grace_2min")
                        QTimer.singleShot(
                            8000,
                            lambda: (
                                self._shrink_from_overlay_popup()
                                if self.overlay_popup_mode == "grace_2min"
                                else None
                            ),
                        )
                    elif 0 < rem <= 30 and not self._prompted_30sec_for_session:
                        self._prompted_30sec_for_session = True
                        if not self.grace_used_today or self._grace_extended_in_session:
                            self._expand_to_center_overlay_popup("grace_30sec")
            except Exception:
                self.lbl_timer.setText(self.current_state)
        else:
            if LOCAL_CACHE.is_offline_pin_unlocked():
                rem_unlock = LOCAL_CACHE.remaining_offline_unlock_seconds()
                m, s = divmod(rem_unlock, 60)
                self.lbl_timer.setText(f"🔓 PIN {m:02d}:{s:02d}")
            else:
                self.lbl_timer.setText(
                    "🟢 FREE" if self.current_state == "FREE_TIME" else self.current_state
                )

        # C) Faz 2 Modül 2, Faz 4 & Faz 5:
        # - GUEST_MODE veya FROZEN_HOLIDAY aktifken klavye/fare sensörü, gürültü sensörü ve TTS kapalıdır.
        # - CO_STUDY_MODE aktifken iki arkadaş birlikte çalışırken konuşabilmesi ve soru çözebilmesi
        #   için gürültü sensörü ve girdi dokunma sensörü devre dışı bırakılır / esnetilir.
        if self.current_state in self.PASSIVE_EXEMPT_STATES:
            self.noise_monitor.set_monitoring_enabled(False)
            self.tts_announcer.set_enabled(False)
            return
        elif self.current_state == "CO_STUDY_MODE":
            self.noise_monitor.set_monitoring_enabled(False)
            self.tts_announcer.set_enabled(self.tts_announcements_enabled)
        else:
            self.noise_monitor.set_monitoring_enabled(True)
            self.tts_announcer.set_enabled(self.tts_announcements_enabled)

        # C2) Faz 3 Modül 1: 20-20-20 Göz ve Duruş Molası Sayacı (FREE_TIME ve COMPUTER_STUDY)
        if self.current_state in ("FREE_TIME", "COMPUTER_STUDY"):
            if self._eye_break_countdown_sec > 0:
                self._eye_break_countdown_sec -= 1
                if self.overlay_popup_mode == "eye_break":
                    self.lbl_overlay_title.setText(
                        f"👁️ Gözlerini Dinlendir & Sırtını Dikleştir! ({self._eye_break_countdown_sec} sn)"
                    )
                if self._eye_break_countdown_sec <= 0:
                    # 20 saniyelik göz molası tamamlandı -> +2 puan ver ve 350x120 sağ üst Widget'a küçült!
                    self._award_eye_break_health_points()
                    if self.overlay_popup_mode == "eye_break":
                        self._shrink_from_overlay_popup()
            else:
                self._eye_break_elapsed_sec += 1
                if self._eye_break_elapsed_sec >= CONFIG.eye_break_interval_sec:
                    self._eye_break_elapsed_sec = 0
                    self._eye_break_countdown_sec = CONFIG.eye_break_duration_sec
                    self._expand_to_center_overlay_popup("eye_break")

        # D) STUDY_TIME veya SLEEP_TIME sırasında GetLastInputInfo sensörü
        if self.current_state in ("STUDY_TIME", "SLEEP_TIME"):
            v_type = self.input_tracker.detect_violation_input_type()
            if v_type:
                if self.current_state == "SLEEP_TIME" or not self.isActiveWindow():
                    self._record_violation_with_cooldown(v_type)

    def _on_blocked_os_shortcut(self, shortcut_name: str) -> None:
        """Öğrenci Alt+Tab, Alt+F4, Win tuşu vb. bastığında ihlal kaydet."""
        if self.current_state in self.PASSIVE_EXEMPT_STATES or self.current_state == "CO_STUDY_MODE":
            return
        print(f"[Enforcer] Engellenen kısayol yakalandı: {shortcut_name}")
        self._record_violation_with_cooldown("pc_key_press")

    def _record_unauthorized_app_violation(self, opened_app_name: str) -> None:
        """
        30 saniye cooldown ile Supabase `violation_logs` tablosuna
        `unauthorized_app_opened` kaydı ve açılan uygulamanın adını gönderir.
        """
        now = time.time()
        if now - self._last_whitelist_violation_epoch < CONFIG.violation_cooldown_sec:
            return
        self._last_whitelist_violation_epoch = now

        # Faz 4 Modül 4.2: Kalkan kırılma anında appeal_used_today == False ise
        # 15 saniyeliğine 550x380 px Adalet Divanı (İtiraz) Popup'ı göster
        if not self.appeal_used_today:
            self.signals.appeal_prompt_requested.emit(
                f"Bilgisayarlı Ders İhlali (unauthorized_app_opened): {opened_app_name}"
            )

        def _worker():
            if not self.supabase:
                return
            try:
                # 1) Atomik RPC ile kalkan düşür ve ihlal kaydet
                self.supabase.rpc(
                    "record_violation_and_break_shield",
                    {
                        "p_user_id": CONFIG.user_id,
                        "p_device_id": CONFIG.device_id,
                        "p_violation_type": "unauthorized_app_opened",
                    },
                ).execute()
                # 2) Ebeveyne açılan izinsiz uygulamanın tam adını bildirim mesajı olarak ilet
                self.supabase.table("messages").insert(
                    {
                        "id": f"msg-wl-{int(time.time())}",
                        "family_id": CONFIG.family_id,
                        "sender_id": CONFIG.user_id,
                        "receiver_id": CONFIG.parent_receiver_id,
                        "message_type": "text",
                        "content": f"⚠️ [Bilgisayarlı Ders İhlali - unauthorized_app_opened] İzinsiz açılan uygulama küçültüldü: {opened_app_name}",
                        "is_read": False,
                    }
                ).execute()
            except Exception as err:
                print(f"[AgentUI] Whitelist ihlal kayıt hatası: {err}")

        threading.Thread(target=_worker, daemon=True).start()

    def _record_violation_with_cooldown(self, violation_type: str) -> None:
        """
        Spam önlemek için maksimum 30 saniyede bir (CONFIG.violation_cooldown_sec)
        Supabase `record_violation_and_break_shield` RPC'sini çağırır.
        """
        if self.current_state in self.PASSIVE_EXEMPT_STATES:
            return
        now = time.time()
        if now - self._last_violation_epoch < CONFIG.violation_cooldown_sec:
            return
        self._last_violation_epoch = now

        # Faz 4 Modül 4.2: Kalkan kırılma anında appeal_used_today == False ise
        # 15 saniyeliğine 550x380 px Adalet Divanı (İtiraz) Popup'ı göster
        if not self.appeal_used_today:
            self.signals.appeal_prompt_requested.emit(
                f"Kilit Ekranı Girdi İhlali ({violation_type})"
            )

        def _worker():
            if not self.supabase:
                return
            try:
                self.supabase.rpc(
                    "record_violation_and_break_shield",
                    {
                        "p_user_id": CONFIG.user_id,
                        "p_device_id": CONFIG.device_id,
                        "p_violation_type": violation_type,
                    },
                ).execute()
            except Exception as err:
                print(f"[AgentUI] İhlal kayıt hatası: {err}")

        threading.Thread(target=_worker, daemon=True).start()

    def _on_high_noise_detected(self, measured_db: int) -> None:
        """
        Faz 3 Modül 2 (Donanımsal Gürültü / Bağırma Sensörü):
        Odadaki ses seviyesi 8 saniye kesintisiz `family_settings.noise_threshold_db`
        eşiğini aştığında:
        1) Ekranda 5 saniyelik yarı saydam PyQt6 uyarı bandı gösterir:
           "🔊 Ses seviyesi çok yükseldi! Lütfen daha sakin olalım."
        2) 60 saniye cooldown ile Supabase `violation_logs` tablosuna
           `high_noise_detected` kaydı gönderir.
        Faz 5: CO_STUDY_MODE aktifken arkadaşla ders çalışma sırasında gürültü ihlali yazılmaz.
        """
        if self.current_state in self.PASSIVE_EXEMPT_STATES or self.current_state == "CO_STUDY_MODE":
            return

        threshold_db = LOCAL_CACHE.get_noise_threshold_db()
        self.noise_banner.show_noise_warning(
            measured_db=measured_db,
            threshold_db=threshold_db,
            duration_ms=5000,
        )

        now = time.time()
        if now - self._last_noise_violation_epoch < CONFIG.noise_violation_cooldown_sec:
            return
        self._last_noise_violation_epoch = now

        # Faz 4 Modül 4.2: Kalkan kırılma anında appeal_used_today == False ise
        # 15 saniyeliğine 550x380 px Adalet Divanı (İtiraz) Popup'ı göster
        if not self.appeal_used_today:
            self.signals.appeal_prompt_requested.emit(
                f"Yüksek Gürültü Algılandı ({measured_db} dB > {threshold_db} dB - high_noise_detected)"
            )

        def _worker():
            if not self.supabase:
                return
            try:
                self.supabase.rpc(
                    "record_violation_and_break_shield",
                    {
                        "p_user_id": CONFIG.user_id,
                        "p_device_id": CONFIG.device_id,
                        "p_violation_type": "high_noise_detected",
                    },
                ).execute()
            except Exception as err:
                print(f"[AgentUI] Gürültü ihlali kayıt hatası: {err}")

        threading.Thread(target=_worker, daemon=True).start()

    def _ensure_daily_reset_if_new_day(self) -> None:
        """
        Faz 3 Modül 3 (Günlük Sıfırlama):
        Gece saat 00:00 olduğunda (veya ajan sabah ilk kez açıldığında) öğrencinin
        `grace_used_today` (Uzatma Jokeri) ve `daily_shields` (3 Kalkan) değerlerinin
        yeni gün için sıfırlandığından emin olur.
        """
        today_str = datetime.now().strftime("%Y-%m-%d")
        if LOCAL_CACHE.get_last_daily_reset_date() == today_str:
            return

        LOCAL_CACHE.set_last_daily_reset_date(today_str)
        self.grace_used_today = False
        self.appeal_used_today = False
        self.daily_shields = 3
        self._warned_2min_for_session = False
        self._prompted_30sec_for_session = False
        self._grace_extended_in_session = False

        def _reset_worker():
            if not self.supabase:
                return
            try:
                self.supabase.table("users").update(
                    {
                        "grace_used_today": False,
                        "appeal_used_today": False,
                        "daily_shields": 3,
                    }
                ).eq("id", CONFIG.user_id).execute()
                print(
                    f"[DailyReset] Yeni gün ({today_str}) için grace_used_today=False, appeal_used_today=False ve daily_shields=3 sıfırlandı."
                )
            except Exception as err:
                print(f"[DailyReset] Günlük sıfırlama hatası: {err}")

        threading.Thread(target=_reset_worker, daemon=True).start()

        # Faz 5 Modül 3.2: Günlük Otomatik Görev Üretimi RPC Çağrısı
        self._spawn_daily_recurring_tasks_rpc()

    def _spawn_daily_recurring_tasks_rpc(self) -> None:
        """
        Faz 5 Modül 3.2 (Günlük Otomatik Görev ve Kalkan Üretimi):
        Sabah ilk açılışta veya gece 00:01 geçişinde Supabase spawn_daily_recurring_tasks()
        RPC fonksiyonunu tetikleyerek o günün görevlerinin ve kalkanlarının hazır olduğundan emin olur.
        """
        def _worker():
            if not self.supabase:
                return
            try:
                self.supabase.rpc(
                    "spawn_daily_recurring_tasks",
                    {"p_family_id": CONFIG.family_id},
                ).execute()
                print("[DailyTasks] spawn_daily_recurring_tasks RPC başarıyla tetiklendi.")
            except Exception as err:
                print(f"[DailyTasks] spawn_daily_recurring_tasks RPC hatası: {err}")

        threading.Thread(target=_worker, daemon=True).start()

    # --------------------------------------------------------------------------
    # 6. SUPABASE DURUM DİNLEYİCİSİ, FAZ 4 ANONS/POPUP TETİKLEYİCİLERİ & KOMUTLAR
    # --------------------------------------------------------------------------
    def _supabase_state_listener_loop(self) -> None:
        while self._running:
            if not self.supabase:
                self._init_supabase_client()
                time.sleep(5)
                continue

            try:
                # 1) Öğrencinin güncel durumunu çek
                res = (
                    self.supabase.table("users")
                    .select("*")
                    .eq("id", CONFIG.user_id)
                    .single()
                    .execute()
                )
                if res.data:
                    self._last_supabase_ok_epoch = time.time()
                    self.signals.connection_status_changed.emit(True)
                    self.signals.state_updated.emit(res.data)

                # 2) Faz 2, 3 & 4: `family_settings` içinden `offline_master_pin_hash`,
                #    `noise_threshold_db`, `tts_announcements_enabled`,
                #    `happy_hour_discount_percent`, `happy_hour_ends_at` çek
                try:
                    fs_res = (
                        self.supabase.table("family_settings")
                        .select(
                            "offline_master_pin_hash, noise_threshold_db, "
                            "tts_announcements_enabled, happy_hour_discount_percent, happy_hour_ends_at"
                        )
                        .eq("family_id", CONFIG.family_id)
                        .limit(1)
                        .execute()
                    )
                    if fs_res.data and len(fs_res.data) > 0:
                        fs_row = fs_res.data[0]
                        pin_hash = fs_row.get("offline_master_pin_hash")
                        LOCAL_CACHE.update_pin_hash(pin_hash)

                        noise_db = fs_row.get("noise_threshold_db")
                        if noise_db is not None:
                            LOCAL_CACHE.update_noise_threshold_db(int(noise_db))
                            self.noise_monitor.set_threshold_db(int(noise_db))

                        tts_enabled = fs_row.get("tts_announcements_enabled")
                        if isinstance(tts_enabled, bool):
                            self.tts_announcements_enabled = tts_enabled
                            LOCAL_CACHE.update_tts_announcements_enabled(tts_enabled)
                            if self.current_state not in self.PASSIVE_EXEMPT_STATES:
                                self.tts_announcer.set_enabled(tts_enabled)

                        # Faz 4 Modül 2.3: Market Happy Hour indirimi başladığında sesli anons
                        hh_discount = int(fs_row.get("happy_hour_discount_percent") or 0)
                        hh_ends = fs_row.get("happy_hour_ends_at")
                        if hh_discount > 0 and hh_ends:
                            hh_key = f"{hh_discount}:{hh_ends}"
                            try:
                                ends_dt = datetime.fromisoformat(
                                    str(hh_ends).replace("Z", "+00:00")
                                )
                                if ends_dt > datetime.now(timezone.utc):
                                    if (
                                        self._poller_bootstrapped
                                        and hh_key != self._last_announced_happy_hour_key
                                    ):
                                        self._last_announced_happy_hour_key = hh_key
                                        self.signals.tts_announcement_requested.emit(
                                            f"Sürpriz İndirim Saati başladı! Ödül marketinde yüzde {hh_discount} indirim var!"
                                        )
                                    elif not self._poller_bootstrapped:
                                        self._last_announced_happy_hour_key = hh_key
                            except Exception:
                                pass
                except Exception:
                    pass

                # 2B) Faz 4 Modül 2.1 & 4.1: Yeni bir "⚡ İlk Kapar Görev Yarışı"
                #     (`is_first_come_race = True`, `claimed_by = None`) eklendiğinde
                #     12 sn 500x260 px Popup + Türkçe TTS anonsu tetikle
                try:
                    race_res = (
                        self.supabase.table("tasks")
                        .select("*")
                        .eq("family_id", CONFIG.family_id)
                        .eq("is_first_come_race", True)
                        .is_("claimed_by", "null")
                        .eq("is_active", True)
                        .order("created_at", desc=True)
                        .limit(5)
                        .execute()
                    )
                    if race_res.data:
                        for task_row in race_res.data:
                            t_id = str(task_row.get("id") or "")
                            if not t_id:
                                continue
                            if not self._poller_bootstrapped:
                                self._seen_race_task_ids.add(t_id)
                            elif t_id not in self._seen_race_task_ids:
                                self._seen_race_task_ids.add(t_id)
                                self.signals.race_task_detected.emit(task_row)
                except Exception:
                    pass

                # 2C) Faz 4 Modül 2.2: Öğrencinin gönderdiği bir görev (`task_submissions`)
                #     veya Adalet Divanı İtirazı (`appeals`) onaylandığında Türkçe TTS anonsu
                try:
                    sub_res = (
                        self.supabase.table("task_submissions")
                        .select("id, status")
                        .eq("user_id", CONFIG.user_id)
                        .eq("status", "approved")
                        .order("created_at", desc=True)
                        .limit(10)
                        .execute()
                    )
                    if sub_res.data:
                        for s_row in sub_res.data:
                            s_id = str(s_row.get("id") or "")
                            if not s_id:
                                continue
                            if not self._poller_bootstrapped:
                                self._seen_approved_submission_ids.add(s_id)
                            elif s_id not in self._seen_approved_submission_ids:
                                self._seen_approved_submission_ids.add(s_id)
                                self.signals.tts_announcement_requested.emit(
                                    "Görevin onaylandı, puanların yüklendi!"
                                )
                except Exception:
                    pass

                try:
                    app_res = (
                        self.supabase.table("appeals")
                        .select("id, status")
                        .eq("user_id", CONFIG.user_id)
                        .eq("status", "approved")
                        .order("created_at", desc=True)
                        .limit(10)
                        .execute()
                    )
                    if app_res.data:
                        for a_row in app_res.data:
                            a_id = str(a_row.get("id") or "")
                            if not a_id:
                                continue
                            if not self._poller_bootstrapped:
                                self._seen_approved_appeal_ids.add(a_id)
                            elif a_id not in self._seen_approved_appeal_ids:
                                self._seen_approved_appeal_ids.add(a_id)
                                self.signals.tts_announcement_requested.emit(
                                    "Harika haber! İtirazın kabul edildi ve kalkanın tamir edildi!"
                                )
                except Exception:
                    pass

                self._poller_bootstrapped = True

                # 3) Ebeveynden gelen uzaktan "[CMD:SCREENSHOT]" komutu var mı kontrol et
                cmd_res = (
                    self.supabase.table("messages")
                    .select("*")
                    .eq("receiver_id", CONFIG.user_id)
                    .eq("is_read", False)
                    .like("content", "%[CMD:SCREENSHOT]%")
                    .order("created_at", desc=True)
                    .limit(1)
                    .execute()
                )
                if cmd_res.data:
                    cmd_msg = cmd_res.data[0]
                    cmd_id = cmd_msg["id"]
                    if cmd_id not in self._processed_command_ids:
                        self._processed_command_ids.add(cmd_id)
                        # Komutu okundu işaretle
                        self.supabase.table("messages").update(
                            {"is_read": True}
                        ).eq("id", cmd_id).execute()
                        # Ekran görüntüsü alma sinyalini tetikle
                        self.signals.remote_screenshot_requested.emit(
                            cmd_msg.get("sender_id", CONFIG.parent_receiver_id)
                        )

            except Exception as err:
                print(f"[AgentUI] Supabase dinleme hatası (yeniden bağlanılacak): {err}")
                self.signals.connection_status_changed.emit(False)
                time.sleep(3)

            time.sleep(CONFIG.state_poll_interval_sec)

    # --------------------------------------------------------------------------
    # 7. HEARTBEAT (15 SN) & AKTİF PENCERE BAŞLIĞI GÖNDERİMİ
    # --------------------------------------------------------------------------
    def _heartbeat_worker_loop(self) -> None:
        while self._running:
            if self.supabase:
                try:
                    win_title = get_active_window_title()
                    now_iso = datetime.now(timezone.utc).isoformat()
                    self.supabase.table("devices").upsert(
                        {
                            "id": CONFIG.device_id,
                            "family_id": CONFIG.family_id,
                            "user_id": CONFIG.user_id,
                            "device_name": CONFIG.device_name,
                            "device_type": "windows_pc",
                            "is_online": True,
                            "last_heartbeat": now_iso,
                            "last_activity_at": now_iso,
                            "active_window_title": win_title,
                        }
                    ).execute()
                    self._last_supabase_ok_epoch = time.time()
                except Exception as err:
                    print(f"[AgentUI] Heartbeat gönderim hatası: {err}")

            time.sleep(CONFIG.heartbeat_interval_sec)

    # --------------------------------------------------------------------------
    # 8. UZAKTAN ANLIK EKRAN GÖRÜNTÜSÜ ALIP SUPABASE STORAGE'A YÜKLEME (mss)
    # --------------------------------------------------------------------------
    def _handle_remote_screenshot(self, parent_id: str) -> None:
        def _capture_and_upload():
            if not self.supabase:
                return
            png_bytes = capture_screen_to_png_bytes()
            if not png_bytes:
                return

            file_name = f"pc-screenshots/{CONFIG.device_id}-{int(time.time())}.png"
            public_url: Optional[str] = None

            try:
                self.supabase.storage.from_(CONFIG.screenshot_bucket).upload(
                    path=file_name,
                    file=png_bytes,
                    file_options={"content-type": "image/png", "upsert": "true"},
                )
                public_url = self.supabase.storage.from_(
                    CONFIG.screenshot_bucket
                ).get_public_url(file_name)
            except Exception as storage_err:
                print(f"[AgentUI] Storage yükleme yedek moduna geçiliyor: {storage_err}")
                b64 = base64.b64encode(png_bytes).decode("ascii")
                public_url = f"data:image/png;base64,{b64}"

            # Ebeveyne bildirim ve ekran görüntüsü bağlantısını gönder
            try:
                win_title = get_active_window_title()
                self.supabase.table("messages").insert(
                    {
                        "id": f"msg-scr-{int(time.time())}",
                        "family_id": CONFIG.family_id,
                        "sender_id": CONFIG.user_id,
                        "receiver_id": parent_id,
                        "message_type": "text",
                        "content": f"📸 [PC Ekran Görüntüsü Alındı] Aktif Pencere: {win_title} -> {public_url}",
                        "is_read": False,
                    }
                ).execute()
            except Exception as msg_err:
                print(f"[AgentUI] Ekran görüntüsü mesaj hatası: {msg_err}")

        threading.Thread(target=_capture_and_upload, daemon=True).start()

    def _on_connection_status(self, connected: bool) -> None:
        if not connected and self.current_state != "OFFLINE_LOCK":
            self.lbl_timer.setText("⚠️ Bağlanıyor...")

    # --------------------------------------------------------------------------
    # 9. WIDGET SÜRÜKLEME VE ALT+F4 KAPATMA KORUMASI
    # --------------------------------------------------------------------------
    def mousePressEvent(self, event) -> None:
        if (
            self.current_state not in self.LOCKED_STATES
            and event.button() == Qt.MouseButton.LeftButton
        ):
            self._drag_offset = (
                event.globalPosition().toPoint() - self.frameGeometry().topLeft()
            )
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event) -> None:
        if (
            self._drag_offset is not None
            and self.current_state not in self.LOCKED_STATES
            and event.buttons() & Qt.MouseButton.LeftButton
        ):
            self.move(event.globalPosition().toPoint() - self._drag_offset)
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event) -> None:
        self._drag_offset = None
        super().mouseReleaseEvent(event)

    def keyPressEvent(self, event: QKeyEvent) -> None:
        # Kilit modundayken Escape veya Alt+F4 tuşlarını yut
        if self.current_state in self.LOCKED_STATES:
            if event.key() in (Qt.Key.Key_Escape, Qt.Key.Key_F4):
                event.ignore()
                return
        super().keyPressEvent(event)

    def closeEvent(self, event: QCloseEvent) -> None:
        """Öğrencinin pencereyi kapatmasını engeller."""
        if not self.allow_exit:
            event.ignore()
            self._record_violation_with_cooldown("pc_key_press")
        else:
            self._running = False
            try:
                self.noise_monitor.stop()
            except Exception:
                pass
            try:
                self.tts_announcer.stop()
            except Exception:
                pass
            try:
                self.ota_updater.stop()
            except Exception:
                pass
            event.accept()
