import React, { useState, useCallback, useRef, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, ActivityIndicator,
  RefreshControl, TouchableOpacity, Animated,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useFocusEffect } from 'expo-router';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ArrowLeft01Icon, ArrowRight01Icon, ArrowUp01Icon, ArrowDown01Icon } from '@hugeicons/core-free-icons';

import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { formatCurrency, monthRange } from '@jojos/core';
import { ComparisonBars, TrendLine, BudgetArch, BudgetProgress, getColor } from '../../src/components/Charts';
import { useTheme } from '../../src/context/ThemeContext';
import DynamicIcon from '../../src/components/DynamicIcon';


const MONTHS_SHORT = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
const MONTHS_LONG  = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

export default function ReportsScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();

  const [loading, setLoading]           = useState(true);
  const [refreshing, setRefreshing]     = useState(false);
  const [currency, setCurrency]         = useState('USD');
  const [currentDate, setCurrentDate]   = useState(new Date());
  const [currentTxs, setCurrentTxs]     = useState<any[]>([]);
  const [categories, setCategories]     = useState<any[]>([]);
  const [budgets, setBudgets]           = useState<any[]>([]);
  const [monthlyHistory, setMonthlyHistory] = useState<any[]>([]);
  const [activeTab, setActiveTab]       = useState<'expense' | 'income'>('expense');

  const fetchReports = async () => {
    if (!user) return;
    try {
      const { data: pData } = await supabase
        .from('profiles').select('household_id, currency').eq('id', user.id).single();
      if (pData?.currency) setCurrency(pData.currency);
      if (!pData?.household_id) return;

      const { start, end } = monthRange(currentDate);

      const { data: txs } = await supabase
        .from('transactions').select('amount, type, category_id')
        .eq('household_id', pData.household_id)
        .gte('date', start).lte('date', end);
      setCurrentTxs(txs || []);

      const { data: cats } = await supabase
        .from('categories').select('*').eq('household_id', pData.household_id);
      setCategories(cats || []);

      const monthStart = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1).toISOString().split('T')[0];
      const { data: buds } = await supabase
        .from('budgets').select('*, categories(name, icon)')
        .eq('household_id', pData.household_id).eq('period', 'monthly').gte('start_date', monthStart);
      setBudgets(buds || []);

      const history: any[] = [];
      for (let i = 5; i >= 0; i--) {
        const d = new Date(currentDate.getFullYear(), currentDate.getMonth() - i, 1);
        const { start: s, end: e } = monthRange(d);
        const { data: hist } = await supabase.from('transactions').select('amount, type')
          .eq('household_id', pData.household_id).gte('date', s).lte('date', e);
        const inc = (hist || []).filter(t => t.type === 'income').reduce((a, t) => a + t.amount, 0);
        const exp = (hist || []).filter(t => t.type === 'expense').reduce((a, t) => a + t.amount, 0);
        history.push({ label: MONTHS_SHORT[d.getMonth()], income: inc, expense: exp });
      }
      setMonthlyHistory(history);
    } catch (e) { console.warn(e); }
    finally { setLoading(false); setRefreshing(false); }
  };

  useFocusEffect(useCallback(() => { fetchReports(); }, [user, currentDate]));
  const onRefresh = useCallback(() => { setRefreshing(true); fetchReports(); }, [user, currentDate]);

  const changeMonth = (delta: number) =>
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + delta, 1));

  // ── Skeleton pulse animation ──────────────────────────────
  const pulse = useRef(new Animated.Value(0.3)).current;
  useEffect(() => {
    if (!loading) return;
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 700, useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0.3, duration: 700, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [loading]);

  const Bone = ({ w, h = 14, mt = 0, mb = 0 }: { w: number | string; h?: number; mt?: number; mb?: number }) => (
    <Animated.View
      style={{
        width: w as any,
        height: h,
        borderRadius: h / 2,
        backgroundColor: isDark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.07)',
        opacity: pulse,
        marginTop: mt,
        marginBottom: mb,
      }}
    />
  );

  if (loading && currentTxs.length === 0) {
    const divBg = isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)';
    return (
      <View style={[s.container, { backgroundColor: theme.background }]}>
        {/* header */}
        <View style={[s.header, { paddingTop: Math.max(insets.top, 16) }]}>
          <Bone w={130} h={22} />
          <Bone w={90} h={14} />
        </View>

        <ScrollView contentContainerStyle={[s.scroll, { paddingBottom: 60 }]} scrollEnabled={false}>
          {/* hero */}
          <View style={[s.heroBlock, { gap: 10 }]}>
            <Bone w={80} h={11} />
            <Bone w={180} h={40} />
            <View style={{ flexDirection: 'row', gap: 40, marginTop: 12 }}>
              <View style={{ gap: 8 }}>
                <Bone w={60} h={10} />
                <Bone w={110} h={18} />
              </View>
              <View style={{ gap: 8 }}>
                <Bone w={60} h={10} />
                <Bone w={110} h={18} />
              </View>
            </View>
          </View>

          <View style={{ height: 1, backgroundColor: divBg }} />

          {/* tabs */}
          <View style={[s.tabBlock, { paddingVertical: 16 }]}>
            <Bone w={60} h={12} />
            <View style={{ marginLeft: 24 }}><Bone w={60} h={12} /></View>
          </View>

          <View style={{ height: 1, backgroundColor: divBg }} />

          {/* comparison bars */}
          <View style={[s.block, { gap: 12 }]}>
            <Bone w={120} h={10} />
            <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: 6, height: 140 }}>
              {[80, 50, 60, 90, 70, 110, 45, 100, 55, 130, 75, 140].map((h, i) => (
                <Animated.View
                  key={i}
                  style={{
                    width: 14, height: h, borderRadius: 3,
                    backgroundColor: isDark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.07)',
                    opacity: pulse,
                  }}
                />
              ))}
            </View>
          </View>

          <View style={{ height: 1, backgroundColor: divBg }} />

          {/* category list */}
          <View style={[s.block, { gap: 16 }]}>
            <Bone w={140} h={10} />
            {[100, 70, 55].map((w, i) => (
              <View key={i} style={{ gap: 8 }}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                    <Bone w={16} h={16} />
                    <Bone w={w} h={12} />
                  </View>
                  <View style={{ alignItems: 'flex-end', gap: 4 }}>
                    <Bone w={70} h={12} />
                    <Bone w={30} h={9} />
                  </View>
                </View>
                <Bone w={'100%'} h={2} />
              </View>
            ))}
          </View>

          <View style={{ height: 1, backgroundColor: divBg }} />

          {/* trend */}
          <View style={[s.block, { gap: 12 }]}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Bone w={140} h={10} />
              <Bone w={80} h={10} />
            </View>
            {/* fake line chart: dots at varying heights */}
            <View style={{ height: 140, justifyContent: 'flex-end' }}>
              <Bone w={'100%'} h={3} />
            </View>
          </View>
        </ScrollView>
      </View>
    );
  }

  const fmt = (n: number) => formatCurrency(n, currency);

  const tIncome   = currentTxs.filter(t => t.type === 'income').reduce((a, t) => a + t.amount, 0);
  const tExpenses = currentTxs.filter(t => t.type === 'expense').reduce((a, t) => a + t.amount, 0);
  const balance   = tIncome - tExpenses;
  const balPos    = balance >= 0;

  const byCategory: Record<string, number> = {};
  currentTxs.filter(t => t.type === activeTab).forEach(t => {
    if (t.category_id) byCategory[t.category_id] = (byCategory[t.category_id] || 0) + t.amount;
  });
  const tabTotal = Object.values(byCategory).reduce((s, v) => s + v, 0);

  const donutData = Object.entries(byCategory)
    .map(([catId, value], i) => {
      const cat = categories.find(c => c.id === catId);
      return { label: cat?.name ?? 'Otro', icon: cat?.icon, value, displayValue: fmt(value), color: getColor(i, isDark) };
    })
    .sort((a, b) => b.value - a.value);

  const trendData = monthlyHistory.map(h => ({
    label: h.label,
    value: activeTab === 'income' ? h.income : h.expense,
  }));
  const trendColor = activeTab === 'income' ? '#22C55E' : '#EF4444';

  const budgetRows = budgets.map(b => {
    const spent = currentTxs
      .filter(t => t.category_id === b.category_id && t.type === 'expense')
      .reduce((s, t) => s + t.amount, 0);
    return { ...b, spent };
  });

  // Separator line
  const Divider = () => <View style={[s.divider, { backgroundColor: isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)' }]} />;

  return (
    <View style={[s.container, { backgroundColor: theme.background }]}>

      {/* ── Header ─────────────────────────── */}
      <View style={[s.header, { paddingTop: Math.max(insets.top, 16) }]}>
        <Text style={[s.title, { color: theme.text }]}>Estadísticas</Text>
        <View style={s.monthRow}>
          <TouchableOpacity onPress={() => changeMonth(-1)} hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}>
            <HugeiconsIcon icon={ArrowLeft01Icon} size={14} color={theme.textMuted} />
          </TouchableOpacity>
          <Text style={[s.monthLabel, { color: theme.textMuted }]}>
            {MONTHS_SHORT[currentDate.getMonth()].toUpperCase()} {currentDate.getFullYear()}
          </Text>
          <TouchableOpacity onPress={() => changeMonth(1)} hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}>
            <HugeiconsIcon icon={ArrowRight01Icon} size={14} color={theme.textMuted} />
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView
        contentContainerStyle={[s.scroll, { paddingBottom: insets.bottom + 100 }]}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.textMuted} />}
        showsVerticalScrollIndicator={false}
      >

        {/* ── Balance principal ─────────────── */}
        <View style={s.heroBlock}>
          <Text style={[s.heroLabel, { color: theme.textMuted }]}>Balance neto</Text>
          <Text style={[s.heroAmount, { color: theme.text }]}>
            {balPos ? '+' : '-'}{fmt(Math.abs(balance))}
          </Text>
          <View style={s.heroKpis}>
            <View style={s.kpiItem}>
              <View style={s.kpiTitleRow}>
                <HugeiconsIcon icon={ArrowUp01Icon} size={12} color="#22C55E" />
                <Text style={[s.kpiLabel, { color: theme.textMuted }]}>Ingresos</Text>
              </View>
              <Text style={[s.kpiValue, { color: theme.text }]}>{fmt(tIncome)}</Text>
            </View>
            <View style={[s.kpiSep, { backgroundColor: isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)' }]} />
            <View style={s.kpiItem}>
              <View style={s.kpiTitleRow}>
                <HugeiconsIcon icon={ArrowDown01Icon} size={12} color="#EF4444" />
                <Text style={[s.kpiLabel, { color: theme.textMuted }]}>Gastos</Text>
              </View>
              <Text style={[s.kpiValue, { color: theme.text }]}>{fmt(Math.abs(tExpenses))}</Text>
            </View>
          </View>
        </View>

        <Divider />

        {/* ── Tab ══════════════════════════ */}
        <View style={s.tabBlock}>
          {(['expense', 'income'] as const).map(tab => {
            const active = activeTab === tab;
            const col = tab === 'income' ? '#22C55E' : '#EF4444';
            return (
              <TouchableOpacity key={tab} style={s.tabItem} onPress={() => setActiveTab(tab)}>
                <Text style={[s.tabText, { color: active ? col : theme.textMuted }]}>
                  {tab === 'expense' ? 'Gastos' : 'Ingresos'}
                </Text>
                {active && <View style={[s.tabUnderline, { backgroundColor: col }]} />}
              </TouchableOpacity>
            );
          })}
        </View>

        <Divider />

        {/* ── Comparison Bar Chart ────────────────────── */}
        <View style={s.block}>
          <Text style={[s.blockTitle, { color: theme.textMuted }]}>Ingresos vs Gastos</Text>
          <ComparisonBars data={monthlyHistory} />
        </View>

        <Divider />

        {/* ── Lista de categorías ──────────── */}
        {donutData.length > 0 && (
          <View style={s.block}>
            <Text style={[s.blockTitle, { color: theme.textMuted }]}>
              {activeTab === 'expense' ? 'Gastos' : 'Ingresos'} — por categoría
            </Text>
            {donutData.map((item, i) => {
              const pct = tabTotal > 0 ? Math.round((item.value / tabTotal) * 100) : 0;
              return (
                <View key={i}>
                  <View style={s.catRow}>
                    {/* Icon */}
                    <View style={s.catIconBox}>
                      {item.icon
                        ? <DynamicIcon name={item.icon} size={14} color={item.color} />
                        : <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: item.color }} />
                      }
                    </View>
                    {/* Name */}
                    <Text style={[s.catName, { color: theme.text }]} numberOfLines={1}>{item.label}</Text>
                    {/* Right */}
                    <View style={s.catRight}>
                      <Text style={[s.catAmount, { color: theme.text }]}>{item.displayValue}</Text>
                      <Text style={[s.catPct, { color: item.color }]}>{pct}%</Text>
                    </View>
                  </View>
                  {/* Thin bar */}
                  <View style={[s.barTrack, { backgroundColor: isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)' }]}>
                    <View style={[s.barFill, { width: `${pct}%`, backgroundColor: item.color }]} />
                  </View>
                  {i < donutData.length - 1 && (
                    <View style={[s.catDivider, { backgroundColor: isDark ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.04)' }]} />
                  )}
                </View>
              );
            })}
          </View>
        )}

        <Divider />

        {/* ── Tendencia ─────────────────── */}
        <View style={s.block}>
          <View style={s.trendHeader}>
            <Text style={[s.blockTitle, { color: theme.textMuted }]}>
              {activeTab === 'income' ? 'Tendencia ingresos' : 'Tendencia gastos'}
            </Text>
            <Text style={[s.trendTotal, { color: trendColor }]}>
              {MONTHS_SHORT[currentDate.getMonth()].toUpperCase()}  {fmt(activeTab === 'income' ? tIncome : tExpenses)}
            </Text>
          </View>
          <TrendLine data={trendData} color={trendColor} />
        </View>

        {/* ── Presupuesto ──────────────── */}
        {activeTab === 'expense' && budgetRows.length > 0 && (
          <>
            <Divider />
            <View style={s.block}>
              <Text style={[s.blockTitle, { color: theme.textMuted }]}>Presupuesto mensual</Text>
              <BudgetArch
                spent={budgetRows.reduce((s, b) => s + b.spent, 0)}
                limit={budgetRows.reduce((s, b) => s + b.amount, 0)}
                currency={currency === 'USD' ? '$' : currency}
              />
              <View style={{ marginTop: 12 }}>
                {budgetRows.map(b => (
                  <BudgetProgress
                    key={b.id}
                    name={b.categories?.name ?? 'Categoría'}
                    icon={b.categories?.icon}
                    spent={b.spent}
                    limit={b.amount}
                  />
                ))}
              </View>
            </View>
          </>
        )}

      </ScrollView>
    </View>
  );
}

const s = StyleSheet.create({
  container: { flex: 1 },
  center:    { flex: 1, alignItems: 'center', justifyContent: 'center' },

  // Header — raw, no background
  header: {
    paddingHorizontal: 20,
    paddingBottom: 14,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: { fontSize: 22, fontWeight: '700', letterSpacing: -0.5 },
  monthRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  monthLabel: { fontSize: 11, fontWeight: '700', letterSpacing: 1.5 },

  scroll: { paddingBottom: 40 },

  divider: { height: 1, marginHorizontal: 0 },

  // Hero block
  heroBlock: { paddingHorizontal: 20, paddingVertical: 24 },
  heroLabel:  { fontSize: 11, fontWeight: '600', letterSpacing: 1.2, textTransform: 'uppercase', marginBottom: 6 },
  heroAmount: { fontSize: 42, fontWeight: '800', letterSpacing: -2, marginBottom: 24 },
  heroKpis:   { flexDirection: 'row', alignItems: 'center', gap: 0 },
  kpiItem:    { flex: 1 },
  kpiSep:     { width: 1, height: 36, marginHorizontal: 20 },
  kpiTitleRow:{ flexDirection: 'row', alignItems: 'center', gap: 5, marginBottom: 4 },
  kpiLabel:   { fontSize: 11, fontWeight: '500', letterSpacing: 0.5 },
  kpiValue:   { fontSize: 17, fontWeight: '700' },

  // Tab toggle — line style, no container
  tabBlock: { flexDirection: 'row', paddingHorizontal: 20 },
  tabItem:  { marginRight: 28, paddingVertical: 14, position: 'relative' },
  tabText:  { fontSize: 13, fontWeight: '600', letterSpacing: 0.2 },
  tabUnderline: { position: 'absolute', bottom: 0, left: 0, right: 0, height: 2, borderRadius: 1 },

  // Chart pair — inline, no card background
  chartsPair: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 24,
    minHeight: 180,
  },
  chartHalf: { flex: 1, alignItems: 'center' },
  chartMicroLabel: { fontSize: 10, fontWeight: '600', letterSpacing: 1.2, textTransform: 'uppercase', marginBottom: 12 },
  vDivider: { width: 1, height: 120, marginHorizontal: 16 },
  emptyDonut: {
    width: 136, height: 136, borderRadius: 68,
    borderWidth: 12, borderColor: 'rgba(255,255,255,0.05)',
    alignItems: 'center', justifyContent: 'center',
  },

  // Category list — no card
  block: { paddingHorizontal: 20, paddingVertical: 20 },
  blockTitle: { fontSize: 10, fontWeight: '700', letterSpacing: 1.4, textTransform: 'uppercase', marginBottom: 18 },

  catRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 8 },
  catIconBox: { width: 20, alignItems: 'center', marginRight: 10 },
  catName: { flex: 1, fontSize: 13, fontWeight: '500' },
  catRight: { alignItems: 'flex-end', gap: 1 },
  catAmount: { fontSize: 13, fontWeight: '700' },
  catPct: { fontSize: 10, fontWeight: '700', letterSpacing: 0.5 },
  barTrack: { height: 2, borderRadius: 1, marginBottom: 0, overflow: 'hidden' },
  barFill: { height: 2, borderRadius: 1 },
  catDivider: { height: 1, marginTop: 12, marginBottom: 12 },

  // Trend
  trendHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 4 },
  trendTotal:  { fontSize: 12, fontWeight: '700', letterSpacing: 0.5 },
});
