import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import AmountInput from '../src/components/AmountInput';
import DynamicIcon from '../src/components/DynamicIcon';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Cancel01Icon, Delete01Icon } from '@hugeicons/core-free-icons';

export default function EditBudgetScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();
  const insets = useSafeAreaInsets();
  
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [categories, setCategories] = useState<any[]>([]);
  const [categoryId, setCategoryId] = useState<string | null>(null);
  const [limitAmount, setLimitAmount] = useState('');

  useEffect(() => {
    const load = async () => {
      if (!user || !id) return;
      
      const { data: budget } = await supabase.from('budgets').select('*').eq('id', id).single();
      if (budget) {
        setCategoryId(budget.category_id);
        setLimitAmount(budget.amount.toString());
        
        const { data: cats } = await supabase.from('categories').select('*').eq('household_id', budget.household_id).eq('type', 'expense');
        setCategories(cats || []);
      }
      setLoading(false);
    };
    load();
  }, [user, id]);

  const handleSave = async () => {
    if (!categoryId) { Alert.alert('Error', 'Selecciona una categoría.'); return; }
    if (!limitAmount || isNaN(Number(limitAmount))) { Alert.alert('Error', 'Límite inválido.'); return; }
    setSaving(true);
    try {
      const { error } = await supabase.from('budgets').update({
        category_id: categoryId,
        amount: Number(limitAmount),
      }).eq('id', id);
      
      if (error) throw error;
      router.back();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = () => {
    Alert.alert('Eliminar Presupuesto', '¿Estás seguro de que deseas eliminar este presupuesto?', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
        const { error } = await supabase.from('budgets').delete().eq('id', id);
        if (error) Alert.alert('Error', error.message);
        else router.back();
      }}
    ]);
  };

  if (loading) return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.text} /></View>;

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 12) }]}>
      <View style={styles.header}>
        <TouchableOpacity style={[styles.closeBtn, { backgroundColor: theme.pillBg }]} onPress={() => router.back()}>
          <HugeiconsIcon icon={Cancel01Icon} size={24} color={theme.text} />
        </TouchableOpacity>
        <Text style={[styles.title, { color: theme.text }]}>Editar Presupuesto</Text>
        <TouchableOpacity style={[styles.deleteBtn, { backgroundColor: isDark ? 'rgba(239,68,68,0.1)' : 'rgba(239,68,68,0.05)' }]} onPress={handleDelete}>
          <HugeiconsIcon icon={Delete01Icon} size={22} color={theme.danger} />
        </TouchableOpacity>
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <View style={styles.heroSection}>
          <Text style={{ fontSize: 48, fontWeight: '700', color: theme.danger, marginRight: 8, marginTop: 4 }}>$</Text>
          <AmountInput
            style={[styles.heroInput, { color: theme.text }]}
            value={limitAmount}
            onChangeText={setLimitAmount}
            placeholder="0"
            placeholderTextColor={theme.textMuted}
          />
        </View>

        <View style={[styles.formCard, { backgroundColor: isDark ? 'rgba(255,255,255,0.05)' : theme.card }]}>
          <Text style={[styles.label, { color: theme.textMuted }]}>Categoría mensual</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingRight: 20 }}>
            {categories.map(cat => (
              <TouchableOpacity key={cat.id} style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }, categoryId === cat.id && { backgroundColor: theme.text, borderColor: theme.text }]} onPress={() => setCategoryId(cat.id)}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                    <DynamicIcon name={cat.icon} size={16} color={categoryId === cat.id ? theme.background : theme.text} />
                    <Text style={[styles.pillText, { color: theme.text }, categoryId === cat.id && { color: theme.background }]}>{cat.name}</Text>
                </View>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: insets.bottom + 20, borderTopColor: theme.border }]}>
        <TouchableOpacity style={[styles.saveBtn, { backgroundColor: theme.text }]} onPress={handleSave} disabled={saving}>
          {saving ? <ActivityIndicator color={theme.background} /> : <Text style={[styles.saveBtnText, { color: theme.background }]}>Guardar Cambios</Text>}
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingBottom: 16 },
  closeBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  deleteBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 18, fontWeight: '700' },
  content: { paddingBottom: 40 },
  heroSection: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 160, paddingHorizontal: 20, marginBottom: 20 },
  heroInput: { fontSize: 72, fontWeight: '800', textAlign: 'center', minWidth: 100 },
  formCard: { marginHorizontal: 20, borderRadius: 24, padding: 20 },
  label: { fontSize: 13, marginBottom: 16, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5 },
  pill: { paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1 },
  pillText: { fontWeight: '600', fontSize: 15 },
  footer: { paddingHorizontal: 20, paddingTop: 16, borderTopWidth: 1 },
  saveBtn: { height: 56, borderRadius: 28, alignItems: 'center', justifyContent: 'center' },
  saveBtnText: { fontSize: 17, fontWeight: '700' },
});
