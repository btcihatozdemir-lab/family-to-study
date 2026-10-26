"""
===============================================================================
pairing_dialog.py - FAZ 6: WINDOWS AJANI 6 HANELİ CİHAZ EŞLEŞTİRME EKRANI
===============================================================================
Masaüstünde uzun URL, e-posta veya şifre yazma zorluğunu ortadan kaldırır.
İlk kurulumda veya `device_auth.json` bulunmadığında ekranın ortasında şık bir
PyQt6 diyalogu açarak ebeveynin panelinden ürettiği 6 haneli kodu ister.
Supabase RPC `verify_desktop_pairing_code` ile doğrulayıp kalıcı mühürler.
===============================================================================
"""

from __future__ import annotations

import sys
from typing import Optional

try:
    from PyQt6.QtCore import Qt
    from PyQt6.QtGui import QGuiApplication, QFont
    from PyQt6.QtWidgets import (
        QDialog,
        QWidget,
        QVBoxLayout,
        QHBoxLayout,
        QLabel,
        QLineEdit,
        QPushButton,
        QFrame,
    )
except ImportError:
    # Test ortamları ve Linux başsız çalıştırma için dummy sınıflar
    class QDialog:  # type: ignore
        def __init__(self, *args, **kwargs): pass
        def exec(self): return 1
        def accept(self): pass
        def reject(self): pass
    class QWidget: pass  # type: ignore

from config import (
    BASE_DIR,
    CONFIG,
    LOCAL_CACHE,
    has_device_auth,
    save_device_auth,
)


