'use client';

import React from 'react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { TopFamilyBar } from '@/components/shared/TopFamilyBar';
import { StudentDashboard } from '@/components/student/StudentDashboard';
import { ParentCommandCenter } from '@/components/parent/ParentCommandCenter';

export default function HomePage() {
  const { activeUser } = useFamilyRealtime();

  return (
    <div className="min-h-screen flex flex-col bg-slate-950">
      <TopFamilyBar />
      <main className="flex-1 max-w-7xl w-full mx-auto px-3 sm:px-6 py-5">
        {activeUser.role === 'parent' ? (
          <ParentCommandCenter />
        ) : (
          <StudentDashboard />
        )}
      </main>
    </div>
  );
}
