"""
===============================================================================
ota_updater.py - UZAKTAN OTOMATİK GÜNCELLEYİCİ (OTA AUTO-UPDATER)
===============================================================================
Özellikler:
- Ajan ilk açıldığında ve çalışırken her 30 dakikada bir Supabase `family_settings`
  tablosundaki `latest_agent_version` değerini yerel `AGENT_VERSION` ile karşılaştırır.
- Sunucudaki sürüm daha yeniyse ve `agent_download_url` mevcutsa:
  1) `updating.lock` dosyasını oluşturur (Watchdog sürecinin müdahale etmesini önler).
  2) Güncelleme paketini (`.zip` veya `.exe`) arka planda indirir ve doğrular.
  3) Güncellemeyi uygular, `updating.lock` dosyasını siler ve Ajanı otomatik
     olarak yeni sürümle yeniden başlatır (`os.execv` veya güncelleme `.bat`).
===============================================================================
"""

from __future__ import annotations

import io
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
import zipfile
from typing import Optional, Tuple

try:
    from supabase import Client
except ImportError:
    Client = None

from config import (
    AGENT_VERSION,
    BASE_DIR,
    CONFIG,
    set_ota_updating_lock,
    clear_ota_updating_lock,
)

IS_WINDOWS = sys.platform == "win32"


def parse_semver(version_str: str) -> Tuple[int, ...]:
    """Sürüm dizesini (örn: '1.2.3') karşılaştırılabilir tamsayı demetine çevirir."""
    parts = []
    clean = (version_str or "").strip().lstrip("vV")
    for p in clean.split("."):
        try:
            parts.append(int(p))
        except ValueError:
            parts.append(0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:4])


def is_version_newer(remote_ver: str, current_ver: str = AGENT_VERSION) -> bool:
    """Uzak sürüm yerel sürümden daha yeni mi denetler."""
    try:
        return parse_semver(remote_ver) > parse_semver(current_ver)
    except Exception:
        return False


