"""
Tam teşekküllü Katı Windows PC Masaüstü Kilit, Sensör ve Watchdog Ajanı
`/windows-agent` klasöründe yer almaktadır:
- windows-agent/agent_gui_enforcer.py (Tam Ekran Topmost Kilit, Fare/Klavye Hook, Pencere İzleyici)
- windows-agent/watchdog_guardian.py (Görev Yöneticisi Kapatma Koruması & agent_offline İhlal Bildirici)
- windows-agent/install_and_start.bat (Windows Startup Kaydı & Görünmez Arka Plan Kurulumu)
- windows-agent/build_exe.bat (Tek dosya .EXE derleyici)
"""

import os
import sys

agent_path = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "windows-agent",
    "agent_gui_enforcer.py",
)

if __name__ == "__main__":
    os.execv(sys.executable, [sys.executable, agent_path])
