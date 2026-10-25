"""
===============================================================================
watchdog_guard.py - İKİZ NÖBETÇİ (MUTUAL WATCHDOG & ANTI-KILL SÜRECİ)
===============================================================================
Özellikler:
- Ana Ajanı (`main.py` / `FamilyOS_Agent.exe`) her 0.5 saniyede bir izleyen
  bağımsız ve hafif bekçi süreci.
- Öğrenci Görev Yöneticisi, CMD (`taskkill /f /im`) veya başka bir araçla
  Ana Ajanı kapattığında:
  1) `updating.lock` dosyası yoksa 0.5 saniye içinde Ana Ajanı tekrar başlatır.
  2) Supabase `violation_logs` tablosuna `watchdog_agent_restarted` ihlali kaydeder.
  3) Ebeveyne anında acil durum uyarısı iletir.
===============================================================================
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from typing import Optional

try:
    import psutil
except ImportError:
    psutil = None

try:
    from supabase import create_client, Client
except ImportError:
    create_client = None
    Client = None

from config import (
    BASE_DIR,
    CONFIG,
    is_ota_updating,
)

IS_WINDOWS = sys.platform == "win32"
CREATE_NO_WINDOW = 0x08000000 if IS_WINDOWS else 0


def init_supabase_client() -> Optional[Client]:
    """Supabase istemcisini başlatır."""
    if not create_client:
        return None
    try:
        return create_client(CONFIG.supabase_url, CONFIG.supabase_anon_key)
    except Exception as err:
        print(f"[WatchdogGuard] Supabase bağlantı hatası: {err}")
        return None


def report_watchdog_restart_violation(supabase: Optional[Client]) -> None:
    """Supabase violation_logs tablosuna watchdog_agent_restarted kaydı ve ebeveyne mesaj gönderir."""
    if not supabase:
        supabase = init_supabase_client()
    if not supabase:
        return

    now_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    now_epoch = int(time.time())

    # 1. Atomik RPC ile kalkan kır ve ihlal kaydet
    try:
        supabase.rpc(
            "record_violation_and_break_shield",
            {
                "p_user_id": CONFIG.user_id,
                "p_device_id": CONFIG.device_id,
                "p_violation_type": "watchdog_agent_restarted",
            },
        ).execute()
    except Exception as rpc_err:
        print(f"[WatchdogGuard] RPC ihlal kayıt hatası (fallback deneniyor): {rpc_err}")
        try:
            supabase.table("violation_logs").insert(
                {
                    "id": f"v-wd-{now_epoch}",
                    "family_id": CONFIG.family_id,
                    "user_id": CONFIG.user_id,
                    "device_id": CONFIG.device_id,
                    "violation_type": "watchdog_agent_restarted",
                    "created_at": now_iso,
                }
            ).execute()
        except Exception:
            pass

    # 2. Ebeveyne doğrudan acil mesaj bildirimi gönder
    try:
        supabase.table("messages").insert(
            {
                "id": f"msg-wd-{now_epoch}",
                "family_id": CONFIG.family_id,
                "sender_id": CONFIG.user_id,
                "receiver_id": CONFIG.parent_receiver_id,
                "message_type": "text",
                "content": (
                    "🚨 [Acil Anti-Kill Kalkanı] Ana ajan beklenmedik şekilde kapatıldı "
                    "ve İkiz Nöbetçi (Watchdog) tarafından 0.5 saniyede otomatik diriltildi!"
                ),
                "is_read": False,
            }
        ).execute()
    except Exception as msg_err:
        print(f"[WatchdogGuard] Ebeveyn uyarı mesajı hatası: {msg_err}")


def is_pid_alive_and_matches(pid: int) -> bool:
    """Verilen PID'nin hayatta olup olmadığını kontrol eder."""
    if pid <= 0:
        return False
    if psutil is not None:
        try:
            p = psutil.Process(pid)
            return p.is_running() and p.status() != psutil.STATUS_ZOMBIE
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return False
    else:
        try:
            os.kill(pid, 0)
            return True
        except (OSError, ProcessLookupError):
            return False


def spawn_main_agent() -> subprocess.Popen:
    """Ana ajanı (main.py / FamilyOS_Agent.exe) penceresiz veya normal süreç olarak başlatır."""
    main_py = str(BASE_DIR / "main.py")
    if getattr(sys, "frozen", False):
        exe_path = sys.executable.replace("watchdog_guard.exe", "FamilyOS_Agent.exe")
        if not os.path.exists(exe_path):
            exe_path = sys.executable
        cmd = [exe_path]
    else:
        python_exe = sys.executable
        cmd = [python_exe, main_py, "--worker"]

    kwargs: dict = {
        "cwd": str(BASE_DIR),
        "close_fds": True,
    }
    if IS_WINDOWS:
        # Arka planda bağımsız yeni süreç grubu
        kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP

    print(f"[WatchdogGuard] Ana Ajan başlatılıyor: {cmd}")
    proc = subprocess.Popen(cmd, **kwargs)
    return proc


def run_watchdog_loop(target_pid: Optional[int] = None) -> None:
    """
    İkiz Nöbetçi Ana Döngüsü:
    Her 0.5 saniyede bir hedef ana ajanın hayatta olup olmadığını denetler.
    """
    print("==================================================================")
    print(" [WATCHDOG GUARD] İKİZ NÖBETÇİ ANTI-KILL SÜRECİ DEVREDE")
    print(f" İzlenen Ana PID: {target_pid}")
    print(f" Çalışma Dizini : {BASE_DIR}")
    print("==================================================================")

    supabase = init_supabase_client()
    current_target_pid = target_pid

    # Eğer target_pid verilmemişse ilk defa ana ajanı kendisi başlatsın
    if not current_target_pid or not is_pid_alive_and_matches(current_target_pid):
        proc = spawn_main_agent()
        current_target_pid = proc.pid
        print(f"[WatchdogGuard] Ana Ajan PID {current_target_pid} ile başlatıldı.")

    while True:
        try:
            time.sleep(0.5)

            # OTA Güncelleme yapılıyorsa nöbetçi müdahale etmez
            if is_ota_updating():
                continue

            if not is_pid_alive_and_matches(current_target_pid):
                print(
                    f"[WatchdogGuard] 🚨 DİKKAT: Ana Ajan (PID: {current_target_pid}) "
                    "sonlandırıldı! 0.5 saniye içinde yeniden başlatılıyor..."
                )
                # İhlal kaydet ve ebeveyne bildir
                report_watchdog_restart_violation(supabase)

                # Ana ajanı dirilt
                new_proc = spawn_main_agent()
                current_target_pid = new_proc.pid
                print(f"[WatchdogGuard] Ana Ajan yeni PID {current_target_pid} ile ayağa kaldırıldı.")
        except KeyboardInterrupt:
            break
        except Exception as err:
            print(f"[WatchdogGuard] Döngü istisnası: {err}")
            time.sleep(1.0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FamilyToStudy İkiz Nöbetçi Watchdog")
    parser.add_argument("--target-pid", type=int, default=None, help="İzlenecek ana ajan PID")
    args = parser.parse_args()

    run_watchdog_loop(target_pid=args.target_pid)