class OTAUpdaterThread(threading.Thread):
    """
    Arka planda periyodik olarak OTA güncellemelerini denetleyen ve
    uygulayan iş parçacığı.
    """

    def __init__(
        self,
        supabase_client_getter,
        check_interval_sec: int = 1800,
        on_update_started_callback=None,
    ) -> None:
        super().__init__(name="OTAUpdaterThread", daemon=True)
        self.supabase_client_getter = supabase_client_getter
        self.check_interval_sec = max(60, int(check_interval_sec))
        self.on_update_started_callback = on_update_started_callback
        self._running = False
        self._is_updating = False

    def stop(self) -> None:
        self._running = False

    def check_for_updates_now(self) -> bool:
        """Güncellemeleri anında kontrol eder ve varsa uygular."""
        if self._is_updating:
            return False

        client: Optional[Client] = (
            self.supabase_client_getter()
            if callable(self.supabase_client_getter)
            else None
        )
        if not client:
            return False

        try:
            res = (
                client.table("family_settings")
                .select("latest_agent_version, agent_download_url, agent_release_notes")
                .eq("family_id", CONFIG.family_id)
                .limit(1)
                .execute()
            )
            if not res.data or len(res.data) == 0:
                return False

            row = res.data[0]
            remote_version = str(row.get("latest_agent_version") or "").strip()
            download_url = str(row.get("agent_download_url") or "").strip()

            if not remote_version or not download_url:
                return False

            if is_version_newer(remote_version, AGENT_VERSION):
                print(
                    f"[OTAUpdater] Yeni sürüm bulundu: {remote_version} (Mevcut: {AGENT_VERSION})! "
                    f"İndiriliyor: {download_url}"
                )
                return self._apply_update(remote_version, download_url)
            else:
                return False
        except Exception as err:
            print(f"[OTAUpdater] Güncelleme denetleme hatası: {err}")
            return False

    def _apply_update(self, new_version: str, download_url: str) -> bool:
        """
        OTA Güncelleme Süreci:
        1. updating.lock dosyasını oluştur (Watchdog saldırı sanmasın).
        2. İndir ve geçici dizinde doğrula.
        3. Dosyaları güncelle ve ajanı yeniden başlat.
        """
        self._is_updating = True
        set_ota_updating_lock()

        if self.on_update_started_callback:
            try:
                self.on_update_started_callback(new_version)
            except Exception:
                pass

        temp_dir = tempfile.mkdtemp(prefix="familyos_update_")
        downloaded_file = os.path.join(temp_dir, "update_package")

        try:
            print(f"[OTAUpdater] İndirme başladı -> {download_url}")
            urllib.request.urlretrieve(download_url, downloaded_file)

            is_zip = zipfile.is_zipfile(downloaded_file)
            if is_zip:
                extract_dir = os.path.join(temp_dir, "extracted")
                os.makedirs(extract_dir, exist_ok=True)
                with zipfile.ZipFile(downloaded_file, "r") as z:
                    z.extractall(extract_dir)

                # Çıkarılan dosyaları BASE_DIR içerisine kopyala
                for root, _, files in os.walk(extract_dir):
                    rel_path = os.path.relpath(root, extract_dir)
                    dest_dir = os.path.join(str(BASE_DIR), rel_path) if rel_path != "." else str(BASE_DIR)
                    os.makedirs(dest_dir, exist_ok=True)
                    for file in files:
                        src_file = os.path.join(root, file)
                        dst_file = os.path.join(dest_dir, file)
                        try:
                            shutil.copy2(src_file, dst_file)
                        except Exception as cp_err:
                            print(f"[OTAUpdater] Dosya kopyalama uyarısı ({file}): {cp_err}")
            elif downloaded_file.endswith(".exe") or download_url.endswith(".exe"):
                # Standalone exe güncellemesi için .bat oluştur
                bat_path = os.path.join(temp_dir, "apply_update.bat")
                target_exe = sys.executable
                with open(bat_path, "w", encoding="utf-8") as bf:
                    bf.write("@echo off\n")
                    bf.write("timeout /t 2 /nobreak >nul\n")
                    bf.write(f'copy /y "{downloaded_file}" "{target_exe}"\n')
                    bf.write(f'del "{BASE_DIR / "updating.lock"}"\n')
                    bf.write(f'start "" "{target_exe}"\n')
                    bf.write(f'rd /s /q "{temp_dir}"\n')
                    bf.write("exit\n")

                subprocess.Popen(["cmd.exe", "/c", bat_path], creationflags=subprocess.CREATE_NO_WINDOW if IS_WINDOWS else 0)
                sys.exit(0)

            print(f"[OTAUpdater] Yeni sürüm {new_version} başarıyla uygulandı! Yeniden başlatılıyor...")
            clear_ota_updating_lock()

            # Ajanı yeni sürümle yeniden başlat
            self._restart_current_agent()
            return True

        except Exception as err:
            print(f"[OTAUpdater] Güncelleme uygulama hatası: {err}")
            clear_ota_updating_lock()
            self._is_updating = False
            return False
        finally:
            try:
                shutil.rmtree(temp_dir, ignore_errors=True)
            except Exception:
                pass

    @staticmethod
    def _restart_current_agent() -> None:
        """Ajan sürecini yerinde yeniden başlatır."""
        clear_ota_updating_lock()
        try:
            if getattr(sys, "frozen", False):
                os.execv(sys.executable, sys.argv)
            else:
                main_script = str(BASE_DIR / "main.py")
                cmd = [sys.executable, main_script, "--worker"]
                subprocess.Popen(cmd, cwd=str(BASE_DIR))
                sys.exit(0)
        except Exception as err:
            print(f"[OTAUpdater] Yeniden başlatma hatası: {err}")
            sys.exit(0)

    def run(self) -> None:
        self._running = True
        # İlk açılışta 15 saniye sonra ilk kontrolü yap
        time.sleep(15)
        self.check_for_updates_now()

        while self._running:
            time.sleep(self.check_interval_sec)
            if not self._running:
                break
            self.check_for_updates_now()
