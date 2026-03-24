import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, RefreshControl, TouchableOpacity, ImageBackground, Dimensions, Alert } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter, useFocusEffect } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { formatCurrency, formatShortDate } from '@jojos/core';
import { useTheme } from '../../src/context/ThemeContext';
import { BudgetArch } from '../../src/components/Charts';
import DynamicIcon from '../../src/components/DynamicIcon';

export default function FinancesScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [accounts, setAccounts] = useState<any[]>([]);
  const [debts, setDebts] = useState<any[]>([]);
  const [savings, setSavings] = useState<any[]>([]);
  const [shoppingLists, setShoppingLists] = useState<any[]>([]);
  const [budgets, setBudgets] = useState<any[]>([]);
  const [currency, setCurrency] = useState('USD');
  const { theme } = useTheme();

  const fetchFinances = async () => {
    if (!user) return;
    try {
      const { data: pData } = await supabase.from('profiles').select('household_id, currency').eq('id', user.id).single();
      if (pData?.currency) setCurrency(pData.currency);
      if (pData?.household_id) {
        const [accRes, debtRes, savRes, shopRes, budRes, txRes] = await Promise.all([
          supabase.from('accounts').select('*').eq('household_id', pData.household_id),
          supabase.from('debts').select('*').eq('household_id', pData.household_id).eq('status', 'active'),
          supabase.from('savings_goals').select('*').eq('household_id', pData.household_id).eq('status', 'active'),
          supabase.from('shopping_lists').select('*, shopping_items(count)').eq('household_id', pData.household_id).eq('status', 'open'),
          supabase.from('budgets').select('*, categories(name, icon)').eq('household_id', pData.household_id),
          supabase.from('transactions').select('amount, category_id, type').eq('household_id', pData.household_id).gte('date', new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0])
        ]);
        setAccounts(accRes.data || []);
        setDebts(debtRes.data || []);
        setSavings(savRes.data || []);
        setShoppingLists(shopRes.data || []);
        
        // Process budgets with current spending
        const txs = txRes.data || [];
        const processedBudgets = budRes.data?.map((b: any) => {
          const spent = txs.filter((t: any) => t.type === 'expense' && t.category_id === b.category_id).reduce((s: number, t: any) => s + t.amount, 0);
          return { ...b, spent };
        }) || [];
        setBudgets(processedBudgets);
      }
    } catch (e) {
      console.warn(e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useFocusEffect(useCallback(() => { fetchFinances(); }, [user]));
  const onRefresh = useCallback(() => { setRefreshing(true); fetchFinances(); }, [user]);

  if (loading) return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;

  const fmt = (n: number) => formatCurrency(n, currency);
  const CARD_WIDTH = Dimensions.get('window').width * 0.85;





  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={[styles.header, { paddingTop: 16 }]}>
        <Text style={[styles.title, { color: theme.text }]}>Finanzas</Text>
      </View>

      <ScrollView
        contentContainerStyle={{ paddingVertical: 20, paddingBottom: 100 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#2563EB" />}
      >
        {/* Accounts Carousel */}
        <Text style={[styles.sectionTitle, { paddingHorizontal: 20, color: theme.text, paddingBottom: 16 }]}>Tus Cuentas</Text>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 12, gap: 16 }}
          snapToInterval={CARD_WIDTH + 16}
          decelerationRate="fast"
        >
          {accounts.length === 0
            ? <View style={[styles.listCard, { width: CARD_WIDTH, backgroundColor: theme.card, borderColor: theme.border }]}><Text style={[styles.emptyText, { color: theme.textMuted }]}>Sin cuentas. Usa el botón "+" para crear una.</Text></View>
            : accounts.map(item => (
              <TouchableOpacity
                key={item.id}
                style={[styles.creditCard, { width: CARD_WIDTH }]}
                onPress={() => router.push(`/account/${item.id}` as any)}
                onLongPress={() => router.push(`/edit-account?id=${item.id}` as any)}
                delayLongPress={400}
              >
                <ImageBackground
                  source={require('../../assets/images/card-bg.png')}
                  style={styles.cardBg}
                  imageStyle={{ borderRadius: 24 }}
                  resizeMode="cover"
                >
                  <View style={styles.cardOverlay}>
                    <View style={styles.cardTop}>
                      <Text style={styles.cardName}>{item.name}</Text>
                      <View style={styles.chip}><View style={styles.chipLine} /></View>
                    </View>
                    <View style={styles.cardBottom}>
                      <View>
                        <Text style={styles.cardSub}>{item.type}</Text>
                        <Text style={styles.cardBalance}>{fmt(item.balance)}</Text>
                      </View>
                      <View style={styles.mcLogo}>
                        <View style={[styles.mcCircle, { backgroundColor: '#EF4444', marginRight: -12 }]} />
                        <View style={[styles.mcCircle, { backgroundColor: '#F59E0B' }]} />
                      </View>
                    </View>
                  </View>
                </ImageBackground>
              </TouchableOpacity>
            ))
          }
        </ScrollView>

        {/* Debts */}
        <View style={{ marginTop: 20 }}>
          <View style={[styles.sectionHeaderRow, { marginHorizontal: 20 }]}><Text style={[styles.sectionTitle, { color: theme.text }]}>Deudas</Text></View>
          <View>
            {debts.length === 0
              ? <Text style={[styles.emptyText, { color: theme.textMuted }]}>Sin deudas registradas</Text>
              : debts.map((item, i) => {
                const progressNum = item.amount > 0 ? (item.amount_paid || 0) / item.amount : 0;
                const progressPct = Math.min(progressNum * 100, 100);
                return (
                  <TouchableOpacity
                    key={item.id}
                    style={[styles.listItem, { paddingHorizontal: 20, borderBottomColor: theme.border }, i === debts.length - 1 && { borderBottomWidth: 0 }]}
                    onPress={() => router.push(`/debt/${item.id}` as any)}
                    onLongPress={() => router.push(`/edit-debt?id=${item.id}` as any)}
                    delayLongPress={400}
                  >
                    <View style={{ flex: 1 }}>
                      <Text style={[styles.listName, { color: theme.text }]}>{item.description || 'Deuda'}</Text>
                      <Text style={[styles.listSub, { color: theme.textMuted }]}>{item.direction === 'owed_to_us' ? 'Nos deben' : 'Debemos'}{item.person_name ? ` • ${item.person_name}` : ''}</Text>

                      <View style={{ marginTop: 8, flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                        <View style={[styles.progressBar, { flex: 1, backgroundColor: theme.border }]}>
                          <View style={[styles.progressFill, { width: `${progressPct}%`, backgroundColor: item.direction === 'owed_to_us' ? theme.success : theme.danger }]} />
                        </View>
                        <Text style={{ color: theme.textMuted, fontSize: 11 }}>{progressPct.toFixed(0)}%</Text>
                      </View>
                    </View>
                    <View style={{ alignItems: 'flex-end', paddingLeft: 12 }}>
                      <Text style={[styles.listAmount, item.direction === 'owed_to_us' ? { color: theme.success } : { color: theme.danger }]}>
                        {item.direction === 'owed_to_us' ? '+' : '-'}{fmt(item.amount - (item.amount_paid || 0))}
                      </Text>
                      <Text style={[styles.tapHint, { color: theme.textMuted }]}>Restante</Text>
                    </View>
                  </TouchableOpacity>
                );
              })
            }
          </View>
        </View>

        {/* Savings Goals */}
        <View style={{ marginTop: 24 }}>
          <View style={[styles.sectionHeaderRow, { marginHorizontal: 20 }]}><Text style={[styles.sectionTitle, { color: theme.text }]}>Metas de Ahorro</Text></View>
          <View>
            {savings.length === 0
              ? <Text style={[styles.emptyText, { color: theme.textMuted }]}>Sin metas establecidas</Text>
              : savings.map((item, i) => {
                const progressNum = item.target_amount > 0 ? (item.current_amount || 0) / item.target_amount : 0;
                const progressPct = Math.min(progressNum * 100, 100);
                return (
                  <TouchableOpacity
                    key={item.id}
                    style={[styles.listItem, { paddingHorizontal: 20, borderBottomColor: theme.border }, i === savings.length - 1 && { borderBottomWidth: 0 }]}
                    onPress={() => router.push(`/goal/${item.id}` as any)}
                    onLongPress={() => router.push(`/edit-savings-goal?id=${item.id}` as any)}
                    delayLongPress={400}
                  >
                    <View style={{ flex: 1 }}>
                      <Text style={[styles.listName, { color: theme.text }]}>{item.name}</Text>
                      <Text style={[styles.listSub, { color: theme.textMuted }]}>
                        {item.deadline ? `Objetivo: ${formatShortDate(item.deadline)}` : 'Ahorro Libre'}
                      </Text>

                      <View style={{ marginTop: 8, flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                        <View style={[styles.progressBar, { flex: 1, backgroundColor: theme.border }]}>
                          <View style={[styles.progressFill, { width: `${progressPct}%`, backgroundColor: item.color || theme.primary }]} />
                        </View>
                        <Text style={{ color: theme.textMuted, fontSize: 11 }}>{progressPct.toFixed(0)}%</Text>
                      </View>
                    </View>
                    <View style={{ alignItems: 'flex-end', paddingLeft: 12 }}>
                      <Text style={[styles.listAmount, { color: item.color || theme.text }]}>
                        {fmt(item.current_amount)}
                      </Text>
                      <Text style={[styles.tapHint, { color: theme.textMuted }]}>de {fmt(item.target_amount)}</Text>
                    </View>
                  </TouchableOpacity>
                );
              })
            }
          </View>
        </View>

        {/* Shopping Lists */}
        <View style={{ marginTop: 24 }}>
          <View style={[styles.sectionHeaderRow, { marginHorizontal: 20 }]}><Text style={[styles.sectionTitle, { color: theme.text }]}>Listas de Compras</Text></View>
          <View>
            {shoppingLists.length === 0
              ? <Text style={[styles.emptyText, { color: theme.textMuted }]}>Sin listas de compras</Text>
              : shoppingLists.map((item, i) => (
                <TouchableOpacity 
                  key={item.id} 
                  style={[styles.listItem, { paddingHorizontal: 20 }]} 
                  onPress={() => router.push(`/shopping-list/${item.id}` as any)}
                >
                  <View>
                    <Text style={[styles.listName, { color: theme.text }]}>{item.name}</Text>
                    <Text style={[styles.listSub, { color: theme.textMuted }]}>{item.shopping_items?.[0]?.count ?? 0} ítems</Text>
                  </View>
                  <Text style={[styles.chevron, { color: theme.textMuted }]}>›</Text>
                </TouchableOpacity>
              ))
            }
          </View>
        </View>

        {/* Budgets Section (New) */}
        {budgets.length > 0 && (
          <View style={{ marginTop: 40, paddingHorizontal: 20 }}>
            <Text style={[styles.sectionTitle, { color: theme.text, marginBottom: 24, fontSize: 18, fontWeight: '700' }]}>Presupuesto Mensual</Text>
            
            <BudgetArch 
              spent={budgets.reduce((s, b) => s + b.spent, 0)} 
              limit={budgets.reduce((s, b) => s + b.amount, 0)}
              currency={currency === 'USD' ? '$' : currency}
            />

            <View style={{ marginTop: 24 }}>
                {budgets.map((b) => (
                <TouchableOpacity 
                    key={b.id} 
                    style={{ marginBottom: 20 }}
                    onLongPress={() => router.push(`/edit-budget?id=${b.id}` as any)}
                    delayLongPress={400}
                >
                    <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8, alignItems: 'center' }}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 }}>
                        <DynamicIcon name={b.categories?.icon} size={18} color={theme.text} />
                        <Text style={{ color: theme.text, fontWeight: '600' }} numberOfLines={1}>{b.categories?.name}</Text>
                    </View>
                    <Text style={{ color: theme.textMuted, fontSize: 13, marginLeft: 10 }}>{fmt(b.spent)} / {fmt(b.amount)}</Text>
                    </View>
                    <View style={{ height: 6, backgroundColor: theme.border, borderRadius: 3, overflow: 'hidden' }}>
                        <View style={{ height: '100%', width: `${Math.min((b.spent/b.amount)*100, 100)}%`, backgroundColor: (b.spent/b.amount) > 0.9 ? theme.danger : theme.primary, borderRadius: 3 }} />
                    </View>
                </TouchableOpacity>
                ))}
            </View>
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
  title: { fontSize: 24, fontWeight: '700', color: '#FAFAFA' },
  addBtn: { backgroundColor: 'rgba(99,158,255,0.2)', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 12 },
  addBtnText: { color: '#FAFAFA', fontSize: 13, fontWeight: '600' },
  sectionHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  sectionTitle: { fontSize: 16, fontWeight: '600', color: '#FAFAFA' },
  sectionAddBtn: { paddingHorizontal: 10, paddingVertical: 5, borderRadius: 10 },
  sectionAddBtnText: { fontSize: 13, fontWeight: '600' },
  listCard: { padding: 0 },
  emptyText: { fontSize: 14, color: '#A1A1AA', textAlign: 'center', marginVertical: 12 },
  listItem: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 16 },
  listName: { fontSize: 16, fontWeight: '500', color: '#FAFAFA' },
  listSub: { fontSize: 13, color: '#A1A1AA', marginTop: 4, textTransform: 'capitalize' },
  listAmount: { fontSize: 16, fontWeight: '600', color: '#FAFAFA', fontVariant: ['tabular-nums'] },
  tapHint: { fontSize: 11, color: '#3F3F46', marginTop: 2 },
  progressBar: { height: 6, backgroundColor: 'rgba(99,158,255,0.2)', borderRadius: 3, overflow: 'hidden' },
  progressFill: { height: '100%', backgroundColor: '#2563EB', borderRadius: 3 },
  chevron: { fontSize: 22, color: '#71717A' },

  creditCard: { height: 200, borderRadius: 24, shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.4, shadowRadius: 12, elevation: 10 },
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
});
