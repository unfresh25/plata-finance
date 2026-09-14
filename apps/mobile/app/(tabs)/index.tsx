import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, RefreshControl, Alert, TouchableOpacity, ImageBackground, Dimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { useTheme } from '../../src/context/ThemeContext';
import { formatCurrency, formatShortDate, monthRange } from '@jojos/core';
import TransactionItem from '../../src/components/TransactionItem';
import { useRouter, useFocusEffect } from 'expo-router';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Wallet01Icon, ArrowUp01Icon, ArrowDown01Icon, Calendar01Icon } from '@hugeicons/core-free-icons';
import * as SecureStore from 'expo-secure-store';
import { Image } from 'react-native';
import { SUBSCRIPTION_LOGOS } from '../../src/data/SubscriptionLogos';
import DynamicIcon from '../../src/components/DynamicIcon';
const getRelativeDateText = (dateString: string) => {
  if (!dateString) return '';
  const [y, m, d] = dateString.split('T')[0].split('-');
  const date = new Date(Number(y), Number(m) - 1, Number(d));
  const today = new Date();
  today.setHours(0,0,0,0);
  const diffTime = date.getTime() - today.getTime();
  const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
  if (diffDays === 0) return 'Hoy';
  if (diffDays === 1) return 'Mañana';
  if (diffDays === -1) return 'Ayer';
  return formatShortDate(dateString);
};

const translateFreq = (freq: string) => {
  switch (freq) {
    case 'weekly': return 'Semanal';
    case 'biweekly': return 'Quincenal';
    case 'monthly': return 'Mensual';
    case 'yearly': return 'Anual';
    default: return freq;
  }
};

