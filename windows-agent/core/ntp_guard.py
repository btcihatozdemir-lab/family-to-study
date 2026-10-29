"""
===============================================================================
core/ntp_guard.py - SAAT MANİPÜLASYONU VE TAMPER KORUMASI (SRP)
===============================================================================
Çocukların ekran süresi limitlerini atlatmak için Windows saatini ileri/geri
almasını engeller. Gerçek dünya saatini NTP sunucularından doğrular.
===============================================================================
"""

from __future__ import annotations
import socket
import struct
import time
from typing import Optional


class NtpGuard:
    """NTP protokolü ile güvenli internet zaman doğrulayıcısı."""
    
    NTP_SERVERS = [
        "pool.ntp.org",
        "time.google.com",
        "time.cloudflare.com",
        "time.windows.com",
    ]
    
    # 1900 ile 1970 (UNIX epoch) arasındaki saniye farkı
    NTP_DELTA = 2208988800

    @classmethod
    def get_network_time(cls, timeout: float = 2.0) -> Optional[float]:
        """Güvenilir NTP sunucularından UNIX zaman damgasını çeker."""
        for server in cls.NTP_SERVERS:
            client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                client.settimeout(timeout)
                # NTP v3 paket yapısı (48 byte, ilk byte 0x1b = mode 3, version 3)
                data = b'\x1b' + 47 * b'\0'
                client.sendto(data, (server, 123))
                response, _ = client.recvfrom(1024)
                
                if len(response) >= 48:
                    unpacked = struct.unpack("!12I", response[0:48])
                    ntp_seconds = unpacked[10]
                    return float(ntp_seconds - cls.NTP_DELTA)
            except Exception:
                continue
            finally:
                client.close()
        return None

    @classmethod
    def verify_system_clock(cls, max_drift_seconds: int = 300) -> bool:
        """
        Sistem saati ile gerçek internet saati arasındaki sapmayı kontrol eder.
        Eğer sapma max_drift_seconds (örn. 5 dakika) üzerindeyse saat manipüle edilmiştir.
        """
        net_time = cls.get_network_time()
        if net_time is None:
            # İnternet yoksa veya engellenmişse güvenli varsayılır
            return True
            
        sys_time = time.time()
        drift = abs(sys_time - net_time)
        if drift > max_drift_seconds:
            print(f"[NtpGuard] 🚨 Saat manipülasyonu tespit edildi! Sapma: {int(drift)} sn")
            return False
        return True
