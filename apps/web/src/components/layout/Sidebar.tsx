'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { HugeiconsIcon } from '@hugeicons/react';
import { Home01Icon,
  ArrowUpDownIcon,
  Calendar01Icon,
  WalletIcon,
  ChartLineData01Icon, } from '@hugeicons/core-free-icons';

const NAV_ITEMS = [
  { href: '/app', label: 'Inicio', icon: Home01Icon },
  { href: '/app/transactions', label: 'Movimientos', icon: ArrowUpDownIcon },
  { href: '/app/calendar', label: 'Calendario', icon: Calendar01Icon },
  { href: '/app/finances', label: 'Finanzas', icon: WalletIcon },
  { href: '/app/reports', label: 'Reportes', icon: ChartLineData01Icon },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="hidden md:flex flex-col w-56 shrink-0 bg-bg-surface border-r border-border h-full">
      {/* Logo */}
      <div className="p-5 border-b border-border">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-accent flex items-center justify-center shadow-lg shadow-accent/20">
            <span className="text-white text-xs font-bold">JF</span>
          </div>
          <span className="font-semibold text-text-primary">Jojo&apos;s Finance</span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 p-3 space-y-0.5">
        {NAV_ITEMS.map(({ href, label, icon: Icon }) => {
          const isActive = href === '/app' ? pathname === '/app' : pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors duration-150 cursor-pointer ${
                isActive
                  ? 'bg-accent/15 text-accent'
                  : 'text-text-secondary hover:text-text-primary hover:bg-bg-elevated'
              }`}
              aria-current={isActive ? 'page' : undefined}
            >
              <HugeiconsIcon icon={Icon} className="w-4 h-4 shrink-0" />
              {label}
            </Link>
          );
        })}
      </nav>

      {/* Bottom hint */}
      <div className="p-3 border-t border-border">
        <p className="text-xs text-muted text-center">Sincronizado en tiempo real</p>
      </div>
    </aside>
  );
}
