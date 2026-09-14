import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, TouchableOpacity, Image } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { formatCurrency, formatShortDate } from '@jojos/core';
import { useFocusEffect, useRouter } from 'expo-router';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ArrowLeft01Icon, ArrowRight01Icon, Menu01Icon, PlusSignIcon, Calendar01Icon, Alert01Icon } from '@hugeicons/core-free-icons';
import { useTheme } from '../../src/context/ThemeContext';
import { SUBSCRIPTION_LOGOS } from '../../src/data/SubscriptionLogos';
import DynamicIcon from '../../src/components/DynamicIcon';

const DAYS_OF_WEEK = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

export default function CalendarScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [loadingTxs, setLoadingTxs] = useState(false);
  const [fetchedMonthStr, setFetchedMonthStr] = useState<string>('');
  const [recurring, setRecurring] = useState<any[]>([]);
  const [debts, setDebts] = useState<any[]>([]);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [members, setMembers] = useState<any[]>([]);
  const [selectedDay, setSelectedDay] = useState<number | null>(null);
  const [currentDate, setCurrentDate] = useState(new Date());
  const [currency, setCurrency] = useState('USD');
  const { theme } = useTheme();

  const fetchCalendar = async () => {
    if (!user) return;
    try {
      const { data: pData } = await supabase.from('profiles').select('household_id, currency').eq('id', user.id).single();
      if (pData?.currency) setCurrency(pData.currency);
      if (pData?.household_id) {
        // Fetch recurring events
        // Fetch recurring events
        const [recRes, debtsRes, memsRes] = await Promise.all([
          supabase.from('recurring_events').select('*, categories (name, icon, color)').eq('household_id', pData.household_id).eq('is_active', true).order('next_date'),
          supabase.from('debts').select('*, categories(name, icon, color), recurring_events(id)').eq('household_id', pData.household_id).eq('status', 'active'),
          supabase.from('profiles').select('id, name').eq('household_id', pData.household_id)
        ]);
        setRecurring(recRes.data || []);
        
        const standaloneDebts = (debtsRes.data || []).filter((d: any) => !d.recurring_events || d.recurring_events.length === 0);
        setDebts(standaloneDebts);
        setMembers(memsRes.data || []);

        // Fetch transactions for the current month view
        const targetMonthStr = `${currentDate.getFullYear()}-${currentDate.getMonth()}`;
        if (fetchedMonthStr !== targetMonthStr) {
          setLoadingTxs(true);
        }

        const start = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
        start.setHours(0,0,0,0);
        const end = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0, 23, 59, 59);

        const { data: txs } = await supabase.from('transactions')
          .select('*, categories (name, icon, color)')
          .eq('household_id', pData.household_id)
          .gte('date', start.toISOString())
          .lte('date', end.toISOString())
          .order('date');
        
        setTransactions(txs || []);
        setFetchedMonthStr(targetMonthStr);
      }
    } catch (e) {
      console.warn(e);
    } finally {
      if (loading) setLoading(false);
      setLoadingTxs(false);
    }
  };

  useFocusEffect(useCallback(() => { fetchCalendar(); }, [user, currentDate]));

  const changeMonth = (offset: number) => {
    setSelectedDay(null);
    setCurrentDate(prev => {
      const nd = new Date(prev);
      nd.setMonth(nd.getMonth() + offset);
      return nd;
    });
  };

  const getDaysInMonth = (date: Date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const firstDay = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();

    const days = [];
    for (let i = 0; i < firstDay; i++) days.push(null);
    for (let i = 1; i <= daysInMonth; i++) days.push(i);
    return days;
  };

  const days = getDaysInMonth(currentDate);
  const monthName = new Intl.DateTimeFormat('es', { month: 'long', year: 'numeric' }).format(currentDate);

  const parseLocalDate = (dateString: string) => {
    if (!dateString) return new Date();
    const [y, m, d] = dateString.split('T')[0].split('-');
    return new Date(Number(y), Number(m) - 1, Number(d));
  };

  const getRelativeDateText = (dateString: string) => {
    if (!dateString) return '';
    const date = parseLocalDate(dateString);
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

  const getOccurrencesInMonth = (ev: any, year: number, month: number) => {
    const nextD = parseLocalDate(ev.next_date);
    const startOfMonth = new Date(year, month, 1).getTime();
    const endOfMonth = new Date(year, month + 1, 0, 23, 59, 59).getTime();
    const occurrences = [];
    let current = new Date(nextD);
    if (current.getTime() > endOfMonth) return [];
    let safety = 0;
    while (current.getTime() <= endOfMonth && safety < 50) {
      safety++;
      if (current.getTime() >= startOfMonth) occurrences.push(new Date(current));
      if (ev.frequency === 'monthly') current.setMonth(current.getMonth() + 1);
      else if (ev.frequency === 'yearly') current.setFullYear(current.getFullYear() + 1);
      else if (ev.frequency === 'weekly') current.setDate(current.getDate() + 7);
      else if (ev.frequency === 'biweekly') current.setDate(current.getDate() + 14);
      else break;
    }
    return occurrences;
  };

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

  const pendingEventsRaw = [...recurring, ...formattedDebts].filter(ev => {
    const d = parseLocalDate(ev.next_date);
    return d.getTime() <= todayMillis.getTime();
  });

  const pendingEvents = selectedDay 
    ? pendingEventsRaw.filter(ev => parseLocalDate(ev.next_date).getDate() === selectedDay)
    : pendingEventsRaw;

  let allMonthEvents: any[] = [];
  recurring.forEach(ev => {
    const occs = getOccurrencesInMonth(ev, currentDate.getFullYear(), currentDate.getMonth());
    occs.forEach(occ => {
      // Excluir si ya está en Pendientes en esta misma fecha virtual porque está trazado localmente.
      if (occ.getTime() > todayMillis.getTime()) {
        const occStr = `${occ.getFullYear()}-${String(occ.getMonth()+1).padStart(2,'0')}-${String(occ.getDate()).padStart(2,'0')}T12:00:00`;
        allMonthEvents.push({ ...ev, projected_date: occStr });
      }
    });
  });

  formattedDebts.forEach(ev => {
    const d = parseLocalDate(ev.next_date as string);
    if (d.getTime() > todayMillis.getTime() && d.getMonth() === currentDate.getMonth() && d.getFullYear() === currentDate.getFullYear()) {
      allMonthEvents.push({ ...ev, projected_date: ev.next_date });
    }
  });

  const displayedEvents = selectedDay 
    ? allMonthEvents.filter(ev => parseLocalDate(ev.projected_date).getDate() === selectedDay)
    : allMonthEvents;

  const currentMonthTransactions = transactions.filter(tx => {
    const d = parseLocalDate(tx.date);
    return d.getMonth() === currentDate.getMonth() && d.getFullYear() === currentDate.getFullYear();
  });

  const displayedTransactions = selectedDay 
    ? currentMonthTransactions.filter(tx => parseLocalDate(tx.date).getDate() === selectedDay)
    : currentMonthTransactions;

  if (loading) return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;

  const fmt = (n: number) => formatCurrency(n, currency);

  const renderLogos = (dayEvents: any[]) => {
    const count = dayEvents.length;
    if (count === 0) return null;

    const renderBadge = (matchedLogo: any, key: number, extraStyle?: any, text?: string, ev?: any) => (
      <View key={key} style={[styles.logoBadgeWrap, extraStyle, ev?.categories ? { backgroundColor: ev.categories.color } : {}]}>
        {text ? (
          <Text style={{ fontSize: 10, color: '#fff', fontWeight: 'bold' }}>{text}</Text>
        ) : matchedLogo ? (
          <Image source={matchedLogo.logo} style={styles.tinyLogo} resizeMode="contain" />
        ) : ev?.categories ? (
          <DynamicIcon name={ev.categories.icon} size={14} color={theme.background} />
        ) : (
          <View style={[styles.tinyFallback, { backgroundColor: theme.textMuted }]} />
        )}
      </View>
    );

    const getMatchedLogo = (ev: any) => {
      let titleToMatch = '';
      let logoIdToMatch = null;

      if (ev._kind === 'recurring') {
        titleToMatch = ev.name || '';
        logoIdToMatch = ev.logo_id;
      } else {
        titleToMatch = ev.description || '';
        if (ev.recurring_id) {
          logoIdToMatch = recurring.find(r => r.id === ev.recurring_id)?.logo_id;
        }
        if (!logoIdToMatch) {
          const parentRecurring = recurring.find(r => r.name === titleToMatch);
          if (parentRecurring) logoIdToMatch = parentRecurring.logo_id;
        }
      }

      if (!titleToMatch && !logoIdToMatch) return null;
      return SUBSCRIPTION_LOGOS.find(l => 
        l.id !== 'none' && 
        ((logoIdToMatch && l.id === logoIdToMatch) || (titleToMatch && l.name.toLowerCase() === titleToMatch.toLowerCase()))
      );
    };

    if (count === 1) {
      const ev = dayEvents[0];
      const matchedLogo = getMatchedLogo(ev);
      return renderBadge(matchedLogo, 0, undefined, undefined, ev);
    }

    if (count === 2) {
      return dayEvents.slice(0, 2).map((ev, i) => {
        const matchedLogo = getMatchedLogo(ev);
        return renderBadge(matchedLogo, i, {
          marginTop: i === 1 ? -8 : 0,
          zIndex: 2 - i
        }, undefined, ev);
      });
    }

    const showPlus = count > 4;
    const items = dayEvents.slice(0, showPlus ? 3 : 4);

    return (
      <>
        <View style={{ flexDirection: 'row' }}>
          {items.slice(0, 2).map((ev, i) => {
            const matchedLogo = getMatchedLogo(ev);
            return renderBadge(matchedLogo, i, {
              marginLeft: i === 1 ? -8 : 0,
              zIndex: 2 - i
            }, undefined, ev);
          })}
        </View>
        <View style={{ flexDirection: 'row', marginTop: -4 }}>
          {items.slice(2, 4).map((ev, i) => {
            const matchedLogo = getMatchedLogo(ev);
            return renderBadge(matchedLogo, i + 2, {
              marginLeft: i === 1 ? -8 : 0,
              zIndex: 2 - i
            }, undefined, ev);
          })}
          {showPlus && items.length === 3 && renderBadge(null, 3, {
            marginLeft: -8,
            zIndex: 0,
            backgroundColor: theme.border
          }, '+')}
        </View>
      </>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {/* Month Selector */}
        <View style={styles.monthHeader}>
          <Text style={[styles.monthText, { color: theme.text }]}>{monthName.charAt(0).toUpperCase() + monthName.slice(1)}</Text>
          <View style={styles.monthNav}>
            <TouchableOpacity style={[styles.navBtn, { backgroundColor: theme.card }]} onPress={() => changeMonth(-1)}>
              <HugeiconsIcon icon={ArrowLeft01Icon} size={20} color={theme.text} />
            </TouchableOpacity>
            <TouchableOpacity style={[styles.navBtn, { backgroundColor: theme.card }]} onPress={() => changeMonth(1)}>
              <HugeiconsIcon icon={ArrowRight01Icon} size={20} color={theme.text} />
            </TouchableOpacity>
          </View>
        </View>

        {/* Calendar Grid */}
        <View style={styles.calendarContainer}>
          <View style={styles.daysHeader}>
            {DAYS_OF_WEEK.map((d, i) => (
              <Text key={i} style={[styles.dayHeaderText, { color: theme.textMuted }]}>{d}</Text>
            ))}
          </View>

          <View style={styles.grid}>
            {days.map((dayNum, index) => {
              if (dayNum === null) return <View key={`empty-${index}`} style={styles.dayCellWrapper} />;

              const isToday = new Date().getDate() === dayNum && new Date().getMonth() === currentDate.getMonth() && new Date().getFullYear() === currentDate.getFullYear();
              const isSelected = selectedDay === dayNum;
              const dayEvents = displayedEvents.filter(ev => parseLocalDate(ev.projected_date).getDate() === dayNum);
              const dayTxs = currentMonthTransactions.filter(tx => parseLocalDate(tx.date).getDate() === dayNum);
              
              const allItems = [
                ...dayEvents.map(e => ({ ...e, _kind: 'recurring' })),
                ...dayTxs.map(t => ({ ...t, _kind: 'transaction' }))
              ];

              return (
                <TouchableOpacity 
                  key={`day-${dayNum}`} 
                  style={styles.dayCellWrapper}
                  activeOpacity={0.7}
                  onPress={() => setSelectedDay(isSelected ? null : dayNum)}
                >
                  <View style={[
                    styles.dayCell, 
                    { backgroundColor: theme.card }, 
                    isToday && { backgroundColor: theme.primary + '30', borderColor: theme.primary, borderWidth: 1 },
                    isSelected && { borderColor: theme.text, borderWidth: 1 }
                  ]}>
                    <Text style={[styles.dayText, { color: isToday ? theme.primary : isSelected ? theme.text : theme.text }]}>{dayNum}</Text>
                    {allItems.length > 0 && (
                      <View style={[styles.logosContainer, { gap: 0 }]}>
                        {renderLogos(allItems)}
                      </View>
                    )}
                  </View>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

        {/* Upcoming Section */}
        <View style={styles.upcomingSection}>
          
          {pendingEventsRaw.length > 0 && (
            <View style={{ marginBottom: 24 }}>
              <View style={styles.upcomingHeader}>
                <HugeiconsIcon icon={Alert01Icon} size={20} color="#F59E0B" />
                <Text style={[styles.upcomingTitle, { color: theme.text }]}>Pagos pendientes</Text>
                <Text style={[styles.upcomingCount, { color: theme.textMuted }]}>{pendingEvents.length}</Text>
              </View>
              <View style={styles.listContainer}>
                {pendingEvents.length === 0 ? (
                  <Text style={[styles.emptyText, { color: theme.textMuted }]}>Sin pagos pendientes en {selectedDay ? 'este día' : 'este mes'}</Text>
                ) : pendingEvents.map((ev, index) => {
                  const matchedLogo = SUBSCRIPTION_LOGOS.find(
                    l => l.id !== 'none' && (l.id === ev.logo_id || l.name.toLowerCase() === ev.name.toLowerCase())
                  );
                  return (
                    <TouchableOpacity
                      key={ev.id}
                      style={[styles.listItem, { borderBottomColor: theme.border }, index === pendingEvents.length - 1 && { borderBottomWidth: 0 }]}
                      activeOpacity={0.7}
                      onPress={() => router.push(ev.isDebt ? `/debt/${ev.id}` as any : `/recurring/${ev.id}` as any)}
                    >
                      <View style={styles.listLeft}>
                        <View style={[styles.iconBox, { backgroundColor: ev.categories?.color || theme.pillBg }]}>
                          {matchedLogo ? (
                            <Image source={matchedLogo.logo} style={styles.listLogoImg} resizeMode="contain" />
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

          <View style={styles.upcomingHeader}>
            <HugeiconsIcon icon={Calendar01Icon} size={20} color="#FB923C" />
            <Text style={[styles.upcomingTitle, { color: theme.text }]}>Próximos pagos</Text>
            <Text style={[styles.upcomingCount, { color: theme.textMuted }]}>{displayedEvents.length}</Text>
          </View>

          <View style={styles.listContainer}>
            {displayedEvents.length === 0 ? (
              <Text style={[styles.emptyText, { color: theme.textMuted }]}>Sin pagos en {selectedDay ? 'este día' : 'este mes'}</Text>
            ) : displayedEvents.map((ev, index) => {
              const matchedLogo = SUBSCRIPTION_LOGOS.find(
                l => l.id !== 'none' && (l.id === ev.logo_id || l.name.toLowerCase() === ev.name.toLowerCase())
              );
              return (
                <TouchableOpacity
                  key={ev.id}
                  style={[styles.listItem, { borderBottomColor: theme.border }, index === displayedEvents.length - 1 && { borderBottomWidth: 0 }]}
                  activeOpacity={0.7}
                  onPress={() => router.push(ev.isDebt ? `/debt/${ev.id}` as any : `/recurring/${ev.id}` as any)}
                >
                  <View style={styles.listLeft}>
                    <View style={[styles.iconBox, { backgroundColor: ev.categories?.color || theme.pillBg }]}>
                      {matchedLogo ? (
                        <Image source={matchedLogo.logo} style={styles.listLogoImg} resizeMode="contain" />
                      ) : ev.categories ? (
                        <DynamicIcon name={ev.categories.icon} size={14} color={theme.background} />
                      ) : (
                        <HugeiconsIcon icon={Calendar01Icon} size={22} color={theme.textMuted} />
                      )}
                    </View>
                    <View style={styles.listTextCol}>
                      <Text style={[styles.listName, { color: theme.text }]}>{ev.name}</Text>
                      <Text style={[styles.listSub, { color: theme.textMuted }]}>{getRelativeDateText(ev.projected_date)} · {translateFreq(ev.frequency)}</Text>
                    </View>
                  </View>
                  <Text style={[styles.listAmount, { color: ev.type === 'income' ? '#22C55E' : theme.text }]}>
                    {ev.type === 'income' ? '+' : '-'}{fmt(ev.amount)}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>

          {/* Transactions Section */}
          <View style={[styles.upcomingHeader, { marginTop: 24 }]}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <HugeiconsIcon icon={Calendar01Icon} size={20} color="#3B82F6" />
              <Text style={[styles.upcomingTitle, { color: theme.text }]}>Movimientos</Text>
            </View>
            {!loadingTxs && (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                <Text style={[styles.upcomingCount, { color: theme.textMuted }]}>{displayedTransactions.length}</Text>
              </View>
            )}
          </View>

          <View style={styles.listContainer}>
            {loadingTxs ? (
              <>
                {[1, 2, 3].map((sk: number) => (
                  <View key={sk} style={[styles.listItem, { borderBottomColor: theme.border }]}>
                    <View style={styles.listLeft}>
                      <View style={[styles.iconBox, { backgroundColor: theme.border }]} />
                      <View style={styles.listTextCol}>
                        <View style={{ width: 120, height: 14, backgroundColor: theme.border, borderRadius: 4, marginBottom: 6 }} />
                        <View style={{ width: 80, height: 12, backgroundColor: theme.border, borderRadius: 4 }} />
                      </View>
                    </View>
                    <View style={{ width: 60, height: 16, backgroundColor: theme.border, borderRadius: 4 }} />
                  </View>
                ))}
              </>
            ) : displayedTransactions.length === 0 ? (
              <Text style={[styles.emptyText, { color: theme.textMuted }]}>Sin movimientos en {selectedDay ? 'este día' : 'este mes'}</Text>
            ) : displayedTransactions.map((tx, index) => {
              const creator = members.find(m => m.id === tx.created_by);
              const creatorName = creator?.name || 'Usuario';
              const initial = creatorName.charAt(0).toUpperCase();

              return (
                <TouchableOpacity
                  key={tx.id}
                  style={[styles.listItem, { borderBottomColor: theme.border }, index === displayedTransactions.length - 1 && { borderBottomWidth: 0 }]}
                  activeOpacity={0.7}
                  onPress={() => router.push(`/transaction/${tx.id}` as any)}
                >
                  <View style={styles.listLeft}>
                  <View style={[styles.iconBox, { backgroundColor: theme.pillBg }]}>
                      <Text style={{ color: theme.text, fontSize: 16, fontWeight: '700' }}>{initial}</Text>
                    </View>
                    <View style={styles.listTextCol}>
                      <Text style={[styles.listName, { color: theme.text }]}>{tx.description || tx.categories?.name || 'Movimiento'}</Text>
                      <Text style={[styles.listSub, { color: theme.textMuted }]}>{getRelativeDateText(tx.date)} · {creatorName}</Text>
                    </View>
                  </View>
                  <Text style={[styles.listAmount, { color: tx.type === 'income' ? '#22C55E' : theme.text }]}>
                    {tx.type === 'income' ? '+' : '-'}{fmt(tx.amount)}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  content: { paddingBottom: 100, paddingTop: 16 },

  monthHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, marginBottom: 16 },
  monthText: { fontSize: 22, fontWeight: '700' },
  monthNav: { flexDirection: 'row', gap: 8 },
  navBtn: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center' },

  calendarContainer: { paddingHorizontal: 16, marginBottom: 32 },
  daysHeader: { flexDirection: 'row', marginBottom: 8 },
  dayHeaderText: { flex: 1, textAlign: 'center', fontSize: 13, fontWeight: '500' },
  grid: { flexDirection: 'row', flexWrap: 'wrap' },
  dayCellWrapper: { width: '14.28%', aspectRatio: 0.65, padding: 3 },
  dayCell: { flex: 1, borderRadius: 12, paddingTop: 8, paddingHorizontal: 4, alignItems: 'center' },
  dayText: { fontSize: 14, fontWeight: '600', marginBottom: 4 },
  logosContainer: { width: '100%', alignItems: 'center', gap: 2 },
  logoBadgeWrap: { width: 22, height: 22, borderRadius: 11, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  tinyLogo: { width: 14, height: 14 },
  tinyFallback: { width: 14, height: 14, borderRadius: 7 },
  moreEventsText: { fontSize: 10, fontWeight: 'bold' },

  upcomingSection: { marginTop: 16 },
  upcomingHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 20, marginBottom: 12 },
  upcomingTitle: { fontSize: 18, fontWeight: '700' },
  upcomingCount: { fontSize: 18, fontWeight: '600' },

  listContainer: { paddingHorizontal: 20 },
  emptyText: { fontSize: 14, textAlign: 'center', marginVertical: 24 },
  listItem: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 14, borderBottomWidth: 1 },
  listLeft: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  iconBox: { width: 22, height: 22, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
  listLogoImg: { width: 22, height: 22 },
  listTextCol: { justifyContent: 'center' },
  listName: { fontSize: 16, fontWeight: '600' },
  listSub: { fontSize: 13, marginTop: 2 },
  listAmount: { fontSize: 16, fontWeight: '700', fontVariant: ['tabular-nums'] },
});
