'use client';

import { useEffect, useCallback } from 'react';

let activeExpansionLocks = 0;

/**
 * Windows Masaüstü Ajanı (PyQt6 QWebEngineView) Pencere Boyutlandırma Köprüsü:
 * - Herhangi bir Modal / Drawer / Büyük Panel açıldığında:
 *   `document.title = "FAMILYOS_UI_EXPAND"` -> Ajan pencereyi `900x650 px` boyutuna büyütür.
 * - Tüm Modal / Drawer'lar kapandığında:
 *   `document.title = "FAMILYOS_UI_COLLAPSE"` -> Ajan pencereyi `350x120 px` kompakt Widget boyutuna küçültür.
 */
export function notifyDesktopAgentExpand(): void {
  if (typeof document === 'undefined') return;
  document.title = 'FAMILYOS_UI_EXPAND';
}

export function notifyDesktopAgentCollapse(): void {
  if (typeof document === 'undefined') return;
  document.title = 'FAMILYOS_UI_COLLAPSE';
}

export function useDesktopBridge(isExpandedOrModalOpen: boolean = false) {
  useEffect(() => {
    if (typeof document === 'undefined') return;

    if (isExpandedOrModalOpen) {
      activeExpansionLocks += 1;
      document.title = 'FAMILYOS_UI_EXPAND';
      return () => {
        activeExpansionLocks = Math.max(0, activeExpansionLocks - 1);
        if (activeExpansionLocks === 0) {
          document.title = 'FAMILYOS_UI_COLLAPSE';
        }
      };
    }
  }, [isExpandedOrModalOpen]);

  const requestExpand = useCallback(() => {
    notifyDesktopAgentExpand();
  }, []);

  const requestCollapse = useCallback(() => {
    activeExpansionLocks = 0;
    notifyDesktopAgentCollapse();
  }, []);

  return {
    requestExpand,
    requestCollapse,
  };
}
