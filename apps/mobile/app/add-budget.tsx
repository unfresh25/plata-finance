import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import AmountInput from '../src/components/AmountInput';
import DynamicIcon from '../src/components/DynamicIcon';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Cancel01Icon } from '@hugeicons/core-free-icons';

export default function AddBudgetScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  const [saving, setSaving] = useState(false);
  const [householdId, setHouseholdId] = useState<string | null>(null);
  const [categories, setCategories] = useState<any[]>([]);
  const [categoryId, setCategoryId] = useState<string | null>(null);
  const [limitAmount, setLimitAmount] = useState('');

  useEffect(() => {
    const load = async () => {
      if (!user) return;
      const { data: p } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (p?.household_id) {
        setHouseholdId(p.household_id);
        const { data: cats } = await supabase.from('categories').select('*').eq('household_id', p.household_id).eq('type', 'expense');
        setCategories(cats || []);
        if (cats && cats.length > 0) setCategoryId(cats[0].id);
      }
    };
    load();
  }, [user]);

  const handleSave = async () => {
    if (!categoryId) { Alert.alert('Error', 'Selecciona una categoría.'); return; }
    if (!limitAmount || isNaN(Number(limitAmount))) { Alert.alert('Error', 'Límite inválido.'); return; }
    setSaving(true);
    try {
      const now = new Date();
      const start = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
      
      const { data: existing } = await supabase
        .from('budgets')
        .select('id')
        .eq('household_id', householdId)
        .eq('category_id', categoryId)
        .eq('start_date', start)
        .maybeSingle();

      if (existing) {
        const { error } = await supabase
          .from('budgets')
          .update({ amount: Number(limitAmount) })
          .eq('id', existing.id);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('budgets')
          .insert({
            household_id: householdId,
            category_id: categoryId,
            amount: Number(limitAmount),
            period: 'monthly',
            start_date: start,
          });
        if (error) throw error;
      }
      router.back();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 12) }]}>
      <View style={styles.header}>
        <TouchableOpacity style={styles.closeBtn} onPress={() => router.back()}>
          <HugeiconsIcon icon={Cancel01Icon} size={24} color="#FAFAFA" />
        </TouchableOpacity>
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        {/* Límite Centrado gigante (Hero) */}
        <View style={styles.heroSection}>
          <Text style={{ fontSize: 48, fontWeight: '700', color: theme.danger, marginRight: 8, marginTop: 4 }}>$</Text>
          <AmountInput
            style={styles.heroInput}
            value={limitAmount}
            onChangeText={setLimitAmount}
            placeholder="0"
            placeholderTextColor="rgba(255,255,255,0.2)"
            autoFocus
          />
        </View>

        <View style={styles.formCard}>
          <Text style={styles.label}>Categoría mensual</Text>
          {categories.length === 0 ? (
            <Text style={styles.emptyNote}>Crea primero categorías de tipo "gasto".</Text>
          ) : (
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingRight: 20 }}>
              {categories.map(cat => (
                <TouchableOpacity key={cat.id} style={[styles.pill, categoryId === cat.id && styles.pillActive]} onPress={() => setCategoryId(cat.id)}>
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                    <DynamicIcon name={cat.icon} size={16} color={categoryId === cat.id ? '#000' : '#FAFAFA'} />
                    <Text style={[styles.pillText, categoryId === cat.id && styles.pillTextActive]}>{cat.name}</Text>
                  </View>
                </TouchableOpacity>
              ))}
            </ScrollView>
          )}
        </View>
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: insets.bottom + 20 }]}>
        <TouchableOpacity style={styles.saveBtn} onPress={handleSave} disabled={saving}>
          {saving ? <ActivityIndicator color="#000" /> : <Text style={styles.saveBtnText}>Guardar Presupuesto</Text>}
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000000' },
  header: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 16 },
  closeBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)', alignItems: 'center', justifyContent: 'center' },
  content: { paddingBottom: 40 },
  
  heroSection: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 160, paddingHorizontal: 20, marginBottom: 20 },
  heroInput: { fontSize: 72, fontWeight: '800', color: '#FAFAFA', textAlign: 'center', minWidth: 100 },
  
  formCard: { marginHorizontal: 20, backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 24, padding: 20 },
  label: { fontSize: 13, color: '#A1A1AA', marginBottom: 16, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5 },
  emptyNote: { color: '#71717A', fontStyle: 'italic' },
  
  pill: { paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.05)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)' },
  pillActive: { backgroundColor: '#FAFAFA', borderColor: '#FAFAFA' },
  pillText: { color: '#FAFAFA', fontWeight: '600', fontSize: 15 },
  pillTextActive: { color: '#000000' },
  
  footer: { paddingHorizontal: 20, paddingTop: 16, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' },
  saveBtn: { backgroundColor: '#FAFAFA', height: 56, borderRadius: 28, alignItems: 'center', justifyContent: 'center' },
  saveBtnText: { color: '#000', fontSize: 17, fontWeight: '700' },
});
