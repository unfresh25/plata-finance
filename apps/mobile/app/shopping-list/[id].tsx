import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, RefreshControl, TouchableOpacity, TextInput, Alert, Modal } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ArrowLeft01Icon, Settings01Icon, ShoppingCart01Icon, Delete01Icon, CheckmarkCircle02Icon, CircleIcon } from '@hugeicons/core-free-icons';
import AmountInput from '../../src/components/AmountInput';

export default function ShoppingListDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { user } = useAuth();
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

  const fetchItems = async () => {
    if (!id) return;
    try {
      const [listRes, itemsRes] = await Promise.all([
        supabase.from('shopping_lists').select('*').eq('id', id).single(),
        supabase.from('shopping_items').select('*').eq('list_id', id),
      ]);
      
      if (listRes.error) console.error('Fetch List Error:', listRes.error);
      if (itemsRes.error) console.error('Fetch Items Error:', itemsRes.error);

      if (listRes.data) {
        setList(listRes.data);
        setEditName(listRes.data.name);
        setEditBudget(listRes.data.estimated_total?.toString() || '');
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
    const { error } = await supabase.from('shopping_items').update({ is_checked: !item.is_checked }).eq('id', item.id);
    if (!error) setItems(prev => prev.map(i => i.id === item.id ? { ...i, is_checked: !i.is_checked } : i));
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

  const deleteList = () => {
    Alert.alert('Eliminar Lista', '¿Estás seguro de que deseas eliminar esta lista?', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
        await supabase.from('shopping_lists').delete().eq('id', id);
        router.back();
      }}
    ]);
  };

  if (loading) return <View style={styles.center}><ActivityIndicator color="#FAFAFA" /></View>;

  const checkedCount = items.filter(i => i.is_checked).length;

  return (
    <View style={[styles.container, { backgroundColor: '#000000' }]}>
      <View style={[styles.header, { paddingTop: Math.max(insets.top, 12) }]}>
        <TouchableOpacity style={styles.iconBtn} onPress={() => router.back()}>
          <HugeiconsIcon icon={ArrowLeft01Icon} size={24} color="#FAFAFA" />
        </TouchableOpacity>
        <View style={{ flex: 1, alignItems: 'center' }}>
           <Text style={styles.title} numberOfLines={1}>{list?.name}</Text>
           <Text style={styles.subtitle}>{checkedCount}/{items.length} completados</Text>
        </View>
        <TouchableOpacity style={styles.iconBtn} onPress={() => setShowSettings(true)}>
          <HugeiconsIcon icon={Settings01Icon} size={24} color="#FAFAFA" />
        </TouchableOpacity>
      </View>

      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#2563EB" />}
      >
        {items.length === 0 ? (
          <View style={styles.emptyState}>
             <HugeiconsIcon icon={ShoppingCart01Icon} size={48} color="rgba(255,255,255,0.1)" />
             <Text style={styles.emptyText}>La lista está vacía</Text>
          </View>
        ) : items.map(item => (
          <TouchableOpacity
            key={item.id}
            style={styles.itemRow}
            onPress={() => toggleItem(item)}
            onLongPress={() => Alert.alert('Eliminar', `¿Eliminar "${item.name}"?`, [
              { text: 'Cancelar', style: 'cancel' },
              { text: 'Eliminar', style: 'destructive', onPress: () => deleteItem(item.id) },
            ])}
          >
            <HugeiconsIcon 
              icon={item.is_checked ? CheckmarkCircle02Icon : CircleIcon} 
              size={24} 
              color={item.is_checked ? '#22C55E' : '#3F3F46'} 
            />
            <Text style={[styles.itemName, item.is_checked && styles.itemNameChecked]}>{item.name}</Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {/* Hero-style Add Input */}
      <View style={[styles.footer, { paddingBottom: Math.max(insets.bottom, 20) }]}>
         <View style={styles.addInputGroup}>
            <TextInput
            style={styles.addInput}
            placeholder="Nuevo ítem..."
            placeholderTextColor="#71717A"
            value={newItemName}
            onChangeText={setNewItemName}
            onSubmitEditing={addItem}
            returnKeyType="done"
            />
            <TouchableOpacity style={styles.addBtn} onPress={addItem} disabled={addingItem}>
            {addingItem ? <ActivityIndicator color="#000" size="small" /> : <Text style={styles.addBtnText}>+</Text>}
            </TouchableOpacity>
         </View>
      </View>

      {/* Settings Modal (Hero Style Edit) */}
      <Modal visible={showSettings} animationType="slide" transparent>
         <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { paddingTop: Math.max(insets.top, 20), paddingBottom: Math.max(insets.bottom, 20) }]}>
                <View style={styles.modalHeader}>
                    <TouchableOpacity style={styles.closeBtn} onPress={() => setShowSettings(false)}>
                        <HugeiconsIcon icon={ArrowLeft01Icon} size={24} color="#FAFAFA" />
                    </TouchableOpacity>
                    <Text style={styles.modalTitle}>Configuración</Text>
                    <TouchableOpacity style={styles.deleteBtn} onPress={deleteList}>
                        <HugeiconsIcon icon={Delete01Icon} size={24} color="#EF4444" />
                    </TouchableOpacity>
                </View>

                <ScrollView keyboardShouldPersistTaps="handled">
                    <View style={styles.heroSection}>
                        <Text style={{ fontSize: 40, fontWeight: '700', color: '#60A5FA', marginRight: 8, marginTop: 4 }}>$</Text>
                        <AmountInput
                            style={styles.heroInput}
                            value={editBudget}
                            onChangeText={setEditBudget}
                            placeholder="0"
                            placeholderTextColor="rgba(255,255,255,0.2)"
                        />
                    </View>
                    <Text style={styles.heroLabel}>Presupuesto Estimado</Text>

                    <View style={styles.formCard}>
                        <Text style={styles.label}>Nombre de la lista</Text>
                        <TextInput 
                            style={styles.settingsInput} 
                            value={editName} 
                            onChangeText={setEditName} 
                            placeholder="Nombre de la lista"
                            placeholderTextColor="rgba(113, 113, 122, 0.7)"
                        />
                    </View>
                </ScrollView>

                <TouchableOpacity style={styles.saveBtn} onPress={saveSettings} disabled={savingSettings}>
                    {savingSettings ? <ActivityIndicator color="#000" /> : <Text style={styles.saveBtnText}>Guardar Cambios</Text>}
                </TouchableOpacity>
            </View>
         </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, backgroundColor: '#000000', alignItems: 'center', justifyContent: 'center' },
  header: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 16, backgroundColor: '#000000' },
  iconBtn: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderRadius: 22, backgroundColor: 'rgba(255,255,255,0.05)' },
  title: { fontSize: 17, fontWeight: '700', color: '#FAFAFA' },
  subtitle: { fontSize: 12, color: '#A1A1AA', marginTop: 2 },
  content: { padding: 20, paddingBottom: 100 },
  
  emptyState: { alignItems: 'center', justifyContent: 'center', marginTop: 100 },
  emptyText: { color: '#3F3F46', fontSize: 16, marginTop: 16, fontWeight: '500' },
  
  itemRow: { flexDirection: 'row', alignItems: 'center', gap: 16, paddingVertical: 18, borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.03)' },
  itemName: { fontSize: 16, color: '#FAFAFA', fontWeight: '500', flex: 1 },
  itemNameChecked: { textDecorationLine: 'line-through', color: '#52525B' },
  
  footer: { paddingHorizontal: 20, backgroundColor: '#000000' },
  addInputGroup: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 20, padding: 6, gap: 10 },
  addInput: { flex: 1, height: 48, paddingHorizontal: 16, color: '#FAFAFA', fontSize: 16 },
  addBtn: { width: 44, height: 44, borderRadius: 16, backgroundColor: '#FAFAFA', alignItems: 'center', justifyContent: 'center' },
  addBtnText: { color: '#000', fontSize: 24, fontWeight: '700' },

  modalOverlay: { flex: 1, backgroundColor: '#000000' },
  modalContent: { flex: 1, paddingHorizontal: 20 },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 },
  modalTitle: { fontSize: 18, fontWeight: '700', color: '#FAFAFA' },
  closeBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)', alignItems: 'center', justifyContent: 'center' },
  deleteBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(239, 68, 68, 0.1)', alignItems: 'center', justifyContent: 'center' },
  
  heroSection: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 100, marginTop: 20 },
  heroInput: { fontSize: 56, fontWeight: '800', color: '#FAFAFA', textAlign: 'center', minWidth: 100 },
  heroLabel: { textAlign: 'center', color: '#A1A1AA', fontSize: 13, fontWeight: '500', marginBottom: 32 },
  
  formCard: { backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 24, padding: 20 },
  label: { fontSize: 12, color: '#A1A1AA', marginBottom: 12, fontWeight: '600', textTransform: 'uppercase' },
  settingsInput: { color: '#FAFAFA', fontSize: 18, fontWeight: '600', borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.1)', paddingBottom: 8 },
  
  saveBtn: { backgroundColor: '#FAFAFA', height: 56, borderRadius: 28, alignItems: 'center', justifyContent: 'center', marginTop: 20 },
  saveBtnText: { color: '#000', fontSize: 17, fontWeight: '700' },
});
