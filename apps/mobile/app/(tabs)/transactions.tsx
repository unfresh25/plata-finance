import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, RefreshControl, TouchableOpacity, TextInput } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { formatCurrency, formatShortDate } from '@jojos/core';
import TransactionItem from '../../src/components/TransactionItem';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Search01Icon } from '@hugeicons/core-free-icons';
import { useRouter, useFocusEffect } from 'expo-router';
import { useTheme } from '../../src/context/ThemeContext';

export default function TransactionsScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [members, setMembers] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [currency, setCurrency] = useState('USD');
  const { theme } = useTheme();

  const fetchTransactions = async () => {
    if (!user) return;
    try {
      const { data: pData } = await supabase.from('profiles').select('household_id, currency').eq('id', user.id).single();
      if (pData?.currency) setCurrency(pData.currency);
      if (pData?.household_id) {
        const [txsRes, catsRes, memsRes] = await Promise.all([
          supabase.from('transactions').select('*').eq('household_id', pData.household_id).order('date', { ascending: false }).limit(50),
          supabase.from('categories').select('*').eq('household_id', pData.household_id),
          supabase.from('profiles').select('id, name').eq('household_id', pData.household_id)
        ]);
        setTransactions(txsRes.data || []);
        setCategories(catsRes.data || []);
        setMembers(memsRes.data || []);
      }
    } catch (e) {
      console.warn(e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useFocusEffect(useCallback(() => { fetchTransactions(); }, [user]));

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    fetchTransactions();
  }, [user]);

  if (loading) {
    return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;
  }

  const filtered = transactions.filter(t => 
    search === '' || 
    t.description?.toLowerCase().includes(search.toLowerCase()) || 
    categories.find(c => c.id === t.category_id)?.name.toLowerCase().includes(search.toLowerCase())
  );

  const fmt = (n: number) => formatCurrency(n, currency);

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={[styles.header, { paddingTop: 16 }]}>
        <Text style={[styles.title, { color: theme.text }]}>Movimientos</Text>
        <View style={[styles.searchBox, { backgroundColor: theme.card, borderColor: theme.border }]}>
          <HugeiconsIcon icon={Search01Icon} size={18} color={theme.textMuted} />
          <TextInput 
            style={[styles.searchInput, { color: theme.text }]} 
            placeholder="Buscar por descripción o categoría..." 
            placeholderTextColor={theme.textMuted}
            value={search}
            onChangeText={setSearch}
          />
        </View>
      </View>

      <ScrollView 
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.primary} />}
      >
        <View>
          {filtered.length === 0 ? (
            <Text style={[styles.emptyText, { color: theme.textMuted }]}>No se encontraron transacciones</Text>
          ) : filtered.map((tx, index) => {
            const cat = categories.find(c => c.id === tx.category_id);
            const creator = members.find(m => m.id === tx.created_by);
            return (
              <TransactionItem
                key={tx.id}
                tx={tx}
                category={cat}
                creator={creator}
                currency={currency}
                isLast={index === filtered.length - 1}
                onPress={() => router.push({ pathname: '/transaction/[id]', params: { id: tx.id, txData: JSON.stringify(tx) } } as any)}
                onLongPress={() => router.push(`/edit-transaction?id=${tx.id}` as any)}
              />
            );
          })}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: { paddingHorizontal: 20, paddingBottom: 16 },
  title: { fontSize: 24, fontWeight: '700', marginBottom: 16 },
  searchBox: { flexDirection: 'row', alignItems: 'center', borderRadius: 12, paddingHorizontal: 16, height: 48, borderWidth: 1 },
  searchInput: { flex: 1, marginLeft: 12, fontSize: 15 },
  content: { padding: 20, paddingBottom: 100 },
  listCard: {},
  emptyText: { fontSize: 14, textAlign: 'center', marginVertical: 12 },
  listItem: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 12, borderBottomWidth: 1 },
  listLeft: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  iconBox: { width: 44, height: 44, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  iconEmoji: { fontSize: 20 },
  listName: { fontSize: 15, fontWeight: '500' },
  listSub: { fontSize: 13, marginTop: 2 },
  listAmount: { fontSize: 16, fontWeight: '600', fontVariant: ['tabular-nums'] },
});