class DevicePairingDialog(QDialog):
    """
    6 Haneli Eşleştirme Kodu ile Cihaz Bağlama Diyalog Penceresi.
    """

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("FamilyOS • Bilgisayar Eşleştirme (Faz 6)")
        self.setFixedSize(480, 310)
        self._setup_style()
        self._build_ui()

    def _setup_style(self) -> None:
        self.setStyleSheet("""
            QDialog {
                background-color: #0b1120;
                color: #ffffff;
                font-family: 'Segoe UI', Arial, sans-serif;
                border: 2px solid #312e81;
                border-radius: 20px;
            }
            QLabel {
                color: #e2e8f0;
            }
            QLineEdit {
                background-color: #020617;
                border: 2px solid #6366f1;
                border-radius: 14px;
                padding: 12px;
                color: #38bdf8;
                font-size: 24px;
                font-weight: 900;
                letter-spacing: 6px;
                text-align: center;
            }
            QLineEdit:focus {
                border: 2px solid #a855f7;
                background-color: #030712;
            }
            QPushButton#btnSubmit {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #4f46e5, stop:1 #9333ea);
                border: none;
                border-radius: 14px;
                padding: 13px;
                color: #ffffff;
                font-size: 14px;
                font-weight: 900;
            }
            QPushButton#btnSubmit:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #4338ca, stop:1 #7e22ce);
            }
            QPushButton#btnSubmit:disabled {
                background-color: #334155;
                color: #94a3b8;
            }
        """)

    def _build_ui(self) -> None:
        layout = QVBoxLayout(self)
        layout.setContentsMargins(32, 26, 32, 26)
        layout.setSpacing(12)

        # Başlık ve İkon
        header_layout = QHBoxLayout()
        icon_lbl = QLabel("🖥️")
        icon_lbl.setStyleSheet("font-size: 26px; border: none;")
        header_layout.addWidget(icon_lbl)

        title_box = QVBoxLayout()
        title_box.setSpacing(2)
        title_lbl = QLabel("FamilyOS Bilgisayar Eşleştirme")
        title_lbl.setStyleSheet("font-size: 17px; font-weight: 900; color: #ffffff;")
        title_box.addWidget(title_lbl)

        sub_lbl = QLabel("Tek Seferlik 6 Haneli Cihaz Bağlama (Faz 6)")
        sub_lbl.setStyleSheet("font-size: 11px; font-weight: 700; color: #818cf8; text-transform: uppercase;")
        title_box.addWidget(sub_lbl)
        header_layout.addLayout(title_box)
        header_layout.addStretch()
        layout.addLayout(header_layout)

        # Açıklama metni
        desc_lbl = QLabel(
            "Ebeveyn panelinizde öğrencinin kartında yer alan 6 haneli Masaüstü Kodunu girin (Örn: 849-201):"
        )
        desc_lbl.setWordWrap(True)
        desc_lbl.setStyleSheet("font-size: 12px; color: #94a3b8; line-height: 1.4;")
        layout.addWidget(desc_lbl)

        # 6 Haneli Kod Girişi
        self.input_code = QLineEdit()
        self.input_code.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.input_code.setPlaceholderText("849-201")
        self.input_code.setMaxLength(8)
        self.input_code.textChanged.connect(self._format_input)
        layout.addWidget(self.input_code)

        # Hata / Durum Bildirimi
        self.lbl_status = QLabel("")
        self.lbl_status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_status.setStyleSheet("font-size: 11px; color: #f43f5e; font-weight: bold; min-height: 16px;")
        layout.addWidget(self.lbl_status)

        # Gönder Butonu
        self.btn_submit = QPushButton("Cihazı Öğrenciye Bağla ve Başlat")
        self.btn_submit.setObjectName("btnSubmit")
        self.btn_submit.clicked.connect(self._handle_submit)
        layout.addWidget(self.btn_submit)

        # Bilgilendirme Notu
        info_footer = QLabel("🔒 Bir kez bağlandığında cihaz kalıcı mühürlenir; bir daha asla şifre sormaz.")
        info_footer.setAlignment(Qt.AlignmentFlag.AlignCenter)
        info_footer.setStyleSheet("font-size: 10px; color: #64748b; font-style: italic;")
        layout.addWidget(info_footer)

    def _format_input(self, text: str) -> None:
        """Kullanıcı sadece rakam girse de 3. rakamdan sonra otomatik tire ekler."""
        digits = "".join([c for c in text if c.isdigit()])
        if len(digits) > 6:
            digits = digits[:6]

        formatted = digits
        if len(digits) > 3:
            formatted = f"{digits[:3]}-{digits[3:]}"

        if formatted != text:
            pos = self.input_code.cursorPosition()
            self.input_code.blockSignals(True)
            self.input_code.setText(formatted)
            self.input_code.setCursorPosition(min(len(formatted), pos + 1))
            self.input_code.blockSignals(False)

    def _handle_submit(self) -> None:
        raw_code = self.input_code.text().strip()
        clean_code = raw_code.replace("-", "").replace(" ", "")

        if len(clean_code) < 4:
            self.lbl_status.setText("⚠️ Lütfen geçerli 6 haneli eşleştirme kodunu girin.")
            return

        self.lbl_status.setStyleSheet("font-size: 11px; color: #38bdf8; font-weight: bold;")
        self.lbl_status.setText("⏳ Kod doğrulanıyor, lütfen bekleyin...")
        self.btn_submit.setEnabled(False)

        try:
            QGuiApplication.processEvents()
        except Exception:
            pass

        # Supabase verify_desktop_pairing_code RPC çağrısı
        res = CONFIG.pair_with_code(clean_code)

        if res.get("success"):
            data = res.get("data", {})
            student_name = data.get("name", "Öğrenci")
            self.lbl_status.setStyleSheet("font-size: 11px; color: #34d399; font-weight: bold;")
            self.lbl_status.setText(f"✅ Harika! Cihaz {student_name} hesabına bağlandı!")

            # 1. device_auth.json içine kalıcı olarak kaydet
            auth_payload = {
                "user_id": data.get("user_id", CONFIG.user_id),
                "family_id": data.get("family_id", CONFIG.family_id),
                "magic_login_token": data.get("magic_login_token", ""),
                "student_name": student_name,
                "device_id": CONFIG.device_id,
                "paired_at": data.get("paired_at", ""),
                "is_paired": True,
            }
            save_device_auth(auth_payload)

            # 2. Local cache içine offline master PIN hash'i çek
            try:
                import urllib.request
                import json
                set_url = (
                    f"{CONFIG.supabase_url}/rest/v1/family_settings"
                    f"?family_id=eq.{data.get('family_id', CONFIG.family_id)}&select=offline_master_pin_hash"
                )
                req = urllib.request.Request(
                    set_url,
                    headers={
                        "apikey": CONFIG.supabase_anon_key,
                        "Authorization": f"Bearer {CONFIG.supabase_anon_key}",
                    },
                )
                with urllib.request.urlopen(req, timeout=5) as r:
                    rows = json.loads(r.read().decode("utf-8"))
                    if rows and rows[0].get("offline_master_pin_hash"):
                        LOCAL_CACHE.update_pin_hash(rows[0]["offline_master_pin_hash"])
            except Exception as e:
                print(f"[PairingDialog] Offline PIN hash çekme uyarısı: {e}")

            try:
                QGuiApplication.processEvents()
            except Exception:
                pass

            self.accept()
        else:
            self.lbl_status.setStyleSheet("font-size: 11px; color: #f43f5e; font-weight: bold;")
            self.lbl_status.setText(f"❌ {res.get('message', 'Eşleştirme kodu geçersiz!')}")
            self.btn_submit.setEnabled(True)


def ensure_device_pairing_gui(parent: Optional[QWidget] = None) -> bool:
    """
    Eğer `device_auth.json` mevcut değilse eşleştirme ekranını açar ve
    başarılı olursa True döner. Zaten eşleştirilmişse doğrudan True döner.
    """
    if has_device_auth():
        return True

    dialog = DevicePairingDialog(parent)
    result = dialog.exec()
    return result == QDialog.DialogCode.Accepted
