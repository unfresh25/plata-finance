import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, RefreshControl, TouchableOpacity } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useFocusEffect, useRouter } from 'expo-router';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Calendar01Icon, AnalyticsUpIcon, AnalyticsDownIcon, ArrowLeft01Icon, ArrowRight01Icon } from '@hugeicons/core-free-icons';

import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { formatCurrency, monthRange } from '@jojos/core';
import { FintechDonut, TrendLine, HeatmapTracker, BudgetProgress, BudgetArch, getColor } from '../../src/components/Charts';
import { useTheme } from '../../src/context/ThemeContext';

const MONTHS_SHORT = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
const MONTHS_LONG = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

export default function ReportsScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [currency, setCurrency] = useState('USD');

  const [currentDate, setCurrentDate] = useState(new Date());

  const [currentTxs, setCurrentTxs] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [budgets, setBudgets] = useState<any[]>([]);
  const [monthlyHistory, setMonthlyHistory] = useState<any[]>([]);
  const [heatmapData, setHeatmapData] = useState<{ date: string; count: number }[]>([]);

  // UI state
  const [activeTab, setActiveTab] = useState<'expense' | 'income'>('expense');

  const fetchReports = async () => {
    if (!user) return;
    try {
      const { data: pData } = await supabase.from('profiles').select('household_id, currency').eq('id', user.id).single();
      if (pData?.currency) setCurrency(pData.currency);
      if (!pData?.household_id) return;

      const { start, end } = monthRange(currentDate);

      // Current month transactions (with category)
      const { data: txs } = await supabase
        .from('transactions')
        .select('amount, type, category_id')
        .eq('household_id', pData.household_id)
        .gte('date', start)
        .lte('date', end);
      setCurrentTxs(txs || []);

      // Categories
      const { data: cats } = await supabase.from('categories').select('*').eq('household_id', pData.household_id);
      setCategories(cats || []);

      // Budgets for current month
      const monthStart = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1).toISOString().split('T')[0];
      const { data: buds } = await supabase
        .from('budgets')
        .select('*, categories(name, icon)')
        .eq('household_id', pData.household_id)
        .eq('period', 'monthly')
        .gte('start_date', monthStart);
      setBudgets(buds || []);

      // Last 6 months aggregated (for TrendLine) up to currentDate
      const history: any[] = [];
      for (let i = 5; i >= 0; i--) {
        const d = new Date(currentDate.getFullYear(), currentDate.getMonth() - i, 1);
        const { start: s, end: e } = monthRange(d);
        const { data: hist } = await supabase
          .from('transactions')
          .select('amount, type')
          .eq('household_id', pData.household_id)
          .gte('date', s)
          .lte('date', e);
        
        const inc = (hist || []).filter(t => t.type === 'income').reduce((sum, t) => sum + t.amount, 0);
        const exp = (hist || []).filter(t => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0);
        history.push({ label: MONTHS_SHORT[d.getMonth()], income: inc, expense: exp });
      }
      setMonthlyHistory(history);

      // Heatmap Data (last 90 days from currentDate)
      const ninetyDaysAgo = new Date(currentDate.getTime() - 90 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      const { data: hmTxs } = await supabase
        .from('transactions')
        .select('date')
        .eq('household_id', pData.household_id)
        .gte('date', ninetyDaysAgo);

      const heatMapAgg: Record<string, number> = {};
      (hmTxs || []).forEach(t => {
         const d = t.date.split('T')[0];
         heatMapAgg[d] = (heatMapAgg[d] || 0) + 1;
      });
      setHeatmapData(Object.keys(heatMapAgg).map(k => ({ date: k, count: heatMapAgg[k] })));

    } catch (e) {
      console.warn(e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useFocusEffect(useCallback(() => { fetchReports(); }, [user, currentDate]));
  const onRefresh = useCallback(() => { setRefreshing(true); fetchReports(); }, [user, currentDate]);

  const changeMonth = (delta: number) => {
    const newDate = new Date(currentDate.getFullYear(), currentDate.getMonth() + delta, 1);
    setCurrentDate(newDate);
  };

  if (loading && currentTxs.length === 0) return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;

  const fmt = (n: number) => formatCurrency(n, currency);

  const tIncome = currentTxs.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
  const tExpenses = currentTxs.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
  const balance = tIncome - tExpenses;

  // ─ Donut Chart Engine ─
  const byCategory: Record<string, number> = {};
  currentTxs.filter(t => t.type === activeTab).forEach(t => {
    if (t.category_id) byCategory[t.category_id] = (byCategory[t.category_id] || 0) + t.amount;
  });
  
  const donutData = Object.entries(byCategory).map(([catId, value], i) => {
    const cat = categories.find(c => c.id === catId);
    return { label: cat ? cat.name : 'Otro', icon: cat?.icon, value, displayValue: fmt(value), color: getColor(i) };
  }).sort((a, b) => b.value - a.value);

  // ─ Trend Line Engine ─
  const trendData = monthlyHistory.map(h => ({
    label: h.label,
    value: activeTab === 'income' ? h.income : h.expense
  }));

  // ─ Budget spend ─
  const budgetRows = budgets.map(b => {
    const catId = b.category_id;
    const spent = Math.abs(currentTxs.filter(t => t.category_id === catId && t.type === 'expense').reduce((s, t) => s + t.amount, 0));
    return { ...b, spent };
  });

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={[styles.header, { paddingTop: Math.max(insets.top, 16) }]}>
        <View>
            <Text style={[styles.title, { color: theme.text }]}>Estadísticas</Text>
            <Text style={{ color: theme.textMuted, fontSize: 13, marginTop: 4 }}>Resumen financiero</Text>
        </View>
        <View style={styles.monthNav}>
            <TouchableOpacity onPress={() => changeMonth(-1)} hitSlop={{top:10,bottom:10,left:10,right:10}}>
                <HugeiconsIcon icon={ArrowLeft01Icon} size={20} color={theme.textMuted} />
            </TouchableOpacity>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginHorizontal: 12 }}>
                <HugeiconsIcon icon={Calendar01Icon} size={14} color={theme.primary} />
                <Text style={{ color: theme.text, fontWeight: '600', fontSize: 13 }}>
                    {MONTHS_LONG[currentDate.getMonth()]} {currentDate.getFullYear()}
                </Text>
            </View>
            <TouchableOpacity onPress={() => changeMonth(1)} hitSlop={{top:10,bottom:10,left:10,right:10}}>
                <HugeiconsIcon icon={ArrowRight01Icon} size={20} color={theme.textMuted} />
            </TouchableOpacity>
        </View>
      </View>

      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.primary} />}
        showsVerticalScrollIndicator={false}
      >
        {/* KPI Balance Section */}
        <View style={styles.balanceCard}>
            <Text style={{ color: theme.textMuted, fontSize: 14, fontWeight: '500', marginBottom: 8 }}>Balance Neto</Text>
            <Text style={{ color: theme.text, fontSize: 36, fontWeight: '800', letterSpacing: -1 }}>{fmt(balance)}</Text>
            
            <View style={{ flexDirection: 'row', gap: 16, marginTop: 24 }}>
                <View style={{ flex: 1 }}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                        <HugeiconsIcon icon={AnalyticsUpIcon} size={14} color={theme.success} />
                        <Text style={{ color: theme.textMuted, fontSize: 12 }}>Ingresos</Text>
                    </View>
                    <Text style={{ color: theme.text, fontSize: 16, fontWeight: '600' }}>{fmt(tIncome)}</Text>
                </View>
                <View style={{ flex: 1 }}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                        <HugeiconsIcon icon={AnalyticsDownIcon} size={14} color={theme.danger} />
                        <Text style={{ color: theme.textMuted, fontSize: 12 }}>Gastos</Text>
                    </View>
                    <Text style={{ color: theme.text, fontSize: 16, fontWeight: '600' }}>{fmt(Math.abs(tExpenses))}</Text>
                </View>
            </View>
        </View>

        {/* Global Tab Switcher */}
        <View style={styles.tabContainer}>
            <TouchableOpacity 
                style={[styles.tabBtn, activeTab === 'expense' && { backgroundColor: 'rgba(255,255,255,0.08)' }]}
                onPress={() => setActiveTab('expense')}
            >
                <Text style={[styles.tabText, activeTab === 'expense' && { color: theme.text }]}>Gastos</Text>
            </TouchableOpacity>
            <TouchableOpacity 
                style={[styles.tabBtn, activeTab === 'income' && { backgroundColor: 'rgba(255,255,255,0.08)' }]}
                onPress={() => setActiveTab('income')}
            >
                <Text style={[styles.tabText, activeTab === 'income' && { color: theme.text }]}>Ingresos</Text>
            </TouchableOpacity>
        </View>

        {/* Categories Donut Chart */}
        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { color: theme.text }]}>Por Categorías</Text>
          <View style={styles.card}>
            {donutData.length === 0 ? (
                <Text style={{ color: theme.textMuted, textAlign: 'center', marginVertical: 20 }}>No hay movimientos registrados</Text>
            ) : (
                <FintechDonut 
                    data={donutData} 
                    totalLabel={activeTab === 'expense' ? 'Total Gastos' : 'Total Ingresos'} 
                    totalValue={fmt(activeTab === 'expense' ? tExpenses : tIncome)} 
                />
            )}
          </View>
        </View>

        {/* Trend Area Chart */}
        <View style={styles.section}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <Text style={[styles.sectionTitle, { color: theme.text, marginBottom: 0 }]}>Tendencia Histórica</Text>
              <Text style={{ color: activeTab === 'income' ? theme.success : theme.danger, fontWeight: '600', fontSize: 13 }}>
                  {activeTab === 'income' ? 'Ingresos' : 'Gastos'}
              </Text>
          </View>
          <View style={[styles.card, { overflow: 'hidden', paddingBottom: 0 }]}>
             <TrendLine data={trendData} color={activeTab === 'income' ? '#22C55E' : '#EF4444'} />
          </View>
        </View>
        
        {/* Heatmap Section */}
        <View style={styles.section}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <Text style={[styles.sectionTitle, { color: theme.text, marginBottom: 0 }]}>Mapa de Actividad</Text>
            <Text style={{ color: theme.textMuted, fontSize: 13 }}>Últimos 90 días</Text>
          </View>
          <View style={[styles.card, { paddingVertical: 12 }]}>
             <HeatmapTracker data={heatmapData} />
             <View style={{ flexDirection: 'row', justifyContent: 'center', gap: 6, marginTop: 16, alignItems: 'center' }}>
                 <Text style={{ color: theme.textMuted, fontSize: 11 }}>Menos</Text>
                 <View style={{ flexDirection: 'row', gap: 4 }}>
                     {[0.05, 0.4, 0.7, 1].map((op, i) => (
                         <View key={i} style={{ width: 10, height: 10, borderRadius: 2, backgroundColor: `rgba(34, 197, 94, ${op})` }} />
                     ))}
                 </View>
                 <Text style={{ color: theme.textMuted, fontSize: 11 }}>Más</Text>
             </View>
          </View>
        </View>

        {/* Monthly Budget */}
        {activeTab === 'expense' && (
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: theme.text }]}>Presupuesto Mensual</Text>
            {budgetRows.length === 0
              ? <Text style={{ color: '#71717A', fontSize: 14, textAlign: 'center', marginVertical: 20 }}>No has configurado ningún límite.</Text>
              : (
                <View>
                  <BudgetArch 
                    spent={budgetRows.reduce((s, b) => s + b.spent, 0)} 
                    limit={budgetRows.reduce((s, b) => s + b.amount, 0)}
                    currency={currency === 'USD' ? '$' : currency}
                  />
                  <View style={{ marginTop: 24 }}>
                    {budgetRows.map((b, i) => (
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
              )
            }
          </View>
        )}

      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000000' },
  center: { flex: 1, backgroundColor: '#000000', alignItems: 'center', justifyContent: 'center' },
  header: { paddingHorizontal: 20, paddingBottom: 16, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  title: { fontSize: 26, fontWeight: '800', color: '#FAFAFA' },
  monthNav: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 24, paddingVertical: 8, paddingHorizontal: 12 },
  content: { padding: 20, paddingBottom: 100 },

  balanceCard: { marginBottom: 32 },
  
  tabContainer: { flexDirection: 'row', backgroundColor: 'rgba(255,255,255,0.03)', borderRadius: 12, padding: 4, marginBottom: 32 },
  tabBtn: { flex: 1, paddingVertical: 10, alignItems: 'center', borderRadius: 8 },
  tabText: { color: '#71717A', fontSize: 14, fontWeight: '600' },

  section: { marginBottom: 32 },
  sectionTitle: { fontSize: 18, fontWeight: '700', color: '#FAFAFA', marginBottom: 16 },
  card: { },
});
