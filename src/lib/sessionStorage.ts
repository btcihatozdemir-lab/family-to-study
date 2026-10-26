'use client';

export interface StoredFamilySession {
  userId: string;
  familyId: string;
  sessionToken: string;
  role: 'parent' | 'child';
  name: string;
  savedAt: number;
}

const STORAGE_KEY = 'family_persistent_session_v6';
const COOKIE_NAME = 'family_os_session';
const DB_NAME = 'family_to_study_idb';
const DB_STORE = 'app_session';

// --- Cookie Helpers ---
function setCookie(name: string, value: string, days: number = 3650): void {
  if (typeof document === 'undefined') return;
  const maxAge = days * 24 * 60 * 60;
  const encoded = encodeURIComponent(value);
  document.cookie = `${name}=${encoded}; path=/; max-age=${maxAge}; SameSite=Lax`;
}

function getCookie(name: string): string | null {
  if (typeof document === 'undefined') return null;
  const match = document.cookie.match(new RegExp('(^|;\\s*)(' + name + ')=([^;]*)'));
  return match ? decodeURIComponent(match[3]) : null;
}

function deleteCookie(name: string): void {
  if (typeof document === 'undefined') return;
  document.cookie = `${name}=; path=/; max-age=0; SameSite=Lax`;
}

// --- IndexedDB Helpers ---
function openIndexedDB(): Promise<IDBDatabase | null> {
  if (typeof window === 'undefined' || !window.indexedDB) {
    return Promise.resolve(null);
  }
  return new Promise((resolve) => {
    try {
      const request = window.indexedDB.open(DB_NAME, 1);
      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;
        if (!db.objectStoreNames.contains(DB_STORE)) {
          db.createObjectStore(DB_STORE);
        }
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

async function saveToIndexedDB(key: string, value: unknown): Promise<void> {
  try {
    const db = await openIndexedDB();
    if (!db) return;
    const tx = db.transaction(DB_STORE, 'readwrite');
    const store = tx.objectStore(DB_STORE);
    store.put(value, key);
  } catch {
    // Ignore IDB write error silently
  }
}

async function getFromIndexedDB<T>(key: string): Promise<T | null> {
  try {
    const db = await openIndexedDB();
    if (!db) return null;
    return new Promise((resolve) => {
      try {
        const tx = db.transaction(DB_STORE, 'readonly');
        const store = tx.objectStore(DB_STORE);
        const req = store.get(key);
        req.onsuccess = () => resolve((req.result as T) || null);
        req.onerror = () => resolve(null);
      } catch {
        resolve(null);
      }
    });
  } catch {
    return null;
  }
}

async function clearFromIndexedDB(key: string): Promise<void> {
  try {
    const db = await openIndexedDB();
    if (!db) return;
    const tx = db.transaction(DB_STORE, 'readwrite');
    const store = tx.objectStore(DB_STORE);
    store.delete(key);
  } catch {
    // Ignore error
  }
}

// --- High-Level Persistent Session Management ---

/**
 * Seals the family session across LocalStorage + IndexedDB + 10-Year Cookie
 */
export async function sealPersistentSession(session: StoredFamilySession): Promise<void> {
  const jsonStr = JSON.stringify(session);

  // 1. LocalStorage
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      localStorage.setItem(STORAGE_KEY, jsonStr);
    } catch {}
  }

  // 2. 10-Year Cookie
  setCookie(COOKIE_NAME, jsonStr, 3650);

  // 3. IndexedDB
  await saveToIndexedDB(STORAGE_KEY, session);
}

/**
 * Retrieves the stored session from any available tier (LocalStorage, Cookie, or IndexedDB)
 */
export async function getPersistentSession(): Promise<StoredFamilySession | null> {
  // 1. Try LocalStorage
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      const lsVal = localStorage.getItem(STORAGE_KEY);
      if (lsVal) {
        const parsed = JSON.parse(lsVal);
        if (parsed?.userId && parsed?.familyId) {
          return parsed;
        }
      }
    } catch {}
  }

  // 2. Try Cookie
  try {
    const cookieVal = getCookie(COOKIE_NAME);
    if (cookieVal) {
      const parsed = JSON.parse(cookieVal);
      if (parsed?.userId && parsed?.familyId) {
        // Re-sync to localStorage
        try {
          localStorage.setItem(STORAGE_KEY, cookieVal);
        } catch {}
        return parsed;
      }
    }
  } catch {}

  // 3. Try IndexedDB
  try {
    const idbVal = await getFromIndexedDB<StoredFamilySession>(STORAGE_KEY);
    if (idbVal?.userId && idbVal?.familyId) {
      // Re-sync
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(idbVal));
        setCookie(COOKIE_NAME, JSON.stringify(idbVal), 3650);
      } catch {}
      return idbVal;
    }
  } catch {}

  return null;
}

/**
 * Removes session permanently from all storage tiers
 */
export async function clearPersistentSession(): Promise<void> {
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {}
  }
  deleteCookie(COOKIE_NAME);
  await clearFromIndexedDB(STORAGE_KEY);
}
