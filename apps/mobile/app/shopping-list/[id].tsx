import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, RefreshControl, TouchableOpacity, TextInput, Alert, Modal } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { useTheme } from '../../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ArrowLeft01Icon, Settings01Icon, ShoppingCart01Icon, Delete01Icon, CheckmarkCircle02Icon, CircleIcon } from '@hugeicons/core-free-icons';
import AmountInput from '../../src/components/AmountInput';
import { formatCurrency } from '@jojos/core';

export default function ShoppingListDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [list, setList] = useState<any>(null);
  const [items, setItems] = useState<any[]>([]);
  const [newItemName, setNewItemName] = useState('');
  const [addingItem, setAddingItem] = useState(false);
  
  const [showSettings, setShowSettings] = useState(false);
  const [editName, setEditName] = useState('');
  const [editBudget, setEditBudget] = useState('');
  const [savingSettings, setSavingSettings] = useState(false);
  const [currency, setCurrency] = useState('USD');
  const [categories, setCategories] = useState<any[]>([]);
  
  // Item Edit State
  const [editingItem, setEditingItem] = useState<any>(null);
  const [editItemName, setEditItemName] = useState('');
  const [editItemQuantity, setEditItemQuantity] = useState('1');
  const [editItemUnit, setEditItemUnit] = useState('');
  const [editItemCategory, setEditItemCategory] = useState<string | null>(null);
  const [editItemEstimatedSum, setEditItemEstimatedSum] = useState('');
  const [savingItem, setSavingItem] = useState(false);
  const [savingTemplate, setSavingTemplate] = useState(false);

  const fetchItems = async () => {
    if (!id) return;
    try {
      const [listRes, itemsRes, curRes] = await Promise.all([
        supabase.from('shopping_lists').select('*').eq('id', id).single(),
        supabase.from('shopping_items').select('*').eq('list_id', id).order('id', { ascending: true }),
        user ? supabase.from('profiles').select('currency').eq('id', user.id).single() : Promise.resolve({ data: null, error: null }),
      ]);
      
      if (listRes.error) console.error('Fetch List Error:', listRes.error);
      if (itemsRes.error) console.error('Fetch Items Error:', itemsRes.error);

      if (curRes.data) setCurrency(curRes.data.currency);

      if (listRes.data) {
        setList(listRes.data);
        setEditName(listRes.data.name);
        setEditBudget(listRes.data.estimated_total?.toString() || '');
        
        // Fetch categories for this household
        const { data: cats } = await supabase.from('categories').select('*').eq('household_id', listRes.data.household_id);
        if (cats) setCategories(cats.filter(c => c.type === 'expense' || c.type === 'both'));
      }
      
      if (itemsRes.data) {
        setItems(itemsRes.data);
      }
    } catch (err) {
      console.error('fetchItems unexpected error:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchItems();
    const channel = supabase
      .channel(`shopping-${id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'shopping_items', filter: `list_id=eq.${id}` }, (payload) => {
        console.log('Realtime change:', payload.eventType);
        // Small delay to ensure DB consistency before refetching
        setTimeout(() => fetchItems(), 100);
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [id]);

  const onRefresh = useCallback(() => { setRefreshing(true); fetchItems(); }, [id]);

  const toggleItem = async (item: any) => {
    if (!item.is_checked) {
      // Prompt for actual price
      Alert.prompt(
        'Precio real de ' + item.name, 
        'Ingresa cuánto costó finalmente:', 
        [
          { text: 'Cancelar', style: 'cancel' },
          { text: 'Confirmar', onPress: async (val?: string) => {
              const actual = val ? Number(val.replace(/[^0-9.]/g, '')) : (item.estimated_price || 0);
              const finalPrice = isNaN(actual) ? 0 : actual;
              const { error } = await supabase.from('shopping_items').update({ is_checked: true, actual_price: finalPrice }).eq('id', item.id);
              if (!error) setItems(prev => prev.map(i => i.id === item.id ? { ...i, is_checked: true, actual_price: finalPrice } : i));
          }}
        ], 
        'plain-text', 
        item.actual_price ? String(item.actual_price) : (item.estimated_price ? String(item.estimated_price) : '')
      );
    } else {
      const { error } = await supabase.from('shopping_items').update({ is_checked: false }).eq('id', item.id);
      if (!error) setItems(prev => prev.map(i => i.id === item.id ? { ...i, is_checked: false } : i));
    }
  };

  const openEditItemModal = (item: any) => {
    setEditingItem(item);
    setEditItemName(item.name);
    setEditItemQuantity(item.quantity ? String(item.quantity) : '1');
    setEditItemUnit(item.unit || '');
    setEditItemCategory(item.category_id || null);
    setEditItemEstimatedSum(item.estimated_price ? String(item.estimated_price) : '');
  };

  const saveEditedItem = async () => {
    if (!editingItem || !editItemName.trim()) return;
    setSavingItem(true);
    try {
      const q = editItemQuantity ? Number(editItemQuantity.replace(/[^0-9.]/g, '')) : 1;
      const qnty = isNaN(q) ? 1 : q;
      const ep = editItemEstimatedSum ? Number(editItemEstimatedSum.replace(/[^0-9.]/g, '')) : null;
      const estPrice = ep !== null && !isNaN(ep) ? ep : null;
      
      const { data, error } = await supabase.from('shopping_items').update({
        name: editItemName.trim(),
        quantity: qnty,
        unit: editItemUnit.trim() || null,
        category_id: editItemCategory,
        estimated_price: estPrice
      }).eq('id', editingItem.id).select().single();
      
      if (error) throw error;
      setItems(prev => prev.map(i => i.id === editingItem.id ? data : i));
      setEditingItem(null);
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSavingItem(false);
    }
  };

  const addItem = async () => {
    if (!newItemName.trim()) return;
    setAddingItem(true);
    try {
      const { data, error } = await supabase.from('shopping_items').insert({
        list_id: id,
        name: newItemName.trim(),
        is_checked: false,
        added_by: user?.id,
      }).select().single();
      
      if (error) throw error;
      console.log('Item added successfully:', data.id);
      
      // We don't necessarily need to setItems here because Realtime will trigger fetchItems
      // but keeping it for immediate feedback. If it "disappears", fetchItems is the culprit.
      setItems(prev => {
        if (prev.find(i => i.id === data.id)) return prev;
        return [...prev, data];
      });
      setNewItemName('');
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setAddingItem(false);
    }
  };

  const deleteItem = async (itemId: string) => {
    await supabase.from('shopping_items').delete().eq('id', itemId);
    setItems(prev => prev.filter(i => i.id !== itemId));
  };

  const saveSettings = async () => {
    if (!editName.trim()) return;
    setSavingSettings(true);
    try {
      const { error } = await supabase.from('shopping_lists').update({
        name: editName.trim(),
        estimated_total: editBudget ? Number(editBudget) : null
      }).eq('id', id);
      if (error) throw error;
      setList((prev: any) => ({ ...prev, name: editName.trim(), estimated_total: editBudget ? Number(editBudget) : null }));
      setShowSettings(false);
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSavingSettings(false);
    }
  };

  const saveAsTemplate = async () => {
    setSavingTemplate(true);
    try {
      const templateItems = items.map(i => ({ 
        name: i.name, 
        quantity: i.quantity, 
        unit: i.unit, 
        category_id: i.category_id, 
        estimated_price: i.estimated_price 
      }));
      
      const { error } = await supabase.from('shopping_templates').insert({
        household_id: list.household_id,
        name: list.name,
        items: templateItems
      });
      if (error) throw error;
      Alert.alert('Éxito', 'Plantilla guardada correctamente.');
      setShowSettings(false);
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSavingTemplate(false);
    }
  };

  const deleteList = () => {
    Alert.alert('Eliminar Lista', '¿Estás seguro de que deseas eliminar esta lista?', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
        await supabase.from('shopping_lists').delete().eq('id', id);
        router.back();
      }}
    ]);
  };

  if (loading) return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.text} /></View>;

  const checkedCount = items.filter(i => i.is_checked).length;
  const currentTotal = items.reduce((sum, item) => sum + (Number(item.estimated_price) || 0), 0);
  const actualTotal = items.filter(i => i.is_checked).reduce((sum, item) => sum + (Number(item.actual_price) || 0), 0);
  const isOverBudget = list?.estimated_total && actualTotal > list.estimated_total;

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={[styles.header, { paddingTop: Math.max(insets.top, 12), backgroundColor: theme.background }]}>
        <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.pillBg }]} onPress={() => router.back()}>
          <HugeiconsIcon icon={ArrowLeft01Icon} size={24} color={theme.text} />
        </TouchableOpacity>
        <View style={{ flex: 1, alignItems: 'center' }}>
           <Text style={[styles.title, { color: theme.text }]} numberOfLines={1}>{list?.name}</Text>
           <Text style={[styles.subtitle, { color: isOverBudget ? theme.danger : theme.textMuted }]}>
             {checkedCount}/{items.length} completados{list?.estimated_total ? ` • Total: ${formatCurrency(actualTotal, currency)} / ${formatCurrency(list.estimated_total, currency)}` : ` • Total: ${formatCurrency(actualTotal, currency)}`}
           </Text>
           {list?.store && <Text style={[styles.subtitle, { color: theme.textMuted }]}>{list.store}</Text>}
        </View>
        <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.pillBg }]} onPress={() => setShowSettings(true)}>
          <HugeiconsIcon icon={Settings01Icon} size={24} color={theme.text} />
        </TouchableOpacity>
      </View>

      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.text} />}
      >
        {items.length === 0 ? (
          <View style={styles.emptyState}>
             <HugeiconsIcon icon={ShoppingCart01Icon} size={48} color={theme.border} />
             <Text style={[styles.emptyText, { color: theme.textMuted }]}>La lista está vacía</Text>
          </View>
        ) : items.map(item => (
          <TouchableOpacity
            key={item.id}
            style={[styles.itemRow, { borderBottomColor: theme.border }]}
            onPress={() => openEditItemModal(item)}
            onLongPress={() => Alert.alert('Eliminar', `¿Eliminar "${item.name}"?`, [
              { text: 'Cancelar', style: 'cancel' },
              { text: 'Eliminar', style: 'destructive', onPress: () => deleteItem(item.id) },
            ])}
          >
            <TouchableOpacity onPress={() => toggleItem(item)}>
              <HugeiconsIcon 
                icon={item.is_checked ? CheckmarkCircle02Icon : CircleIcon} 
                size={28} 
                color={item.is_checked ? '#22C55E' : theme.textMuted} 
              />
            </TouchableOpacity>
            <View style={{ flex: 1, marginLeft: 16 }}>
              <Text style={[styles.itemName, { color: theme.text }, item.is_checked && { color: theme.textMuted, textDecorationLine: 'line-through' }]}>
                {item.quantity && item.quantity > 1 ? `${item.quantity} ` : ''}{item.unit ? `${item.unit} ` : ''}{item.name}
              </Text>
              {item.category_id && (
                <Text style={{ color: theme.textMuted, fontSize: 13, marginTop: 4 }}>
                  {categories.find(c => c.id === item.category_id)?.name}
                </Text>
              )}
            </View>
            <View style={{ alignItems: 'flex-end', marginLeft: 8 }}>
              {item.is_checked ? (
                <Text style={{ color: theme.text, fontSize: 13, fontWeight: '600' }}>
                  {item.actual_price ? formatCurrency(item.actual_price, currency) : ''}
                </Text>
              ) : (
                <Text style={{ color: item.estimated_price ? theme.text : theme.primary, fontSize: 13, fontWeight: '600' }}>
                  {item.estimated_price ? formatCurrency(item.estimated_price, currency) : '+ Precio Est.'}
                </Text>
              )}
            </View>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {/* Hero-style Add Input */}
      <View style={[styles.footer, { paddingBottom: Math.max(insets.bottom, 20), backgroundColor: theme.background }]}>
         <View style={[styles.addInputGroup, { backgroundColor: theme.pillBg }]}>
            <TextInput
            style={[styles.addInput, { color: theme.text }]}
            placeholder="Nuevo ítem..."
            placeholderTextColor={theme.textMuted}
            value={newItemName}
            onChangeText={setNewItemName}
            onSubmitEditing={addItem}
            returnKeyType="done"
            />
            <TouchableOpacity style={[styles.addBtn, { backgroundColor: theme.text }]} onPress={addItem} disabled={addingItem}>
            {addingItem ? <ActivityIndicator color={theme.background} size="small" /> : <Text style={[styles.addBtnText, { color: theme.background }]}>+</Text>}
            </TouchableOpacity>
         </View>
      </View>

      {/* Settings Modal (Hero Style Edit) */}
      <Modal visible={showSettings} animationType="slide" transparent>
         <View style={[styles.modalOverlay, { backgroundColor: theme.background }]}>
            <View style={[styles.modalContent, { paddingTop: Math.max(insets.top, 20), paddingBottom: Math.max(insets.bottom, 20) }]}>
                <View style={styles.modalHeader}>
                    <TouchableOpacity style={[styles.closeBtn, { backgroundColor: theme.pillBg }]} onPress={() => setShowSettings(false)}>
                        <HugeiconsIcon icon={ArrowLeft01Icon} size={24} color={theme.text} />
                    </TouchableOpacity>
                    <Text style={[styles.modalTitle, { color: theme.text }]}>Configuración</Text>
                    <TouchableOpacity style={[styles.deleteBtn, { backgroundColor: isDark ? 'rgba(239, 68, 68, 0.1)' : 'rgba(239, 68, 68, 0.05)' }]} onPress={deleteList}>
                        <HugeiconsIcon icon={Delete01Icon} size={24} color={theme.danger} />
                    </TouchableOpacity>
                </View>

                <ScrollView keyboardShouldPersistTaps="handled">
                    <View style={styles.heroSection}>
                        <Text style={{ fontSize: 40, fontWeight: '700', color: theme.text, marginRight: 8, marginTop: 4 }}>$</Text>
                        <AmountInput
                            style={[styles.heroInput, { color: theme.text }]}
                            value={editBudget}
                            onChangeText={setEditBudget}
                            placeholder="0"
                            placeholderTextColor={theme.textMuted}
                        />
                    </View>
                    <Text style={[styles.heroLabel, { color: theme.textMuted }]}>Presupuesto Estimado</Text>

                    <View style={[styles.formCard, { backgroundColor: theme.card }]}>
                        <Text style={[styles.label, { color: theme.textMuted }]}>Nombre de la lista</Text>
                        <TextInput 
                            style={[styles.settingsInput, { color: theme.text, borderBottomColor: theme.border }]} 
                            value={editName} 
                            onChangeText={setEditName} 
                            placeholder="Nombre de la lista"
                            placeholderTextColor={theme.textMuted}
                        />
                    </View>
                </ScrollView>

                <TouchableOpacity style={[styles.saveBtn, { backgroundColor: theme.text }]} onPress={saveSettings} disabled={savingSettings}>
                    {savingSettings ? <ActivityIndicator color={theme.background} /> : <Text style={[styles.saveBtnText, { color: theme.background }]}>Guardar Cambios</Text>}
                </TouchableOpacity>

                <TouchableOpacity style={[styles.saveBtn, { backgroundColor: 'transparent', borderWidth: 1, borderColor: theme.border, marginTop: 16 }]} onPress={saveAsTemplate} disabled={savingTemplate}>
                    {savingTemplate ? <ActivityIndicator color={theme.text} /> : <Text style={[styles.saveBtnText, { color: theme.text }]}>Guardar como Plantilla</Text>}
                </TouchableOpacity>
            </View>
         </View>
      </Modal>

      {/* Edit Item Modal */}
      <Modal visible={!!editingItem} animationType="slide" transparent>
         <View style={[styles.modalOverlay, { backgroundColor: theme.background }]}>
            <View style={[styles.modalContent, { paddingTop: Math.max(insets.top, 20), paddingBottom: Math.max(insets.bottom, 20) }]}>
                <View style={styles.modalHeader}>
                    <TouchableOpacity style={[styles.closeBtn, { backgroundColor: theme.pillBg }]} onPress={() => setEditingItem(null)}>
                        <HugeiconsIcon icon={ArrowLeft01Icon} size={24} color={theme.text} />
                    </TouchableOpacity>
                    <Text style={[styles.modalTitle, { color: theme.text }]}>Editar Ítem</Text>
                    <TouchableOpacity style={[styles.deleteBtn, { backgroundColor: isDark ? 'rgba(239, 68, 68, 0.1)' : 'rgba(239, 68, 68, 0.05)' }]} onPress={() => { deleteItem(editingItem.id); setEditingItem(null); }}>
                        <HugeiconsIcon icon={Delete01Icon} size={24} color={theme.danger} />
                    </TouchableOpacity>
                </View>

                <ScrollView keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
                    <View style={[styles.formCard, { backgroundColor: theme.card, marginTop: 20 }]}>
                        <Text style={[styles.label, { color: theme.textMuted }]}>Nombre del producto</Text>
                        <TextInput 
                            style={[styles.settingsInput, { color: theme.text, borderBottomColor: theme.border, marginBottom: 24 }]} 
                            value={editItemName} 
                            onChangeText={setEditItemName} 
                        />

                        <View style={{ flexDirection: 'row', gap: 16, marginBottom: 24 }}>
                           <View style={{ flex: 1 }}>
                              <Text style={[styles.label, { color: theme.textMuted }]}>Cantidad</Text>
                              <TextInput 
                                  style={[styles.settingsInput, { color: theme.text, borderBottomColor: theme.border }]} 
                                  value={editItemQuantity} 
                                  onChangeText={setEditItemQuantity} 
                                  keyboardType="numeric"
                              />
                           </View>
                           <View style={{ flex: 1 }}>
                              <Text style={[styles.label, { color: theme.textMuted }]}>Unidad (Ej. kg, lb)</Text>
                              <TextInput 
                                  style={[styles.settingsInput, { color: theme.text, borderBottomColor: theme.border }]} 
                                  value={editItemUnit} 
                                  onChangeText={setEditItemUnit} 
                              />
                           </View>
                        </View>

                        <Text style={[styles.label, { color: theme.textMuted }]}>Precio Estimado</Text>
                        <AmountInput
                            style={[styles.settingsInput, { color: theme.text, borderBottomColor: theme.border, marginBottom: 24 }]}
                            value={editItemEstimatedSum}
                            onChangeText={setEditItemEstimatedSum}
                            placeholder="0"
                            placeholderTextColor={theme.textMuted}
                        />

                        <Text style={[styles.label, { color: theme.textMuted, marginTop: 12 }]}>Categoría del producto</Text>
                        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingVertical: 8 }}>
                          {categories.map(cat => {
                            const isSelected = editItemCategory === cat.id;
                            return (
                              <TouchableOpacity
                                key={cat.id}
                                style={{ flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, borderWidth: 1, borderColor: isSelected ? cat.color : theme.border, backgroundColor: isSelected ? `${cat.color}15` : theme.pillBg }}
                                onPress={() => setEditItemCategory(cat.id)}
                              >
                                <Text style={{ fontSize: 14, fontWeight: '600', color: isSelected ? cat.color : theme.text }}>{cat.name}</Text>
                              </TouchableOpacity>
                            )
                          })}
                        </ScrollView>
                    </View>
                </ScrollView>

                <TouchableOpacity style={[styles.saveBtn, { backgroundColor: theme.text }]} onPress={saveEditedItem} disabled={savingItem}>
                    {savingItem ? <ActivityIndicator color={theme.background} /> : <Text style={[styles.saveBtnText, { color: theme.background }]}>Guardar Ítem</Text>}
                </TouchableOpacity>
            </View>
         </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 16 },
  iconBtn: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderRadius: 22 },
  title: { fontSize: 17, fontWeight: '700' },
  subtitle: { fontSize: 12, marginTop: 2 },
  content: { padding: 20, paddingBottom: 100 },
  
  emptyState: { alignItems: 'center', justifyContent: 'center', marginTop: 100 },
  emptyText: { fontSize: 16, marginTop: 16, fontWeight: '500' },
  
  itemRow: { flexDirection: 'row', alignItems: 'center', gap: 16, paddingVertical: 18, borderBottomWidth: 1 },
  itemName: { fontSize: 16, fontWeight: '500', flex: 1 },
  
  footer: { paddingHorizontal: 20 },
  addInputGroup: { flexDirection: 'row', alignItems: 'center', borderRadius: 20, padding: 6, gap: 10 },
  addInput: { flex: 1, height: 48, paddingHorizontal: 16, fontSize: 16 },
  addBtn: { width: 44, height: 44, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  addBtnText: { fontSize: 24, fontWeight: '700' },

  modalOverlay: { flex: 1 },
  modalContent: { flex: 1, paddingHorizontal: 20 },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 },
  modalTitle: { fontSize: 18, fontWeight: '700' },
  closeBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  deleteBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  
  heroSection: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 100, marginTop: 20 },
  heroInput: { fontSize: 56, fontWeight: '800', textAlign: 'center', minWidth: 100 },
  heroLabel: { textAlign: 'center', fontSize: 13, fontWeight: '500', marginBottom: 32 },
  
  formCard: { borderRadius: 24, padding: 20 },
  label: { fontSize: 12, marginBottom: 12, fontWeight: '600', textTransform: 'uppercase' },
  settingsInput: { fontSize: 18, fontWeight: '600', borderBottomWidth: 1, paddingBottom: 8 },
  
  saveBtn: { height: 56, borderRadius: 28, alignItems: 'center', justifyContent: 'center', marginTop: 20 },
  saveBtnText: { fontSize: 17, fontWeight: '700' },
});
