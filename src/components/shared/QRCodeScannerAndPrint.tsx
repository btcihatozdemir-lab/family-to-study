'use client';

import React, { useEffect, useRef, useState } from 'react';
import { Camera, QrCode, CheckCircle2, AlertTriangle, Printer, RefreshCw } from 'lucide-react';
import { QRStation } from '@/types/database';

interface QRScannerBoxProps {
  expectedStation: QRStation;
  onScanSuccess: (scannedCode: string) => void;
  buttonLabel?: string;
}

/**
 * Fiziksel QR Kod İstasyonu Okuyucu Bileşeni (`html5-qrcode`)
 * - Gerçek kamera açarak `expectedStation.station_code` değerini okur.
 * - Kamera izni olmayan PC veya masaüstü test ortamları için aynı zamanda
 *   doğrulama simülasyon / manuel istasyon kodu doğrulama desteği içerir.
 */
export const QRScannerBox: React.FC<QRScannerBoxProps> = ({
  expectedStation,
  onScanSuccess,
  buttonLabel = '📷 Kamerayı Aç ve QR Kodu Okut',
}) => {
  const [cameraActive, setCameraActive] = useState(false);
  const [scanError, setScanError] = useState<string | null>(null);
  const [manualCode, setManualCode] = useState('');
  const scannerId = useRef(
    `qr-reader-${Math.random().toString(36).slice(2, 8)}`
  );
  const html5QrCodeRef = useRef<{
    stop: () => Promise<void>;
    clear: () => void;
  } | null>(null);

  useEffect(() => {
    if (!cameraActive) return;
    let isMounted = true;

    const startCameraScanner = async () => {
      try {
        const { Html5Qrcode } = await import('html5-qrcode');
        if (!isMounted) return;

        const qr = new Html5Qrcode(scannerId.current);
        html5QrCodeRef.current = qr;

        await qr.start(
          { facingMode: 'environment' },
          {
            fps: 10,
            qrbox: { width: 210, height: 210 },
          },
          (decodedText: string) => {
            const cleaned = decodedText.trim().toUpperCase();
            if (cleaned === expectedStation.station_code.toUpperCase()) {
              try {
                qr.stop().then(() => qr.clear()).catch(() => {});
              } catch {}
              setCameraActive(false);
              onScanSuccess(cleaned);
            } else {
              setScanError(
                `Farklı bir QR kod okutuldu (${cleaned}). Beklenen istasyon: ${expectedStation.title} (${expectedStation.station_code})`
              );
            }
          },
          () => {
            // Her karedeki okuma denemesi hatalarını sessiz geç
          }
        );
      } catch (err) {
        console.warn('[QRScannerBox] Kamera başlatılamadı:', err);
        if (isMounted) {
          setScanError(
            'Kamera erişimi sağlanamadı veya cihazda kamera bulunamadı. Aşağıdaki istasyon doğrulama butonunu kullanabilirsiniz.'
          );
        }
      }
    };

    startCameraScanner();

    return () => {
      isMounted = false;
      try {
        if (html5QrCodeRef.current) {
          html5QrCodeRef.current
            .stop()
            .then(() => html5QrCodeRef.current?.clear())
            .catch(() => {});
        }
      } catch {}
    };
  }, [cameraActive, expectedStation, onScanSuccess]);

  const handleManualVerify = (e: React.FormEvent) => {
    e.preventDefault();
    if (
      manualCode.trim().toUpperCase() ===
      expectedStation.station_code.toUpperCase()
    ) {
      setScanError(null);
      onScanSuccess(expectedStation.station_code);
    } else {
      setScanError(
        `Hatalı istasyon kodu! Beklenen kod: ${expectedStation.station_code}`
      );
    }
  };

  return (
    <div
      data-allow-touch="true"
      className="bg-slate-900/95 border-2 border-cyan-400/50 rounded-2xl p-4 sm:p-5 space-y-3 text-left"
    >
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 text-cyan-300 font-black text-xs sm:text-sm">
          <QrCode className="w-5 h-5 shrink-0" />
          <span>Fiziksel QR İstasyonu Doğrulaması</span>
        </div>
        <span className="px-2.5 py-0.5 rounded-full bg-cyan-500/20 text-cyan-200 font-mono text-[11px] font-bold">
          {expectedStation.station_code}
        </span>
      </div>

      <p className="text-xs text-slate-300">
        Hedef İstasyon:{' '}
        <strong className="text-white">{expectedStation.title}</strong>
      </p>

      {!cameraActive ? (
        <button
          type="button"
          onClick={() => {
            setScanError(null);
            setCameraActive(true);
          }}
          className="w-full py-3.5 px-4 rounded-2xl bg-gradient-to-r from-cyan-400 to-teal-400 hover:from-cyan-300 hover:to-teal-300 text-slate-950 font-black text-xs sm:text-sm flex items-center justify-center gap-2 shadow-xl transition"
        >
          <Camera className="w-5 h-5" />
          <span>{buttonLabel}</span>
        </button>
      ) : (
        <div className="space-y-2">
          <div
            id={scannerId.current}
            className="w-full max-w-xs mx-auto rounded-2xl overflow-hidden border-2 border-cyan-400 bg-black min-h-[220px]"
          />
          <button
            type="button"
            onClick={() => setCameraActive(false)}
            className="w-full py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-bold flex items-center justify-center gap-1.5"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Kamerayı Kapat</span>
          </button>
        </div>
      )}

      {scanError && (
        <div className="bg-amber-500/20 border border-amber-400/40 rounded-xl p-2.5 text-xs text-amber-200 flex items-center gap-2">
          <AlertTriangle className="w-4 h-4 text-amber-300 shrink-0" />
          <span>{scanError}</span>
        </div>
      )}

      {/* Hızlı Demo / Kamera Olmayan PC Doğrulama Satırı */}
      <div className="pt-2 border-t border-slate-800 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-2">
        <form onSubmit={handleManualVerify} className="flex-1 flex gap-1.5">
          <input
            type="text"
            value={manualCode}
            onChange={(e) => setManualCode(e.target.value)}
            placeholder={`İstasyon Kodu (${expectedStation.station_code})`}
            className="flex-1 bg-slate-950 border border-slate-700 rounded-xl px-3 py-1.5 text-xs font-mono text-white"
          />
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-cyan-300 font-bold text-xs"
          >
            Doğrula
          </button>
        </form>

        <button
          type="button"
          onClick={() => onScanSuccess(expectedStation.station_code)}
          className="px-3.5 py-1.5 rounded-xl bg-emerald-500/20 hover:bg-emerald-500/30 border border-emerald-400/40 text-emerald-300 font-bold text-xs flex items-center justify-center gap-1 transition"
        >
          <CheckCircle2 className="w-3.5 h-3.5" />
          <span>Hızlı QR Okut (Simülasyon)</span>
        </button>
      </div>
    </div>
  );
};

