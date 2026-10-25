'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { supabase, isSupabaseConfigured } from '@/lib/supabase';

const CLOCK_DRIFT_THRESHOLD_MS = 2 * 60 * 1000; // 2 dakika

/**
 * SHA-256 Hash Yardımcısı (Acil Durum Offline 6 Haneli PIN için)
 */
export async function computeSha256Hex(rawPin: string): Promise<string> {
  try {
    const clean = rawPin.trim();
    if (
      typeof window !== 'undefined' &&
      window.crypto &&
      window.crypto.subtle
    ) {
      const encoder = new TextEncoder();
      const data = encoder.encode(clean);
      const hashBuffer = await window.crypto.subtle.digest('SHA-256', data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
    }
  } catch (err) {
    console.error('[computeSha256Hex] WebCrypto hatası:', err);
  }
  // Basit deterministik yedek (SSR veya eski tarayıcılar için)
  let h1 = 0xdeadbeef ^ rawPin.length;
  let h2 = 0x41c6ce57 ^ rawPin.length;
  for (let i = 0; i < rawPin.length; i++) {
    const ch = rawPin.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 =
    Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^
    Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 =
    Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^
    Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (h2 >>> 0).toString(16).padStart(8, '0') + (h1 >>> 0).toString(16).padStart(8, '0');
}

interface UseServerTimeOptions {
  onClockTamperDetected?: () => void;
}

/**
 * Anti-Cheat Sunucu Saati Senkronizasyonu Hook'u
 * - Uygulama açıldığında Supabase `get_server_time()` RPC'sini çağırır.
 * - `serverTimeOffset = serverTime - Date.now()` değerini hesaplar.
 * - Tüm kronometrelerin `Date.now() + serverTimeOffset` üzerinden çalışmasını sağlar.
 * - Oturum sırasında cihaz saati >2 dakika ileri/geri alınırsa `clock_tamper_attempt` tetikler.
 */
export function useServerTime(options?: UseServerTimeOptions) {
  const [serverTimeOffset, setServerTimeOffset] = useState<number>(0);
  const offsetRef = useRef<number>(0);
  const baselineWallClockRef = useRef<number>(Date.now());
  const baselinePerfNowRef = useRef<number>(
    typeof performance !== 'undefined' ? performance.now() : 0
  );
  const tamperCooldownRef = useRef<number>(0);
  const onTamperRef = useRef(options?.onClockTamperDetected);
  onTamperRef.current = options?.onClockTamperDetected;

  const syncWithServerTime = useCallback(async () => {
    if (!isSupabaseConfigured || !supabase) return;
    try {
      const requestStart = Date.now();
      const { data, error } = await supabase.rpc('get_server_time');
      if (error || !data) return;

      const requestEnd = Date.now();
      const rttHalf = Math.round((requestEnd - requestStart) / 2);
      const serverMs = new Date(data as string).getTime() + rttHalf;

      if (!Number.isNaN(serverMs)) {
        const calculatedOffset = serverMs - requestEnd;
        offsetRef.current = calculatedOffset;
        setServerTimeOffset(calculatedOffset);
        baselineWallClockRef.current = Date.now();
        baselinePerfNowRef.current =
          typeof performance !== 'undefined' ? performance.now() : 0;
      }
    } catch (err) {
      console.error('[useServerTime.syncWithServerTime] Hata:', err);
    }
  }, []);

  useEffect(() => {
    syncWithServerTime();

    // Her 5 saniyede bir monotonik saat (performance.now) ile cihaz saati (Date.now)
    // arasındaki farkı kontrol ederek >2 dk saat hilesini yakala
    const driftWatchInterval = setInterval(() => {
      try {
        if (typeof performance === 'undefined') return;
        const elapsedMonotonic = performance.now() - baselinePerfNowRef.current;
        const elapsedWallClock = Date.now() - baselineWallClockRef.current;
        const driftMs = Math.abs(elapsedWallClock - elapsedMonotonic);

        if (driftMs > CLOCK_DRIFT_THRESHOLD_MS) {
          // Cihaz saati >2 dakika değiştirildi!
          baselineWallClockRef.current = Date.now();
          baselinePerfNowRef.current = performance.now();

          // Offset'i monotonik saate göre otomatik düzelt ki sayaç bozulmasın
          offsetRef.current += elapsedMonotonic - elapsedWallClock;
          setServerTimeOffset(offsetRef.current);

          const now = Date.now();
          if (now - tamperCooldownRef.current > 30000) {
            tamperCooldownRef.current = now;
            onTamperRef.current?.();
          }
        }
      } catch (err) {
        console.error('[useServerTime.driftWatch] Hata:', err);
      }
    }, 5000);

    return () => clearInterval(driftWatchInterval);
  }, [syncWithServerTime]);

  const getServerNow = useCallback((): number => {
    return Date.now() + offsetRef.current;
  }, []);

  return {
    serverTimeOffset,
    getServerNow,
    syncWithServerTime,
  };
}
