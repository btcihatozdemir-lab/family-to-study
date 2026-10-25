import type { Metadata, Viewport } from 'next';
import './globals.css';
import { FamilyRealtimeProvider } from '@/context/FamilyRealtimeContext';

export const metadata: Metadata = {
  title: 'FamilyToStudy | Aile İçi Oyunlaştırma & Çoklu Cihaz Senkronizasyonu',
  description:
    'Çocukların günlük rutinlerini, ödevlerini ve sorumluluklarını eğlenceli hale getiren, çoklu cihaz senkronizasyonlu ve ebeveyn kontrollü PWA sistemi.',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'FamilyToStudy',
  },
};

export const viewport: Viewport = {
  themeColor: '#020617',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="tr">
      <body className="min-h-screen bg-slate-950 text-slate-100 antialiased">
        <FamilyRealtimeProvider>{children}</FamilyRealtimeProvider>
      </body>
    </html>
  );
}
