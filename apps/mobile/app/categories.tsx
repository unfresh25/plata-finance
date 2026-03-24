import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, RefreshControl } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter, useFocusEffect, Stack } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import DynamicIcon from '../src/components/DynamicIcon';

export default function CategoriesScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [categories, setCategories] = useState<any[]>([]);

  const fetchCategories = async () => {
    if (!user) return;
    try {
      const { data: pData } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (pData?.household_id) {
        const { data } = await supabase.from('categories').select('*').eq('household_id', pData.household_id).order('name');
        setCategories(data || []);
      }
    } catch (e) {
      console.warn(e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useFocusEffect(useCallback(() => { fetchCategories(); }, [user]));
  
  const onRefresh = useCallback(() => { 
    setRefreshing(true); 
    fetchCategories(); 
  }, [user]);

  if (loading) return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;

  const incomes = categories.filter(c => c.type === 'income');
  const expenses = categories.filter(c => c.type === 'expense');

  const renderList = (data: any[], title: string) => (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: theme.textMuted }]}>{title}</Text>
      <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
        {data.length === 0 ? (
          <Text style={[styles.emptyText, { color: theme.textMuted }]}>No hay categorías aquí.</Text>
        ) : data.map((cat, i) => (
          <TouchableOpacity 
            key={cat.id} 
            style={[styles.item, { borderBottomColor: theme.border }, i === data.length - 1 && { borderBottomWidth: 0 }]}
            onPress={() => router.push(`/category/${cat.id}` as any)}
          >
            <View style={styles.itemLeft}>
              <View style={[styles.iconBox, { backgroundColor: cat.color ? cat.color + '20' : theme.pillBg }]}>
                <DynamicIcon name={cat.icon} size={20} color={cat.color || theme.text} />
              </View>
              <Text style={[styles.itemName, { color: theme.text }]}>{cat.name}</Text>
            </View>
            <Text style={[styles.chevron, { color: theme.textMuted }]}>›</Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 8) }]}>
        <View style={[styles.header, { borderBottomColor: theme.border }]}>
          <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.card, borderWidth: 1, borderColor: theme.border }]} onPress={() => router.back()}>
            <Text style={{ color: theme.text, fontSize: 18, fontWeight: '600' }}>✕</Text>
          </TouchableOpacity>
          <Text style={[styles.title, { color: theme.text }]}>Categorías</Text>
          <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.primary }]} onPress={() => router.push('/category/new' as any)}>
            <Text style={{ color: '#FFF', fontSize: 24, fontWeight: '400', lineHeight: 26 }}>+</Text>
          </TouchableOpacity>
        </View>

        <ScrollView contentContainerStyle={styles.content} refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.primary} />}>
          {renderList(expenses, 'GASTOS')}
          {renderList(incomes, 'INGRESOS')}
        </ScrollView>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 16, borderBottomWidth: 1 },
  title: { fontSize: 20, fontWeight: '700' },
  iconBtn: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
  content: { padding: 20, paddingBottom: 100 },
  section: { marginBottom: 32 },
  sectionTitle: { fontSize: 13, fontWeight: '600', marginBottom: 12, marginLeft: 4, letterSpacing: 0.5 },
  card: { borderRadius: 16, borderWidth: 1, overflow: 'hidden' },
  item: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: 16, borderBottomWidth: 1 },
  itemLeft: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  iconBox: { width: 44, height: 44, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  itemName: { fontSize: 16, fontWeight: '500' },
  chevron: { fontSize: 22 },
  emptyText: { padding: 20, textAlign: 'center', fontSize: 14 }
});
