'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';
import { HugeiconsIcon } from '@hugeicons/react';
import { Login01Icon, Mail01Icon, LockPasswordIcon } from '@hugeicons/core-free-icons';

export default function LoginPage() {
  const router = useRouter();
  const supabase = getSupabaseBrowserClient();

  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setMessage(null);

    if (mode === 'login') {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) {
        setError(error.message);
      } else {
        router.push('/app');
        router.refresh();
      }
    } else {
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { name } },
      });
      if (error) {
        setError(error.message);
      } else {
        setMessage('Revisa tu correo para confirmar tu cuenta.');
      }
    }

    setLoading(false);
  }

  return (
    <div className="min-h-dvh flex items-center justify-center p-4">
      {/* Background glow */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-96 h-96 bg-accent/10 rounded-full blur-3xl" />
      </div>

      <div className="relative w-full max-w-sm animate-slide-up">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-accent mb-4 shadow-lg shadow-accent/30">
            <span className="text-white font-bold text-xl">JF</span>
          </div>
          <h1 className="text-2xl font-bold text-text-primary">Jojo&apos;s Finance</h1>
          <p className="text-text-secondary text-sm mt-1">
            {mode === 'login' ? 'Bienvenido de vuelta' : 'Crea tu cuenta'}
          </p>
        </div>

        {/* Card */}
        <div className="card">
          <form onSubmit={handleSubmit} className="space-y-4">
            {mode === 'signup' && (
              <div>
                <label className="label" htmlFor="name">Nombre</label>
                <input
                  id="name"
                  type="text"
                  className="input"
                  placeholder="Tu nombre"
                  value={name}
                  onChange={e => setName(e.target.value)}
                  required
                />
              </div>
            )}

            <div>
              <label className="label" htmlFor="email">Correo</label>
              <div className="relative">
                <HugeiconsIcon icon={Mail01Icon} className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  id="email"
                  type="email"
                  className="input pl-9"
                  placeholder="correo@ejemplo.com"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  required
                />
              </div>
            </div>

            <div>
              <label className="label" htmlFor="password">Contraseña</label>
              <div className="relative">
                <HugeiconsIcon icon={LockPasswordIcon} className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  id="password"
                  type="password"
                  className="input pl-9"
                  placeholder="••••••••"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  required
                  minLength={8}
                />
              </div>
            </div>

            {error && (
              <p className="text-sm text-danger bg-danger/10 rounded-lg px-3 py-2">{error}</p>
            )}
            {message && (
              <p className="text-sm text-success bg-success/10 rounded-lg px-3 py-2">{message}</p>
            )}

            <button
              type="submit"
              className="btn-primary w-full flex items-center justify-center gap-2"
              disabled={loading}
              id="auth-submit-btn"
            >
              {loading ? (
                <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <HugeiconsIcon icon={Login01Icon} className="w-4 h-4" />
              )}
              {mode === 'login' ? 'Iniciar sesión' : 'Registrarse'}
            </button>
          </form>
        </div>

        {/* Toggle */}
        <p className="text-center text-sm text-text-secondary mt-4">
          {mode === 'login' ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?'}{' '}
          <button
            onClick={() => { setMode(m => m === 'login' ? 'signup' : 'login'); setError(null); }}
            className="text-accent hover:text-accent-hover font-medium cursor-pointer transition-colors"
          >
            {mode === 'login' ? 'Regístrate' : 'Inicia sesión'}
          </button>
        </p>
      </div>
    </div>
  );
}
