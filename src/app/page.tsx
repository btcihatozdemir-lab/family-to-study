'use client';

import React from 'react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { TopFamilyBar } from '@/components/shared/TopFamilyBar';
import { StudentDashboard } from '@/components/student/StudentDashboard';
import { ParentCommandCenter } from '@/components/parent/ParentCommandCenter';
import { AuthAndLoginScreen } from '@/components/auth/AuthAndLoginScreen';
import { FamilySetupWizardModal } from '@/components/auth/FamilySetupWizardModal';

export default function HomePage() {
  const {
    isAuthenticated,
    sessionLoading,
    activeUser,
    wizardOpen,
    wizardOwnerEmail,
    setWizardOpen,
    createFamilyWizard,
    loginSuccessWithUser,
  } = useFamilyRealtime();

  if (sessionLoading) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-slate-950 text-white space-y-4">
        <div className="w-16 h-16 rounded-3xl bg-gradient-to-tr from-indigo-500 via-purple-600 to-pink-500 flex items-center justify-center text-3xl animate-pulse shadow-xl shadow-indigo-500/30">
          🚀
        </div>
        <div className="text-sm font-bold text-indigo-300">
          Family-to-Study Açılıyor...
        </div>
      </div>
    );
  }

  // If not authenticated, render Login / Welcome Screen & Wizard
  if (!isAuthenticated) {
    return (
      <>
        <AuthAndLoginScreen
          onLoginSuccess={(userId, familyId) => loginSuccessWithUser(userId, familyId)}
          onRequestSetupWizard={(email) => setWizardOpen(true)}
        />
        <FamilySetupWizardModal
          isOpen={wizardOpen}
          ownerEmail={wizardOwnerEmail}
          onComplete={async (data) => {
            await createFamilyWizard(data);
          }}
        />
      </>
    );
  }

  // Authenticated Screen
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

      <FamilySetupWizardModal
        isOpen={wizardOpen}
        ownerEmail={wizardOwnerEmail}
        onComplete={async (data) => {
          await createFamilyWizard(data);
        }}
      />
    </div>
  );
}