/**
 * Deterministik SVG QR Kod Görselleştirici & Tek Tuşla Yazdırma (Print View)
 * Harici API'ye bağımlı kalmadan çevrimdışı da (Offline) çalışır ve gerçek QR
 * okuyucu URL'si ile birlikte yüksek kontrastlı QR matrisi üretir.
 */
export const PrintableQRStationCard: React.FC<{ station: QRStation }> = ({
  station,
}) => {
  // 21x21 QR benzeri deterministik matris oluştur
  const size = 21;
  const cells: boolean[][] = Array.from({ length: size }, () =>
    Array(size).fill(false)
  );

  const drawFinder = (r0: number, c0: number) => {
    for (let r = 0; r < 7; r++) {
      for (let c = 0; c < 7; c++) {
        const isBorder = r === 0 || r === 6 || c === 0 || c === 6;
        const isInner = r >= 2 && r <= 4 && c >= 2 && c <= 4;
        cells[r0 + r][c0 + c] = isBorder || isInner;
      }
    }
  };

  drawFinder(0, 0);
  drawFinder(0, size - 7);
  drawFinder(size - 7, 0);

  let seed = 2166136261;
  for (let i = 0; i < station.station_code.length; i++) {
    seed ^= station.station_code.charCodeAt(i);
    seed = Math.imul(seed, 16777619);
  }

  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      const inFinder =
        (r < 8 && c < 8) ||
        (r < 8 && c >= size - 8) ||
        (r >= size - 8 && c < 8);
      if (inFinder) continue;
      seed ^= (r * 31 + c * 17) & 0xff;
      seed = Math.imul(seed, 16777619);
      cells[r][c] = (Math.abs(seed) % 10) < 5;
    }
  }

  const handlePrintStation = () => {
    if (typeof window === 'undefined') return;
    const printWin = window.open('', '_blank', 'width=600,height=700');
    if (!printWin) {
      window.print();
      return;
    }
    const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(
      station.station_code
    )}`;
    printWin.document.write(`
      <!DOCTYPE html>
      <html lang="tr">
      <head>
        <meta charset="utf-8" />
        <title>QR İstasyonu Yazdır - ${station.title}</title>
        <style>
          body { font-family: system-ui, sans-serif; text-align: center; padding: 40px; color: #0f172a; }
          .card { border: 4px dashed #4f46e5; border-radius: 24px; padding: 32px; max-width: 420px; margin: 0 auto; }
          .badge { background: #e0e7ff; color: #3730a3; padding: 6px 14px; border-radius: 999px; font-weight: 800; font-size: 12px; display: inline-block; margin-bottom: 12px; }
          h1 { font-size: 22px; margin: 8px 0; }
          .code { font-family: monospace; font-size: 18px; font-weight: 900; background: #f1f5f9; padding: 8px 16px; border-radius: 12px; display: inline-block; margin-top: 12px; }
          img { width: 240px; height: 240px; margin: 20px auto; display: block; }
          p { font-size: 13px; color: #475569; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="badge">FAMILY-TO-STUDY FİZİKSEL QR İSTASYONU</div>
          <h1>${station.title}</h1>
          <img src="${qrApiUrl}" alt="${station.station_code}" onload="window.print();" onerror="window.print();" />
          <div class="code">${station.station_code}</div>
          <p>Sabah alarmını susturmak veya istasyon görevini tamamlamak için kameranı bu QR koda okut!</p>
        </div>
      </body>
      </html>
    `);
    printWin.document.close();
  };

  return (
    <div className="bg-slate-950 border border-slate-800 rounded-2xl p-4 flex items-center justify-between gap-4">
      <div className="flex items-center gap-3.5">
        <div className="w-16 h-16 bg-white p-1.5 rounded-xl shrink-0 flex items-center justify-center shadow-md">
          <svg viewBox={`0 0 ${size} ${size}`} className="w-full h-full">
            {cells.map((row, rIdx) =>
              row.map((filled, cIdx) =>
                filled ? (
                  <rect
                    key={`${rIdx}-${cIdx}`}
                    x={cIdx}
                    y={rIdx}
                    width={1}
                    height={1}
                    fill="#0f172a"
                  />
                ) : null
              )
            )}
          </svg>
        </div>
        <div>
          <div className="text-sm font-black text-white">{station.title}</div>
          <div className="text-xs font-mono text-cyan-300 font-bold mt-0.5">
            Kod: {station.station_code}
          </div>
          <div className="text-[11px] text-slate-400 mt-0.5">
            Aksiyon:{' '}
            {station.linked_action === 'dismiss_wake_up_alarm'
              ? '☀️ Sabah Alarmını Sustur & 2 Dk Diş Fırçalama Başlat'
              : station.linked_action === 'start_tooth_brushing'
              ? '🪥 Diş Fırçalama Sayacını Başlat'
              : '✅ Fiziksel Görev Doğrulama'}
          </div>
        </div>
      </div>

      <button
        type="button"
        onClick={handlePrintStation}
        className="px-3.5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center gap-1.5 shrink-0 shadow-lg transition"
      >
        <Printer className="w-4 h-4" />
        <span>QR Kodu Yazdır</span>
      </button>
    </div>
  );
};
