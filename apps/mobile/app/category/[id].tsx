import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ScrollView, ActivityIndicator, Alert, Modal, Platform } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { useAuth } from '../../src/context/AuthContext';
import { useTheme } from '../../src/context/ThemeContext';
import { CategoryIconGroups } from '../../src/lib/IconDictionary';
import DynamicIcon from '../../src/components/DynamicIcon';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Delete01Icon } from '@hugeicons/core-free-icons';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';

const COLORS = ['#EF4444', '#F97316', '#F59E0B', '#84CC16', '#22C55E', '#14B8A6', '#06B6D4', '#3B82F6', '#6366F1', '#8B5CF6', '#D946EF', '#F43F5E', '#64748B'];
// Aplanar todos los íconos de todos los grupos y asegurar que son unicos (aunque no deberia haber repetidos)
const ALL_ICONS = Array.from(new Set(CategoryIconGroups.flatMap(g => g.items.map(i => i.icon))));

export default function CategoryEditScreen() {
  const { id } = useLocalSearchParams();
  const isNew = id === 'new';
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(!isNew);
  const [saving, setSaving] = useState(false);
  const [showIconModal, setShowIconModal] = useState(false);
  
  const [name, setName] = useState('');
  const [type, setType] = useState<'income' | 'expense'>('expense');
  const [color, setColor] = useState(COLORS[0]);
  const [icon, setIcon] = useState(ALL_ICONS[0] || 'dashboard-square-01');

  useEffect(() => {
    if (!isNew && id) {
      supabase.from('categories').select('*').eq('id', id).single()
        .then(({ data, error }) => {
          if (data) {
            setName(data.name);
            setType(data.type);
            setColor(data.color || COLORS[0]);
            setIcon(data.icon || ALL_ICONS[0]);
          }
          if (error) Alert.alert('Error', error.message);
          setLoading(false);
        });
    }
  }, [id, isNew]);

  const handleSave = async () => {
    if (!name.trim()) return Alert.alert('Error', 'El nombre no puede estar vacío');
    setSaving(true);
    
    try {
      const { data: pData } = await supabase.from('profiles').select('household_id').eq('id', user?.id).single();
      
      const payload = {
        household_id: pData?.household_id,
        name: name.trim(),
        type,
        color,
        icon
      };

      if (isNew) {
        const { error } = await supabase.from('categories').insert(payload);
        if (error) throw error;
      } else {
        const { error } = await supabase.from('categories').update(payload).eq('id', id);
        if (error) throw error;
      }
      router.back();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = () => {
    Alert.alert('Eliminar categoría', '¿Estás seguro? Las transacciones asociadas podrían perder su categoría.', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
        setSaving(true);
        const { error } = await supabase.from('categories').delete().eq('id', id);
        setSaving(false);
        if (error) Alert.alert('Error', error.message);
        else router.back();
      }}
    ]);
  };

  if (loading) return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 12) }]}>
      <Stack.Screen options={{ headerShown: false }} />
      
      {/* HEADER */}
      <View style={styles.header}>
        <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.card }]} onPress={() => router.back()}>
          <Text style={[styles.iconText, { color: theme.text }]}>✕</Text>
        </TouchableOpacity>
        <Text style={[styles.title, { color: theme.text }]}>{isNew ? 'Nueva Categoría' : 'Editar Categoría'}</Text>
        <View style={{ width: 44 }} />
      </View>

      <ScrollView contentContainerStyle={styles.contentScroll} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
        
        {/* HUGE PREVIEW */}
        <View style={styles.amountContainer}>
          <TouchableOpacity 
            style={[styles.giantIconBox, { backgroundColor: color + '20' }]}
            onPress={() => setShowIconModal(true)}
            activeOpacity={0.7}
          >
            <DynamicIcon name={icon} size={48} color={color} />
          </TouchableOpacity>
          <TextInput
            style={[styles.amountText, { color: theme.text }]}
            placeholder="Nombre de categoría"
            placeholderTextColor={theme.textMuted}
            value={name}
            onChangeText={setName}
            autoFocus
            selectionColor={color}
          />
        </View>

        {/* DETAILS SECTION */}
        <View style={styles.detailsSection}>
          <Text style={styles.sectionLabel}>TIPO DE MOVIMIENTO</Text>
          <View style={styles.typeRow}>
            <TouchableOpacity 
              style={[styles.typeBtn, type === 'expense' ? { backgroundColor: '#EF4444', borderColor: '#EF4444' } : { backgroundColor: theme.card, borderColor: theme.border }]} 
              onPress={() => setType('expense')}
            >
              <Text style={[styles.typeBtnText, type === 'expense' ? { color: '#FFF' } : { color: theme.textMuted }]}>Gasto</Text>
            </TouchableOpacity>
            <TouchableOpacity 
              style={[styles.typeBtn, type === 'income' ? { backgroundColor: '#22C55E', borderColor: '#22C55E' } : { backgroundColor: theme.card, borderColor: theme.border }]} 
              onPress={() => setType('income')}
            >
              <Text style={[styles.typeBtnText, type === 'income' ? { color: '#FFF' } : { color: theme.textMuted }]}>Ingreso</Text>
            </TouchableOpacity>
          </View>

          <Text style={[styles.sectionLabel, { marginTop: 12 }]}>COLOR</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.colorScroll}>
            {COLORS.map(c => (
              <TouchableOpacity
                key={c}
                style={[styles.colorCircle, { backgroundColor: c }, color === c && styles.colorSelected]}
                onPress={() => setColor(c)}
              >
                {color === c && <Text style={{ color: '#FFF', fontWeight: 'bold' }}>✓</Text>}
              </TouchableOpacity>
            ))}
          </ScrollView>

          {!isNew && (
            <TouchableOpacity style={styles.deleteBtn} onPress={handleDelete}>
              <HugeiconsIcon icon={Delete01Icon} size={20} color="#EF4444" />
              <Text style={styles.deleteText}>Eliminar Categoría</Text>
            </TouchableOpacity>
          )}

        </View>
      </ScrollView>

      {/* FIXED BOTTOM ACTIONS */}
      <View style={styles.bottomActions}>
         <TouchableOpacity
          style={[styles.categoryPillBtn, { backgroundColor: color, flexDirection: 'row', alignItems: 'center', gap: 8 }]}
          onPress={() => setShowIconModal(true)}
        >
          <DynamicIcon name={icon} size={20} color="#FAFAFA" />
          <Text style={styles.categoryPillBtnText}>Elegir ícono</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.saveBtn}
          onPress={handleSave}
          disabled={saving || !name.trim()}
        >
          {saving ? <ActivityIndicator color="#09090B" /> : <Text style={styles.saveBtnText}>Guardar</Text>}
        </TouchableOpacity>
      </View>

      {/* FLAT ICON SELECTOR MODAL */}
      <Modal visible={showIconModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowIconModal(false)} />
          <View style={[styles.modalContent, { backgroundColor: theme.card }]}>
            <View style={styles.modalHandle} />
            <View style={styles.modalHeader}>
              <Text style={[styles.modalTitle, { color: theme.text }]}>Seleccionar Ícono</Text>
              <TouchableOpacity onPress={() => setShowIconModal(false)} style={[styles.modalCloseBtn, { backgroundColor: theme.border }]}>
                <Text style={[styles.modalCloseText, { color: theme.text }]}>✕</Text>
              </TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={styles.categoryGrid} showsVerticalScrollIndicator={false}>
              {ALL_ICONS.map((ic, idx) => (
                <TouchableOpacity
                  key={`ic-${idx}`}
                  style={[styles.modalIconCell, icon === ic && { backgroundColor: color + '20', borderColor: color, borderWidth: 1 }]}
                  onPress={() => {
                    setIcon(ic);
                    setShowIconModal(false);
                  }}
                >
                  <DynamicIcon name={ic} size={28} color={icon === ic ? color : theme.text} />
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>
        </View>
      </Modal>

    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },

  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 10 },
  iconBtn: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
  iconText: { fontSize: 18, fontWeight: '600' },
  title: { fontSize: 18, fontWeight: '700' },

  contentScroll: { paddingHorizontal: 20, paddingBottom: 20 },

  amountContainer: { flexDirection: 'column', alignItems: 'center', marginTop: 30, marginBottom: 40, gap: 16 },
  giantIconBox: { width: 96, height: 96, borderRadius: 32, alignItems: 'center', justifyContent: 'center' },
  amountText: { fontSize: 36, fontWeight: '800', letterSpacing: -0.5, textAlign: 'center', padding: 0 },

  detailsSection: { gap: 12 },
  sectionLabel: { fontSize: 13, color: '#71717A', fontWeight: '500', marginBottom: 8, marginLeft: 4, letterSpacing: 0.5 },

  typeRow: { flexDirection: 'row', gap: 12, marginBottom: 24 },
  typeBtn: { flex: 1, paddingVertical: 14, borderRadius: 16, alignItems: 'center', borderWidth: 1 },
  typeBtnText: { fontSize: 16, fontWeight: '600' },

  colorScroll: { gap: 12 },
  colorCircle: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
  colorSelected: { borderWidth: 3, borderColor: '#FAFAFA' },

  deleteBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 40, padding: 16, backgroundColor: 'rgba(239,68,68,0.1)', borderRadius: 16 },
  deleteText: { color: '#EF4444', fontSize: 16, fontWeight: '600' },

  bottomActions: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 16, paddingBottom: 16 },
  categoryPillBtn: { paddingHorizontal: 18, paddingVertical: 14, borderRadius: 24 },
  categoryPillBtnText: { color: '#FFFFFF', fontWeight: '600', fontSize: 16 },
  saveBtn: { backgroundColor: '#FAFAFA', paddingHorizontal: 28, paddingVertical: 14, borderRadius: 24 },
  saveBtnText: { color: '#000000', fontWeight: '800', fontSize: 16 },

  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'flex-end' },
  modalBackdropClose: { ...StyleSheet.absoluteFillObject },
  modalContent: { borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24, height: '70%', backgroundColor: '#121212' },
  modalHandle: { width: 40, height: 4, backgroundColor: '#3F3F46', borderRadius: 2, alignSelf: 'center', marginBottom: 20 },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 },
  modalTitle: { fontSize: 18, fontWeight: '700' },
  modalCloseBtn: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center' },
  modalCloseText: { fontSize: 16, fontWeight: '700' },
  
  categoryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, paddingBottom: 40, justifyContent: 'center' },
  modalIconCell: { width: 56, height: 56, borderRadius: 16, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: 'transparent' },
});
