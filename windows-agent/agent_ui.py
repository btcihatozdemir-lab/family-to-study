"""
===============================================================================
agent_ui.py - LEGACY ADAPTER & NATIVE SOLID BRIDGE
===============================================================================
Bu dosya geriye dönük uyumluluk köprüsüdür.
PWA ve QWebEngineView bağımlılıkları tamamen kaldırılmış; yerine %100 Saf
Native PyQt6 mimarisine (`agent_app.py` ve `ui/`) geçilmiştir.
===============================================================================
"""

from __future__ import annotations
import sys
from agent_app import AgentApp

# Geriye dönük uyumluluk için AgentApp sınıfını ve instance'ını dışa aktar
AgentWindow = AgentApp

if __name__ == "__main__":
    print("[agent_ui] Saf Native PyQt6 mimarisi devrede. main.py çalıştırılıyor...")
    from main import main
    sys.exit(main())
