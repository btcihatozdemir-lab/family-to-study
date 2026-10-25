import { createClient, SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl =
  process.env.NEXT_PUBLIC_SUPABASE_URL ||
  'https://pljxviezoilirlsoavto.supabase.co';
const supabaseAnonKey =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
  'sb_publishable_J9zEygp-UY48F0QYIM0gKg_BFg3KlTD';

export const isSupabaseConfigured =
  Boolean(supabaseUrl && supabaseAnonKey) &&
  !supabaseUrl.includes('your-project-id') &&
  !supabaseUrl.includes('PROJE_ID_BURAYA');

// Provide a safe WebSocket constructor for Node 20 SSR so @supabase/realtime-js never throws during prerendering
const getRealtimeTransport = () => {
  if (typeof window !== 'undefined' && window.WebSocket) {
    return window.WebSocket;
  }
  if (typeof globalThis !== 'undefined' && (globalThis as unknown as { WebSocket?: typeof WebSocket }).WebSocket) {
    return (globalThis as unknown as { WebSocket: typeof WebSocket }).WebSocket;
  }
  return class SSRDummyWebSocket {} as unknown as typeof WebSocket;
};

export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      realtime: {
        transport: getRealtimeTransport(),
        params: {
          eventsPerSecond: 20,
        },
      },
    })
  : null;

/**
 * Ses kaydını (Appeal savunması veya Pazar Röportajı Zaman Kapsülü) önce
 * Supabase Storage (`voice-memories` bucket) içine yüklemeyi dener;
 * bucket tanımlı değilse veya çevrimdışıysa kesintisiz çalışması için
 * Base64 Data URL döner.
 */
export async function uploadAudioToSupabaseStorageOrDataUrl(
  blob: Blob,
  folder: 'appeals' | 'weekly-interviews',
  fallbackDataUrl: string
): Promise<string> {
  if (!isSupabaseConfigured || !supabase) {
    return fallbackDataUrl;
  }

  try {
    const fileName = `${folder}/${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 8)}.webm`;
    const { data, error } = await supabase.storage
      .from('voice-memories')
      .upload(fileName, blob, {
        contentType: 'audio/webm',
        upsert: false,
      });

    if (!error && data?.path) {
      const { data: pubData } = supabase.storage
        .from('voice-memories')
        .getPublicUrl(data.path);
      if (pubData?.publicUrl) {
        return pubData.publicUrl;
      }
    }
  } catch {
    // Fallback to base64 data URL silently
  }

  return fallbackDataUrl;
}
