import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import AmountInput from '../src/components/AmountInput';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Cancel01Icon, ShoppingCart01Icon } from '@hugeicons/core-free-icons';

export default function AddShoppingListScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  const [saving, setSaving] = useState(false);
  const [householdId, setHouseholdId] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [budget, setBudget] = useState('');

  useEffect(() => {
    const load = async () => {
      if (!user) return;
      const { data } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      setHouseholdId(data?.household_id || null);
    };
    load();
  }, [user]);

  const handleSave = async () => {
    if (!name.trim()) { Alert.alert('Error', 'Ingresa un nombre para la lista.'); return; }
    setSaving(true);
    try {
      const { error } = await supabase.from('shopping_lists').insert({
        household_id: householdId,
        created_by: user?.id,
        name: name.trim(),
        estimated_total: budget ? Number(budget) : null,
        status: 'open',
      });
      if (error) throw error;
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
        <Text style={styles.title}>Nueva Lista</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        {/* Presupuesto Estimado Gigante (Hero) */}
        <View style={styles.heroSection}>
          <Text style={{ fontSize: 40, fontWeight: '700', color: theme.primary, marginRight: 8, marginTop: 4 }}>$</Text>
          <AmountInput
            style={styles.heroInput}
            value={budget}
            onChangeText={setBudget}
            placeholder="0"
            placeholderTextColor="rgba(255,255,255,0.2)"
          />
        </View>
        <Text style={styles.heroLabel}>Presupuesto Estimado</Text>

        <View style={styles.formCard}>
          <Text style={styles.label}>Nombre de la lista</Text>
          <View style={styles.inputWrapper}>
             <TextInput 
                style={styles.input} 
                placeholder="Nombre de la lista" 
                placeholderTextColor="rgba(113, 113, 122, 0.7)" 
                value={name} 
                onChangeText={setName} 
                autoFocus 
             />
          </View>
        </View>
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: insets.bottom + 20 }]}>
        <TouchableOpacity style={styles.saveBtn} onPress={handleSave} disabled={saving}>
          {saving ? <ActivityIndicator color="#000" /> : <Text style={styles.saveBtnText}>Crear Lista</Text>}
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000000' },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 16 },
  closeBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)', alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 18, fontWeight: '700', color: '#FAFAFA' },
  content: { paddingBottom: 40 },
  
  heroSection: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 120, paddingHorizontal: 20, marginTop: 20 },
  heroInput: { fontSize: 64, fontWeight: '800', color: '#FAFAFA', textAlign: 'center', minWidth: 100 },
  heroLabel: { textAlign: 'center', color: '#A1A1AA', fontSize: 14, fontWeight: '500', marginBottom: 40 },
  
  formCard: { marginHorizontal: 20, backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 24, padding: 24 },
  label: { fontSize: 13, color: '#A1A1AA', marginBottom: 16, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5 },
  inputWrapper: { flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.1)', paddingBottom: 8 },
  input: { flex: 1, color: '#FAFAFA', fontSize: 18, fontWeight: '500' },
  
  footer: { paddingHorizontal: 20, paddingTop: 16, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' },
  saveBtn: { backgroundColor: '#FAFAFA', height: 56, borderRadius: 28, alignItems: 'center', justifyContent: 'center' },
  saveBtnText: { color: '#000', fontSize: 17, fontWeight: '700' },
});
