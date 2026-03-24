import { createClient } from '@/lib/supabase/server';
import { HugeiconsIcon } from '@hugeicons/react';
import { Settings01Icon, UserCircleIcon, Notification01Icon, GridIcon, LogoutSquare01Icon } from '@hugeicons/core-free-icons';

export const metadata = { title: 'Configuración' };

export default async function SettingsPage() {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data: profile } = await supabase.from('profiles').select('*, households(*)').eq('id', user!.id).single();

  if (!profile || !profile.household_id) return null;

  const householdName = (profile as { households?: { name: string } | null })?.households?.name;

  const sections = [
    {
      title: 'Cuenta',
      items: [
        { href: '/app/settings/profile', icon: UserCircleIcon, label: 'Perfil', description: profile?.name ?? '—' },
        { href: '/app/settings/household', icon: GridIcon, label: 'Hogar', description: householdName ?? 'Sin hogar' },
      ],
    },
    {
      title: 'Preferencias',
      items: [
        { href: '/app/settings/categories', icon: GridIcon, label: 'Categorías', description: 'Personaliza tus categorías' },
        { href: '/app/settings/notifications', icon: Notification01Icon, label: 'Notificaciones', description: 'Recordatorios y alertas' },
      ],
    },
    {
      title: 'Datos',
      items: [
        { href: '/app/settings/export', icon: Settings01Icon, label: 'Exportar datos', description: 'CSV o PDF' },
      ],
    },
  ];

  return (
    <div className="max-w-lg space-y-6 animate-fade-in">
      <h1 className="text-2xl font-bold text-text-primary">Configuración</h1>

      {sections.map(sec => (
        <section key={sec.title}>
          <p className="text-xs font-semibold text-muted uppercase tracking-wide mb-2">{sec.title}</p>
          <div className="card divide-y divide-border p-0">
            {sec.items.map(({ href, icon: Icon, label, description }) => (
              <a
                key={href}
                href={href}
                className="flex items-center gap-3 px-4 py-3.5 hover:bg-bg-elevated transition-colors cursor-pointer first:rounded-t-2xl last:rounded-b-2xl"
              >
                <div className="w-8 h-8 rounded-lg bg-bg-elevated flex items-center justify-center">
                  <HugeiconsIcon icon={Icon} className="w-4 h-4 text-text-secondary" />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-text-primary">{label}</p>
                  <p className="text-xs text-muted">{description}</p>
                </div>
                <span className="text-muted text-lg">›</span>
              </a>
            ))}
          </div>
        </section>
      ))}

      {/* Logout */}
      <form action="/api/auth/logout" method="POST">
        <button
          type="submit"
          className="w-full flex items-center gap-3 px-4 py-3.5 card text-danger hover:bg-danger/10 transition-colors cursor-pointer"
          id="settings-logout-btn"
        >
          <HugeiconsIcon icon={LogoutSquare01Icon} className="w-4 h-4" />
          Cerrar sesión
        </button>
      </form>
    </div>
  );
}
