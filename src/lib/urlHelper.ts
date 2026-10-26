/**
 * ==============================================================================
 * urlHelper.ts - DİNAMİK URL VE GİT-HUB PAGES / BASE-PATH KÖPRÜSÜ
 * ==============================================================================
 * GitHub Pages (/family-to-study), özel alan adı veya localhost altında çalışan
 * uygulamanın doğru kök adresini hesaplar; sihirli link (?u=...) ve QR kodlarda
 * 404 (kök dizin kaybı) oluşmasını %100 engeller.
 * ==============================================================================
 */

/**
 * Uygulamanın tam kök adresini (Origin + GitHub Pages repo alt dizini / basePath) döner.
 * Her zaman '/' ile biter.
 *
 * Örnek Çıktılar:
 * - GitHub Pages: https://btcihatozdemir-lab.github.io/family-to-study/
 * - Localhost:    http://localhost:3000/
 * - Özel Domain:  https://aile-akademisi.com/
 */
export function getAppBaseUrl(): string {
  // SSR veya istemci dışı ortamlar için fallback
  if (typeof window === 'undefined') {
    const envProd = process.env.PWA_PRODUCTION_URL || process.env.FAMILY_PWA_URL;
    if (envProd) {
      return envProd.endsWith('/') ? envProd : `${envProd}/`;
    }
    const envBase = process.env.NEXT_PUBLIC_BASE_PATH || '';
    const cleanEnvBase = envBase ? (envBase.startsWith('/') ? envBase : `/${envBase}`).replace(/\/+$/, '') : '/family-to-study';
    return `https://btcihatozdemir-lab.github.io${cleanEnvBase}/`;
  }

  const { origin, pathname, hostname } = window.location;

  // 1. Next.js derleme anında atanan NEXT_PUBLIC_BASE_PATH (varsa)
  let basePath = process.env.NEXT_PUBLIC_BASE_PATH || '';

  // 2. GitHub Pages altında çalışıyorsak (*.github.io)
  if (!basePath && hostname.endsWith('github.io')) {
    const segments = pathname.split('/').filter(Boolean);
    if (segments.length > 0) {
      // İlk segment repository adıdır (örn: "family-to-study")
      basePath = `/${segments[0]}`;
    } else {
      // Eğer kullanıcı doğrudan root'a düştüyse bile repo adına yönelt
      basePath = '/family-to-study';
    }
  } else if (!basePath && pathname && pathname !== '/') {
    // Özel alan adlarında veya alt klasör dağıtımlarında
    const segments = pathname.split('/').filter(Boolean);
    // Dosya adı veya API rotası olmayan ilk segmenti koru
    if (segments.length > 0 && !segments[0].includes('.')) {
      basePath = `/${segments[0]}`;
    }
  }

  // Sonda çift slash olmaması için normalize et
  const cleanBasePath = basePath
    ? (basePath.startsWith('/') ? basePath : `/${basePath}`).replace(/\/+$/, '')
    : '';

  return `${origin}${cleanBasePath}/`;
}

/**
 * Aile bireyleri için tek tıkla sihirli giriş linki oluşturur.
 * Örn: https://btcihatozdemir-lab.github.io/family-to-study/?u=mag-mvp6oluv-osm4m0
 */
export function buildMagicLoginUrl(token: string): string {
  if (!token) return getAppBaseUrl();
  const baseUrl = getAppBaseUrl();
  return `${baseUrl}?u=${encodeURIComponent(token)}`;
}

/**
 * Google OAuth veya Supabase Auth yönlendirme adresi
 */
export function getOAuthRedirectUrl(): string {
  return getAppBaseUrl();
}
