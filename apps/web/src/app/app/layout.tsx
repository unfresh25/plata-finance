import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import Sidebar from '@/components/layout/Sidebar';
import Header from '@/components/layout/Header';

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) redirect('/login');

  let { data: profile } = await supabase
    .from('profiles')
    .select('*, households(*)')
    .eq('id', user.id)
    .single();

  if (!profile) {
    await supabase.from('profiles').insert({ id: user.id, name: user.email?.split('@')[0] || 'Usuario', currency: 'USD' });
    const res = await supabase.from('profiles').select('*, households(*)').eq('id', user.id).single();
    profile = res.data;
  }

  if (profile && !profile.household_id) {
    const { data: hh } = await supabase.from('households').insert({ name: 'Hogar Principal' }).select().single();
    if (hh) {
      await supabase.from('profiles').update({ household_id: hh.id }).eq('id', profile.id);
      
      const { data: newProfile } = await supabase.from('profiles').select('*, households(*)').eq('id', user.id).single();
      profile = newProfile;
    }
  }

  return (
    <div className="flex h-dvh overflow-hidden bg-bg-base">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header profile={profile} />
        <main className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