export default function HomeScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [profile, setProfile] = useState<any>(null);
  const [accounts, setAccounts] = useState<any[]>([]);
  const [recent, setRecent] = useState<any[]>([]); // Renamed from transactions to recent
  const [recurring, setRecurring] = useState<any[]>([]);
  const [debts, setDebts] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [budgetTotal, setBudgetTotal] = useState(0);
  const [currency, setCurrency] = useState('USD');
  const [members, setMembers] = useState<any[]>([]);
  const { theme, isDark } = useTheme();

  const fetchDashboardData = async () => {
    if (!user) return;

    try {
      let { data: pData } = await supabase.from('profiles').select('*, households(*)').eq('id', user.id).single();

      // If profile is missing, it will automatically populate as soon as backend trigger finishes or RLS is fixed.
      if (!pData) {
        console.warn('Profile not found. Waiting for DB trigger or RLS fix.');
      }

      if (pData && !pData.household_id) {
        // First check if there's a pending invite code to join
        let pendingInvite = null;
        try {
          pendingInvite = await SecureStore.getItemAsync('pending_invite_code');
        } catch (e) { }

        let joinedExisting = false;

        if (pendingInvite) {
          console.log('Procesando invite code pendiente:', pendingInvite);
          const { data: hh } = await supabase.from('households').select('id, name').eq('invite_code', pendingInvite).single();
          if (hh) {
            const { error: updateErr } = await supabase.from('profiles').update({ household_id: hh.id }).eq('id', pData.id);
            if (!updateErr) {
              joinedExisting = true;
              pData.household_id = hh.id;
              pData.households = hh;
              Alert.alert('¡Bienvenido!', `Te has unido exitosamente al hogar "${hh.name}".`);
            }
          } else {
            Alert.alert('Código inválido', `El código de invitación ${pendingInvite} no fue encontrado. Se creará un nuevo hogar para ti.`);
          }
          try { await SecureStore.deleteItemAsync('pending_invite_code'); } catch (e) { }
        }

        // Only create a new household if we didn't join an existing one
        if (!joinedExisting) {
          const { data: hh, error: hhErr } = await supabase.from('households').insert({ name: 'Hogar Principal' }).select().single();
          if (hhErr) Alert.alert('Error Creando Hogar', hhErr.message);

          if (hh) {
            const { error: hhUpErr } = await supabase.from('profiles').update({ household_id: hh.id }).eq('id', pData.id);
            if (hhUpErr) Alert.alert('Error Vinculando Hogar', hhUpErr.message);

            await Promise.all([
              // Supabase client instance allows parallel unhandled inserts but we'll await them safely 
              supabase.from('accounts').insert({ household_id: hh.id, name: 'Efectivo Principal', type: 'banco', balance: 0 }),
              supabase.from('categories').insert([
                { household_id: hh.id, name: 'Alimentación', type: 'expense', icon: '🍔', color: '#EF4444' },
                { household_id: hh.id, name: 'Transporte', type: 'expense', icon: '🚗', color: '#F59E0B' },
                { household_id: hh.id, name: 'Vivienda', type: 'expense', icon: '🏠', color: '#6366F1' },
                { household_id: hh.id, name: 'Salario', type: 'income', icon: '💰', color: '#22C55E' },
              ])
            ]);
            const res = await supabase.from('profiles').select('*, households(*)').eq('id', user.id).single();
            pData = res.data;
          }
        }
      }

      const authName = user.user_metadata?.full_name || user.user_metadata?.name || user.user_metadata?.display_name;
      if (pData && authName && pData.name !== authName) {
        await supabase.from('profiles').update({ name: authName }).eq('id', user.id);
        pData.name = authName;
      }

      setProfile(pData);
      setCurrency(pData?.currency ?? 'USD');

      if (pData?.household_id) {
        const { start, end } = monthRange();

        const [accRes, txsRes, recRes, debtsRes, catsRes, memsRes] = await Promise.all([
          supabase.from('accounts').select('*').eq('household_id', pData.household_id),
          supabase.from('transactions').select('*').eq('household_id', pData.household_id).gte('date', start).lte('date', end).order('date', { ascending: false }),
          supabase.from('recurring_events').select('*, categories(name, icon, color)').eq('household_id', pData.household_id).eq('is_active', true).order('next_date').limit(15),
          supabase.from('debts').select('*, categories(name, icon, color), recurring_events(id)').eq('household_id', pData.household_id).eq('status', 'active'),
          supabase.from('categories').select('*').eq('household_id', pData.household_id),
          supabase.from('profiles').select('id, name').eq('household_id', pData.household_id)
        ]);

        setAccounts(accRes.data || []);
        setRecent(txsRes.data || []);
        setRecurring(recRes.data || []);
        
        const standaloneDebts = (debtsRes.data || []).filter((d: any) => !d.recurring_events || d.recurring_events.length === 0);
        setDebts(standaloneDebts);
        
        setCategories(catsRes.data || []);
        setMembers(memsRes.data || []);
      }
    } catch (error) {
      console.warn("Error fetching dashboard:", error);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useFocusEffect(
    useCallback(() => {
      fetchDashboardData();
    }, [user])
  );

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    fetchDashboardData();
  }, [user]);

  if (loading) {
    return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;
  }

  const fmt = (n: number) => formatCurrency(n, currency);
  const CARD_WIDTH = Dimensions.get('window').width * 0.85;

  const totalBalance = accounts.reduce((s, a) => s + a.balance, 0);
  const income = recent.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
  const expenses = recent.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Buenos días' : hour < 19 ? 'Buenas tardes' : 'Buenas noches';
  const metaName = user?.user_metadata?.full_name || user?.user_metadata?.name || user?.user_metadata?.display_name;

  let rawName = metaName || profile?.name || user?.email?.split('@')[0] || '';
  if (rawName.includes('@')) rawName = rawName.split('@')[0];

  let firstName = rawName.trim().split(' ')[0];
  if (firstName) firstName = firstName.charAt(0).toUpperCase() + firstName.slice(1);

  const todayMillis = new Date();
  todayMillis.setHours(0,0,0,0);
  
  const formattedDebts = debts.map(d => ({
    id: d.id,
    name: `Deuda: ${d.description || d.person_name}`,
    amount: d.amount - (d.amount_paid || 0),
    categories: d.categories,
    type: d.direction === 'owed_to_us' ? 'income' : 'expense',
    next_date: d.due_date ? `${d.due_date}T12:00:00` : null,
    isDebt: true,
  })).filter(d => d.next_date);

  const combinedEvents = [...recurring, ...formattedDebts];

  const pendingRecurring = combinedEvents.filter(ev => {
    if (!ev.next_date) return false;
    const [y, m, d] = ev.next_date.split('T')[0].split('-');
    return new Date(Number(y), Number(m) - 1, Number(d)).getTime() <= todayMillis.getTime();
  });
  const upcomingRecurring = combinedEvents.filter(ev => {
    if (!ev.next_date) return false;
    const [y, m, d] = ev.next_date.split('T')[0].split('-');
    return new Date(Number(y), Number(m) - 1, Number(d)).getTime() > todayMillis.getTime();
  });

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: theme.background }]}
      contentContainerStyle={[styles.content, { paddingTop: 20 }]}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.primary} />}
    >
      <View style={styles.topRow}>
        <View style={styles.header}>
          <Text style={[styles.greeting, { color: theme.text }]}>{greeting} {firstName},</Text>
          <Text style={[styles.heroSub, { color: theme.textMuted }]}>tu balance es</Text>
        </View>
      </View>

      <Text style={[styles.balanceAmount, { color: theme.text }]}>{fmt(totalBalance)}</Text>

      <View style={styles.trendsRow}>
        <View style={styles.trendItem}>
          <HugeiconsIcon icon={ArrowUp01Icon} color="#22C55E" size={16} />
          <View>
            <Text style={[styles.trendLabel, { color: theme.textMuted }]}>Ingresos</Text>
            <Text style={[styles.trendValue, { color: theme.text }]}>{fmt(income)}</Text>
          </View>
        </View>
        <View style={styles.trendItem}>
          <HugeiconsIcon icon={ArrowDown01Icon} color="#EF4444" size={16} />
          <View>
            <Text style={[styles.trendLabel, { color: theme.textMuted }]}>Gastos</Text>
            <Text style={[styles.trendValue, { color: theme.text }]}>{fmt(expenses)}</Text>
          </View>
        </View>
      </View>

      {accounts.length > 0 && (
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, { color: theme.text }]}>Tus Cuentas</Text>
            <TouchableOpacity onPress={() => router.push('/finances' as any)}>
              <Text style={[styles.seeAllText, { color: theme.primary }]}>Ver todo</Text>
            </TouchableOpacity>
          </View>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.accountsScroll}
            snapToInterval={CARD_WIDTH + 16}
            decelerationRate="fast"
          >
            {accounts.map(acc => (
              <TouchableOpacity
                key={acc.id}
                style={[styles.creditCard, { width: CARD_WIDTH, shadowColor: isDark ? '#000' : theme.text, shadowOpacity: isDark ? 0.1 : 0.05 }]}
                onPress={() => router.push(`/account/${acc.id}` as any)}
                onLongPress={() => router.push(`/edit-account?id=${acc.id}` as any)}
                delayLongPress={400}
              >
                <ImageBackground
                  source={require('../../assets/images/card-bg.png')}
                  style={styles.cardBg}
                  imageStyle={{ borderRadius: 24 }}
                  resizeMode="cover"
                >
                  <View style={[styles.cardOverlay, { backgroundColor: isDark ? 'rgba(0,0,0,0.2)' : 'rgba(255,255,255,0.1)' }]}>
                    <View style={styles.cardTop}>
                      <Text style={[styles.cardName, { color: isDark ? '#FFFFFF' : '#18181B', textShadowColor: isDark ? 'rgba(0,0,0,0.3)' : 'transparent' }]}>{acc.name}</Text>
                      <View style={[styles.chip, { borderColor: isDark ? 'rgba(255,255,255,0.6)' : 'rgba(0,0,0,0.2)' }]}><View style={[styles.chipLine, { backgroundColor: isDark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.15)' }]} /></View>
                    </View>
                    <View style={styles.cardBottom}>
                      <View>
                        <Text style={[styles.cardSub, { color: isDark ? 'rgba(255,255,255,0.8)' : 'rgba(0,0,0,0.6)' }]}>{acc.type}</Text>
                        <Text style={[styles.cardBalance, { color: isDark ? '#FFFFFF' : '#18181B', textShadowColor: isDark ? 'rgba(0,0,0,0.3)' : 'transparent' }]}>{fmt(acc.balance)}</Text>
                      </View>
                      <View style={styles.mcLogo}>
                        <View style={[styles.mcCircle, { backgroundColor: '#EF4444', marginRight: -12 }]} />
                        <View style={[styles.mcCircle, { backgroundColor: '#F59E0B' }]} />
                      </View>
                    </View>
                  </View>
                </ImageBackground>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      )}

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Text style={[styles.sectionTitle, { color: theme.text }]}>Últimas transacciones</Text>
          <TouchableOpacity onPress={() => router.push('/transactions' as any)}>
            <Text style={[styles.seeAllText, { color: theme.primary }]}>Ver todo</Text>
          </TouchableOpacity>
        </View>
        <View style={styles.listContainer}>
          {recent.length === 0 ? (
            <Text style={[styles.emptyText, { color: theme.textMuted }]}>No hay movimientos recientes</Text>
          ) : recent.map((tx, index) => {
            const cat = categories.find(c => c.id === tx.category_id);
            const creator = members.find(m => m.id === tx.created_by);
            return (
              <TransactionItem
                key={tx.id}
                tx={tx}
                category={cat}
                creator={creator}
                currency={currency}
                isLast={index === recent.length - 1}
                onPress={() => router.push({ pathname: '/transaction/[id]', params: { id: tx.id, txData: JSON.stringify(tx) } } as any)}
                onLongPress={() => router.push(`/edit-transaction?id=${tx.id}` as any)}
              />
            );
          })}
        </View>
      </View>

      {/* PAGOS PENDIENTES */}
      {pendingRecurring.length > 0 && (
        <View style={[styles.section, { marginBottom: 32 }]}>
          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, { color: '#F59E0B' }]}>Pagos pendientes</Text>
            <TouchableOpacity onPress={() => router.push('/calendar' as any)}>
              <Text style={[styles.seeAllText, { color: theme.primary }]}>Ver todo</Text>
            </TouchableOpacity>
          </View>
          <View style={styles.listContainer}>
            {pendingRecurring.map((ev, index) => {
              const matchedLogo = SUBSCRIPTION_LOGOS.find(
                l => l.id !== 'none' && (l.id === ev.logo_id || l.name.toLowerCase() === ev.name.toLowerCase())
              );
              return (
                <TouchableOpacity
                  key={ev.id}
                  style={[styles.listItem, { borderBottomColor: theme.border }, index === pendingRecurring.length - 1 && { borderBottomWidth: 0 }]}
                  activeOpacity={0.7}
                  onPress={() => router.push(ev.isDebt ? `/debt/${ev.id}` as any : `/recurring/${ev.id}` as any)}
                  onLongPress={() =>
                    Alert.alert(
                      ev.name,
                      '¿Qué deseas hacer?',
                      [
                        { text: 'Editar', onPress: () => router.push(`/edit-recurring?id=${ev.id}` as any) },
                        {
                          text: 'Eliminar', style: 'destructive', onPress: async () => {
                            const { error } = await supabase.from('recurring_events').delete().eq('id', ev.id);
                            if (!error) fetchDashboardData();
                          }
                        },
                        { text: 'Cancelar', style: 'cancel' },
                      ]
                    )
                  }
                >
                  <View style={styles.listLeft}>
                    <View style={[styles.iconBox, { backgroundColor: ev.categories?.color || theme.pillBg }]}>
                      {matchedLogo ? (
                        <Image source={matchedLogo.logo} style={styles.logoImg} resizeMode="contain" />
                      ) : ev.categories ? (
                        <DynamicIcon name={ev.categories.icon} size={14} color={theme.background} />
                      ) : (
                        <HugeiconsIcon icon={Calendar01Icon} size={22} color={theme.textMuted} />
                      )}
                    </View>
                    <View style={styles.listTextCol}>
                      <Text style={[styles.listName, { color: theme.text }]}>{ev.name}</Text>
                      <Text style={[styles.listSub, { color: '#F59E0B' }]}>{getRelativeDateText(ev.next_date)} · {translateFreq(ev.frequency)} · Pendiente</Text>
                    </View>
                  </View>
                  <Text style={[styles.listAmount, { color: ev.type === 'income' ? '#22C55E' : theme.text }]}>
                    {ev.type === 'income' ? '+' : '-'}{fmt(ev.amount)}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>
      )}

      {/* PRÓXIMOS PAGOS */}
      <View style={[styles.section, { marginBottom: 40 }]}>
        <View style={styles.sectionHeader}>
          <Text style={[styles.sectionTitle, { color: theme.text }]}>Próximos pagos</Text>
          <TouchableOpacity onPress={() => router.push('/calendar' as any)}>
            <Text style={[styles.seeAllText, { color: theme.primary }]}>Ver todo</Text>
          </TouchableOpacity>
        </View>
        <View style={styles.listContainer}>
          {upcomingRecurring.length === 0 ? (
            <Text style={[styles.emptyText, { color: theme.textMuted }]}>Sin eventos próximos</Text>
          ) : upcomingRecurring.map((ev, index) => {
            const matchedLogo = SUBSCRIPTION_LOGOS.find(
              l => l.id !== 'none' && (l.id === ev.logo_id || l.name.toLowerCase() === ev.name.toLowerCase())
            );
            return (
              <TouchableOpacity
                key={ev.id}
                style={[styles.listItem, { borderBottomColor: theme.border }, index === upcomingRecurring.length - 1 && { borderBottomWidth: 0 }]}
                activeOpacity={0.7}
                onPress={() => router.push(ev.isDebt ? `/debt/${ev.id}` as any : `/recurring/${ev.id}` as any)}
                onLongPress={() =>
                  Alert.alert(
                    ev.name,
                    '¿Qué deseas hacer?',
                    [
                      { text: 'Editar', onPress: () => router.push(`/edit-recurring?id=${ev.id}` as any) },
                      {
                        text: 'Eliminar', style: 'destructive', onPress: async () => {
                          const { error } = await supabase.from('recurring_events').delete().eq('id', ev.id);
                          if (!error) fetchDashboardData();
                        }
                      },
                      { text: 'Cancelar', style: 'cancel' },
                    ]
                  )
                }
              >
                <View style={styles.listLeft}>
                  <View style={[styles.iconBox, { backgroundColor: ev.categories?.color || theme.pillBg }]}>
                    {matchedLogo ? (
                      <Image source={matchedLogo.logo} style={styles.logoImg} resizeMode="contain" />
                    ) : ev.categories ? (
                      <DynamicIcon name={ev.categories.icon} size={14} color={theme.background} />
                    ) : (
                      <HugeiconsIcon icon={Calendar01Icon} size={22} color={theme.textMuted} />
                    )}
                  </View>
                  <View style={styles.listTextCol}>
                    <Text style={[styles.listName, { color: theme.text }]}>{ev.name}</Text>
                    <Text style={[styles.listSub, { color: theme.textMuted }]}>{getRelativeDateText(ev.next_date)} · {translateFreq(ev.frequency)}</Text>
                  </View>
                </View>
                <Text style={[styles.listAmount, { color: ev.type === 'income' ? '#22C55E' : theme.text }]}>
                  {ev.type === 'income' ? '+' : '-'}{fmt(ev.amount)}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { paddingBottom: 100 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  topRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', paddingHorizontal: 20 },
  header: { flex: 1 },
  greeting: { fontSize: 24, fontWeight: '700' },
  heroSub: { fontSize: 22, fontWeight: '500', marginTop: 4 },
  balanceAmount: { fontSize: 44, fontWeight: '800', letterSpacing: -1, paddingHorizontal: 20, marginTop: 16, marginBottom: 24, fontVariant: ['tabular-nums'] },

  trendsRow: { flexDirection: 'row', gap: 24, paddingHorizontal: 20, marginBottom: 32 },
  trendItem: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  trendLabel: { fontSize: 13, marginBottom: 2 },
  trendValue: { fontSize: 16, fontWeight: '700', fontVariant: ['tabular-nums'] },

  section: { marginBottom: 32 },
  sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, marginBottom: 16 },
  sectionTitle: { fontSize: 18, fontWeight: '600' },
  seeAllText: { fontSize: 14, fontWeight: '500' },

  accountsScroll: { paddingHorizontal: 20, gap: 16 },
  creditCard: { height: 200, borderRadius: 24, shadowOffset: { width: 0, height: 4 }, shadowRadius: 8, elevation: 4 },
  cardBg: { flex: 1, borderRadius: 24 },
  cardOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 24, padding: 20, justifyContent: 'space-between' },
  cardTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  cardName: { fontSize: 18, color: '#FFFFFF', fontWeight: '700', letterSpacing: 1, textShadowColor: 'rgba(0,0,0,0.3)', textShadowOffset: { width: 0, height: 2 }, textShadowRadius: 4 },
  chip: { width: 34, height: 24, borderRadius: 6, borderWidth: 1, borderColor: 'rgba(255,255,255,0.6)', justifyContent: 'center', alignItems: 'center' },
  chipLine: { width: '100%', height: 1, backgroundColor: 'rgba(255,255,255,0.4)' },
  cardBottom: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  cardSub: { fontSize: 12, color: 'rgba(255,255,255,0.8)', textTransform: 'uppercase', letterSpacing: 1.5, marginBottom: 4 },
  cardBalance: { fontSize: 26, fontWeight: '800', color: '#FFFFFF', letterSpacing: 1, textShadowColor: 'rgba(0,0,0,0.3)', textShadowOffset: { width: 0, height: 2 }, textShadowRadius: 4, fontVariant: ['tabular-nums'] },
  mcLogo: { flexDirection: 'row', alignItems: 'center' },
  mcCircle: { width: 32, height: 32, borderRadius: 16, opacity: 0.85 },

  listContainer: { paddingHorizontal: 20 },
  emptyText: { fontSize: 14, textAlign: 'center', marginVertical: 12 },
  listItem: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 14, borderBottomWidth: 1 },
  listLeft: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  iconBox: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
  iconEmoji: { fontSize: 20 },
  listTextCol: { justifyContent: 'center' },
  listName: { fontSize: 16, fontWeight: '600' },
  listSub: { fontSize: 13, marginTop: 2 },
  listAmount: { fontSize: 16, fontWeight: '700', fontVariant: ['tabular-nums'] },
  logoImg: { width: 34, height: 34 },
});
