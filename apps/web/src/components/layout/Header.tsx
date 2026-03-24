'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { HugeiconsIcon } from '@hugeicons/react';
import { Settings01Icon,
  Logout01Icon,
  UserIcon, } from '@hugeicons/core-free-icons';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';
import type { Profile } from '@jojos/core';

interface HeaderProps {
  profile: (Profile & { households: { name: string } | null }) | null;
}

export default function Header({ profile }: HeaderProps) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const supabase = getSupabaseBrowserClient();

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  const initials = profile?.name
    ? profile.name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
    : '?';

  return (
    <header className="h-14 shrink-0 bg-bg-surface border-b border-border flex items-center justify-between px-5">
      {/* Household name */}
      <div>
        <p className="text-xs text-muted">Hogar</p>
        <p className="text-sm font-medium text-text-primary">{profile?.households?.name ?? '—'}</p>
      </div>

      {/* Avatar dropdown */}
      <div className="relative">
        <button
          onClick={() => setOpen(!open)}
          className="flex items-center gap-2 cursor-pointer hover:bg-bg-elevated rounded-xl px-2 py-1.5 transition-colors"
          aria-label="Menú de usuario"
          id="user-menu-btn"
        >
          <div className="w-8 h-8 rounded-full bg-accent/20 border border-accent/30 flex items-center justify-center">
            {profile?.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={profile.avatar_url} alt={profile.name} className="w-full h-full rounded-full object-cover" />
            ) : (
              <span className="text-accent text-xs font-bold">{initials}</span>
            )}
          </div>
          <div className="hidden sm:block text-left">
            <p className="text-sm font-medium text-text-primary leading-tight">{profile?.name ?? 'Usuario'}</p>
            <p className="text-xs text-muted">{profile?.currency}</p>
          </div>
        </button>

        {open && (
          <>
            <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
            <div className="absolute right-0 top-full mt-2 w-44 bg-bg-elevated border border-border rounded-xl shadow-xl z-20 animate-fade-in">
              <a href="/app/settings" className="flex items-center gap-2.5 px-3 py-2.5 text-sm text-text-secondary hover:text-text-primary hover:bg-bg-surface rounded-t-xl cursor-pointer transition-colors">
                <HugeiconsIcon icon={Settings01Icon} className="w-4 h-4" />
                Configuración
              </a>
              <a href="/app/settings/profile" className="flex items-center gap-2.5 px-3 py-2.5 text-sm text-text-secondary hover:text-text-primary hover:bg-bg-surface cursor-pointer transition-colors">
                <HugeiconsIcon icon={UserIcon} className="w-4 h-4" />
                Perfil
              </a>
              <hr className="border-border mx-2" />
              <button
                onClick={handleLogout}
                className="flex items-center gap-2.5 w-full px-3 py-2.5 text-sm text-danger hover:bg-danger/10 rounded-b-xl cursor-pointer transition-colors"
                id="logout-btn"
              >
                <HugeiconsIcon icon={Logout01Icon} className="w-4 h-4" />
                Cerrar sesión
              </button>
            </div>
          </>
        )}
      </div>
    </header>
  );
}
