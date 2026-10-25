"""
===============================================================================
FAMILY-TO-STUDY: WINDOWS WATCHDOG (GÖREV YÖNETİCİSİ KORUMA BEKÇİSİ)
===============================================================================
Bu süreç arka planda çalışarak `agent_gui_enforcer.py` sürecini izler.
Öğrenci Görev Yöneticisi'nden (Task Manager) kilit ekranını sonlandırırsa:
1. Anında Supabase `record_violation_and_break_shield` RPC fonksiyonunu
   `agent_offline` tipiyle çağırır (1 Kalkan kırılır ve Ebeveyne acil uyarı gider).
2. Kilit ajanını 1 saniye içinde otomatik olarak yeniden başlatır!
===============================================================================
"""

import os
import sys
import time
import json
import subprocess

try:
    from supabase import create_client
except ImportError:
    create_client = None

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
AGENT_SCRIPT = os.path.join(BASE_DIR, "agent_gui_enforcer.py")
CONFIG_FILE = os.path.join(BASE_DIR, "agent_config.json")


def notify_agent_tampered():
    """Öğrenci ajanı Görev Yöneticisi'nden kapattığında agent_offline ihlali gönderir."""
    if not create_client or not os.path.exists(CONFIG_FILE):
        return
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        client = create_client(cfg["supabase_url"], cfg["supabase_key"])
        client.rpc(
            "record_violation_and_break_shield",
            {
                "p_user_id": cfg["student_id"],
                "p_device_id": cfg["device_id"],
                "p_violation_type": "agent_offline",
            },
        ).execute()
    except Exception as e:
        print("Watchdog bildirim hatası:", e)


def main():
    print("[FamilyToStudy Watchdog] Koruma bekçisi aktif...")
    while True:
        proc = subprocess.Popen([sys.executable, AGENT_SCRIPT], cwd=BASE_DIR)
        exit_code = proc.wait()

        # Eğer ajan beklenmedik şekilde kapatıldıysa (Task Manager Kill vb.)
        if exit_code != 0:
            print("[Watchdog] UYARI: Ajan sonlandırıldı! İhlal kaydediliyor ve yeniden başlatılıyor...")
            notify_agent_tampered()
            time.sleep(1.0)
        else:
            time.sleep(2.0)


if __name__ == "__main__":
    main()
