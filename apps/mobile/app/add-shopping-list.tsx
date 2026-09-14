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
import DynamicIcon from '../src/components/DynamicIcon';

export default function AddShoppingListScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  const [saving, setSaving] = useState(false);
  const [householdId, setHouseholdId] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [budget, setBudget] = useState('');
  const [store, setStore] = useState('');
  const [categoryId, setCategoryId] = useState<string | null>(null);
  const [categories, setCategories] = useState<any[]>([]);
  const [templates, setTemplates] = useState<any[]>([]);

  useEffect(() => {
    const load = async () => {
      if (!user) return;
      const { data } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (data?.household_id) {
        setHouseholdId(data.household_id);
        const [{ data: cats }, { data: tmpls }] = await Promise.all([
          supabase.from('categories').select('*').eq('household_id', data.household_id),
          supabase.from('shopping_templates').select('*').eq('household_id', data.household_id)
        ]);
        
        if (cats) setCategories(cats.filter(c => c.type === 'expense' || c.type === 'both'));
        if (tmpls) setTemplates(tmpls);
      }
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
        store: store.trim() || null,
        category_id: categoryId,
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

  const handleCreateFromTemplate = (template: any) => {
    Alert.alert('Usar Plantilla', `¿Crear nueva lista desde "${template.name}"?`, [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Crear', onPress: async () => {
          setSaving(true);
          try {
            const { data: newList, error: listError } = await supabase.from('shopping_lists').insert({
              household_id: householdId,
              created_by: user?.id,
              name: template.name,
              status: 'open',
            }).select().single();
            if (listError) throw listError;

            if (template.items && template.items.length > 0) {
              const itemsToInsert = template.items.map((i: any) => ({
                list_id: newList.id,
                name: i.name,
                quantity: i.quantity || 1,
                unit: i.unit,
                category_id: i.category_id,
                estimated_price: i.estimated_price,
                added_by: user?.id,
              }));
              const { error: itemsError } = await supabase.from('shopping_items').insert(itemsToInsert);
              if (itemsError) throw itemsError;
            }
            
            router.replace(`/shopping-list/${newList.id}` as any);
          } catch (e: any) {
            Alert.alert('Error', e.message);
            setSaving(false);
          }
      }}
    ]);
  };

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 12) }]}>
      <View style={styles.header}>
        <TouchableOpacity style={[styles.closeBtn, { backgroundColor: theme.pillBg }]} onPress={() => router.back()}>
          <HugeiconsIcon icon={Cancel01Icon} size={24} color={theme.text} />
        </TouchableOpacity>
        <Text style={[styles.title, { color: theme.text }]}>Nueva Lista</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        {templates.length > 0 && (
          <View style={{ marginTop: 20, marginBottom: 10 }}>
            <Text style={[styles.label, { color: theme.textMuted, marginHorizontal: 20, marginBottom: 12 }]}>Tus Plantillas</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, gap: 12 }}>
              {templates.map(tmpl => (
                <TouchableOpacity 
                  key={tmpl.id} 
                  style={[styles.templateCard, { backgroundColor: theme.card, borderColor: theme.border }]}
                  onPress={() => handleCreateFromTemplate(tmpl)}
                >
                  <HugeiconsIcon icon={ShoppingCart01Icon} size={24} color={theme.text} />
                  <Text style={[styles.templateName, { color: theme.text }]}>{tmpl.name}</Text>
                  <Text style={{ fontSize: 13, color: theme.textMuted }}>{tmpl.items?.length || 0} ítems</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>
        )}

        {/* Presupuesto Estimado Gigante (Hero) */}
        <View style={styles.heroSection}>
          <Text style={{ fontSize: 40, fontWeight: '700', color: theme.primary, marginRight: 8, marginTop: 4 }}>$</Text>
          <AmountInput
            style={[styles.heroInput, { color: theme.text }]}
            value={budget}
            onChangeText={setBudget}
            placeholder="0"
            placeholderTextColor={theme.textMuted}
          />
        </View>
        <Text style={[styles.heroLabel, { color: theme.textMuted }]}>Presupuesto Estimado</Text>

        <View style={[styles.formCard, { backgroundColor: theme.card }]}>
          <Text style={[styles.label, { color: theme.textMuted }]}>Nombre de la lista</Text>
          <View style={[styles.inputWrapper, { borderBottomColor: theme.border }]}>
             <TextInput 
                style={[styles.input, { color: theme.text }]} 
                placeholder="Nombre de la lista" 
                placeholderTextColor={theme.textMuted} 
                value={name} 
                onChangeText={setName} 
                autoFocus 
             />
          </View>

          <Text style={[styles.label, { color: theme.textMuted, marginTop: 24 }]}>Tienda / Lugar (Opcional)</Text>
          <View style={[styles.inputWrapper, { borderBottomColor: theme.border }]}>
             <TextInput 
                style={[styles.input, { color: theme.text }]} 
                placeholder="Ej. Walmart, Éxito..." 
                placeholderTextColor={theme.textMuted} 
                value={store} 
                onChangeText={setStore} 
             />
          </View>

          <Text style={[styles.label, { color: theme.textMuted, marginTop: 24 }]}>Categoría de la lista</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingVertical: 8 }}>
            {categories.map(cat => {
              const isSelected = categoryId === cat.id;
              return (
                <TouchableOpacity
                  key={cat.id}
                  style={[styles.categoryPill, { borderColor: isSelected ? cat.color : theme.border, backgroundColor: isSelected ? `${cat.color}15` : theme.pillBg }]}
                  onPress={() => setCategoryId(cat.id)}
                >
                  <DynamicIcon name={cat.icon} size={16} color={isSelected ? cat.color : theme.text} />
                  <Text style={[styles.categoryPillText, { color: isSelected ? cat.color : theme.text }]}>{cat.name}</Text>
                </TouchableOpacity>
              )
            })}
            {categories.length === 0 && <Text style={{ color: theme.textMuted }}>Cargando categorías...</Text>}
          </ScrollView>
        </View>
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: insets.bottom + 20, borderTopColor: theme.border }]}>
        <TouchableOpacity style={[styles.saveBtn, { backgroundColor: theme.text }]} onPress={handleSave} disabled={saving}>
          {saving ? <ActivityIndicator color={theme.background} /> : <Text style={[styles.saveBtnText, { color: theme.background }]}>Crear Lista</Text>}
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 16 },
  closeBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 18, fontWeight: '700' },
  content: { paddingBottom: 40 },
  
  heroSection: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 120, paddingHorizontal: 20, marginTop: 20 },
  heroInput: { fontSize: 64, fontWeight: '800', textAlign: 'center', minWidth: 100 },
  heroLabel: { textAlign: 'center', fontSize: 14, fontWeight: '500', marginBottom: 40 },
  
  formCard: { marginHorizontal: 20, borderRadius: 24, padding: 24 },
  label: { fontSize: 13, marginBottom: 16, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5 },
  inputWrapper: { flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, paddingBottom: 8 },
  input: { flex: 1, fontSize: 18, fontWeight: '500' },
  
  footer: { paddingHorizontal: 20, paddingTop: 16, borderTopWidth: 1 },
  saveBtn: { height: 56, borderRadius: 28, alignItems: 'center', justifyContent: 'center' },
  saveBtnText: { fontSize: 17, fontWeight: '700' },
  categoryPill: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, borderWidth: 1 },
  categoryPillText: { fontSize: 14, fontWeight: '600' },
  templateCard: { width: 140, padding: 16, borderRadius: 20, borderWidth: 1, gap: 8 },
  templateName: { fontSize: 16, fontWeight: '600', marginTop: 4 },
});
