import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator, Alert, ScrollView, Modal, TextInput, Image } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { SUBSCRIPTION_LOGOS, SubscriptionLogo } from '../src/data/SubscriptionLogos';
import { Delete01Icon } from '@hugeicons/core-free-icons';
import { HugeiconsIcon } from '@hugeicons/react-native';
import DynamicIcon from '../src/components/DynamicIcon';
import AmountInput from '../src/components/AmountInput';
import DaySelector from '../src/components/DaySelector';

const FREQUENCIES = ['monthly', 'weekly', 'yearly'];
const FREQ_LABELS: Record<string, string> = { monthly: 'Mensual', weekly: 'Semanal', yearly: 'Anual' };

export default function EditRecurringScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { theme, isDark } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const [name, setName] = useState('');
  const [amount, setAmount] = useState('');
  const [type, setType] = useState<'expense' | 'income'>('expense');
  const [frequency, setFrequency] = useState('monthly');
  const [dayOfMonth, setDayOfMonth] = useState('1');

  const [selectedLogo, setSelectedLogo] = useState<SubscriptionLogo | null>(null);
  const [showLogoModal, setShowLogoModal] = useState(false);

  const [categories, setCategories] = useState<any[]>([]);
  const [categoryId, setCategoryId] = useState<string | null>(null);
  const [showCategoryModal, setShowCategoryModal] = useState(false);

  useEffect(() => {
    const loadEvent = async () => {
      try {
        if (!id) throw new Error('No se proporcionó un ID válido.');
        const { data, error } = await supabase.from('recurring_events').select('*').eq('id', id).single();
        if (error || !data) throw error || new Error('No se encontró el evento recurrente.');

        setName(data.name);
        setAmount(String(data.amount));
        setType(data.type as 'expense' | 'income');
        setFrequency(data.frequency);
        setDayOfMonth(String(data.day_of_month));
        if (data.category_id) setCategoryId(data.category_id);

        const { data: catData } = await supabase.from('categories').select('*').eq('household_id', data.household_id);
        if (catData) setCategories(catData);

        if (data.logo_id) {
          const logo = SUBSCRIPTION_LOGOS.find(l => l.id === data.logo_id);
          if (logo) setSelectedLogo(logo);
        }
      } catch (err: any) {
        Alert.alert('Error', err.message);
        router.back();
      } finally {
        setLoading(false);
      }
    };
    loadEvent();
  }, [id]);

  const currentCategory = categories.find(c => c.id === categoryId);
  const filteredCategories = categories.filter(c => c.type === type);

  const calcNextDate = (day: number): string => {
    const today = new Date();
    const yr = today.getFullYear();
    const mo = today.getMonth();
    const d = today.getDate();
    const nextDate = day >= d
      ? new Date(yr, mo, day)
      : new Date(yr, mo + 1, day);
    return nextDate.toISOString().split('T')[0];
  };

  const handleUpdate = async () => {
    if (!name.trim()) { Alert.alert('Error', 'Ingresa un nombre.'); return; }
    if (!amount || isNaN(Number(amount))) { Alert.alert('Error', 'Monto inválido.'); return; }
    const day = Number(dayOfMonth);
    if (isNaN(day) || day < 1 || day > 31) { Alert.alert('Error', 'Día inválido (1-31).'); return; }
    setSaving(true);
    try {
      const { error } = await supabase.from('recurring_events').update({
        logo_id: selectedLogo ? selectedLogo.id : null,
        category_id: categoryId,
        name: name.trim(),
        amount: Number(amount),
        type,
        frequency,
        day_of_month: day,
        next_date: calcNextDate(day),
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
    Alert.alert('Eliminar', '¿Eliminar este evento recurrente?', [
      { text: 'Cancelar', style: 'cancel' },
      {
        text: 'Eliminar', style: 'destructive', onPress: async () => {
          setDeleting(true);
          try {
            await supabase.from('recurring_events').delete().eq('id', id);
            router.back();
          } catch (e: any) {
            Alert.alert('Error', e.message);
          } finally {
            setDeleting(false);
          }
        }
      }
    ]);
  };

  const handleSelectLogo = (logo: SubscriptionLogo) => {
    setSelectedLogo(logo);
    if (!name.trim() || SUBSCRIPTION_LOGOS.find(l => l.name === name)) {
      setName(logo.name);
    }
    setShowLogoModal(false);
  };

  if (loading) {
    return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.text} /></View>;
  }

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 10), paddingBottom: insets.bottom }]}>
      {/* HEADER */}
      <View style={styles.header}>
        <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.pillBg }]} onPress={() => router.back()}>
          <Text style={[styles.iconText, { color: theme.text }]}>✕</Text>
        </TouchableOpacity>

        <View style={styles.headerRight}>
          <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.pillBg }]} onPress={() => setType(type === 'income' ? 'expense' : 'income')}>
            <Text style={[styles.iconText, { color: theme.text }]}>{type === 'income' ? '↓' : '↑'}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.iconBtn, { backgroundColor: '#EF444420', borderWidth: 1, borderColor: '#EF444440' }]} onPress={handleDelete} disabled={deleting}>
            {deleting ? <ActivityIndicator size="small" color="#EF4444" /> : <HugeiconsIcon icon={Delete01Icon} size={20} color="#EF4444" />}
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.contentScroll} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
        {/* HUGE AMOUNT */}
        <View style={styles.amountContainer}>
          <Text style={[styles.currencySymbol, { color: type === 'income' ? '#22C55E' : '#EF4444' }]}>$</Text>
          <AmountInput
            style={[styles.amountText, { color: type === 'income' ? '#22C55E' : '#EF4444', minWidth: 100, padding: 0 }]}
            placeholder="0"
            placeholderTextColor="#3F3F46"
            value={amount}
            onChangeText={setAmount}
            autoFocus
            maxLength={14}
            selectionColor="#2563EB"
          />
        </View>

        {/* DETAILS SECTION */}
        <View style={styles.detailsSection}>
          <Text style={[styles.sectionLabel, { color: theme.textMuted }]}>Nombre del servicio</Text>
          <View style={[styles.inputContainer, { backgroundColor: theme.pillBg }]}>
            <TextInput
              style={[styles.textInput, { color: theme.text }]}
              placeholder="Ej. Netflix, Spotify, Arriendo"
              placeholderTextColor={theme.textMuted}
              value={name}
              onChangeText={setName}
            />
          </View>

          <Text style={[styles.sectionLabel, { marginTop: 12, color: theme.textMuted }]}>Frecuencia</Text>
          <View style={styles.pillGrid}>
            {FREQUENCIES.map(f => (
              <TouchableOpacity
                key={f}
                style={[
                  styles.choicePill,
                  { backgroundColor: theme.pillBg, borderColor: frequency === f ? theme.text : 'transparent' }
                ]}
                onPress={() => setFrequency(f)}
              >
                <Text style={[
                  styles.choicePillText,
                  { color: frequency === f ? theme.text : theme.textMuted }
                ]}>
                  {FREQ_LABELS[f]}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <View style={{ marginTop: 24 }}>
              <Text style={[styles.sectionLabel, { marginBottom: 0, color: theme.textMuted }]}>Día de cobro</Text>
              <DaySelector selectedDay={dayOfMonth} onSelectDay={setDayOfMonth} color={type === 'income' ? '#22C55E' : '#EF4444'} />
          </View>

          <Text style={[styles.sectionLabel, { marginTop: 12, color: theme.textMuted }]}>Categoría</Text>
          <TouchableOpacity
            style={[styles.inputContainer, { backgroundColor: theme.pillBg, flexDirection: 'row', alignItems: 'center', gap: 10 }]}
            onPress={() => setShowCategoryModal(true)}
          >
            {currentCategory ? (
               <>
                 <DynamicIcon name={currentCategory.icon} size={20} color={currentCategory.color} />
                 <Text style={[styles.textInput, { color: theme.text }]}>{currentCategory.name}</Text>
               </>
            ) : (
               <Text style={[styles.textInput, { color: theme.textMuted }]}>Seleccionar categoría</Text>
            )}
          </TouchableOpacity>
        </View>
      </ScrollView>

      {/* FIXED BOTTOM ACTIONS */}
      <View style={styles.bottomActions}>
        <TouchableOpacity
          style={[styles.categoryPillBtn, { backgroundColor: theme.pillBg }, selectedLogo ? { borderWidth: 1, borderColor: theme.border } : undefined, { flexDirection: 'row', alignItems: 'center', gap: 10 }]}
          onPress={() => setShowLogoModal(true)}
        >
          {selectedLogo ? (
            <Image source={selectedLogo.logo} style={{ width: 24, height: 24 }} resizeMode="contain" />
          ) : (
            <Text style={{ fontSize: 20, color: theme.text }}>✦</Text>
          )}
          <Text style={[styles.categoryPillBtnText, { color: theme.text }]} numberOfLines={1}>
            {selectedLogo ? selectedLogo.name : 'Servicio'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.saveBtn, { backgroundColor: theme.text }]}
          onPress={handleUpdate}
          disabled={saving || !amount || amount === '0'}
        >
          {saving ? <ActivityIndicator color={theme.background} /> : <Text style={[styles.saveBtnText, { color: theme.background }]}>Actualizar</Text>}
        </TouchableOpacity>
      </View>

      {/* LOGO SELECTOR MODAL */}
      <Modal visible={showLogoModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowLogoModal(false)} />
          <View style={[styles.modalContent, { backgroundColor: theme.card }]}>
            <View style={[styles.modalHandle, { backgroundColor: theme.border }]} />
            <View style={[styles.modalHeader, { borderBottomColor: theme.border }]}>
              <Text style={[styles.modalTitle, { color: theme.text }]}>Seleccionar Servicio</Text>
              <TouchableOpacity onPress={() => setShowLogoModal(false)} style={[styles.modalCloseBtn, { backgroundColor: theme.pillBg }]}>
                <Text style={[styles.modalCloseText, { color: theme.text }]}>✕</Text>
              </TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={styles.logoGrid}>
              <TouchableOpacity
                style={[styles.modalLogoBox, { backgroundColor: theme.pillBg }, !selectedLogo && { borderColor: theme.text, borderWidth: 2 }]}
                onPress={() => { setSelectedLogo(null); setShowLogoModal(false); }}
              >
                <Text style={[styles.noLogoText, { color: theme.textMuted }]}>Ninguno</Text>
              </TouchableOpacity>

              {SUBSCRIPTION_LOGOS.filter(l => l.id !== 'none').map(logo => (
                <TouchableOpacity
                  key={logo.id}
                  style={[styles.modalLogoBox, { backgroundColor: theme.pillBg }, selectedLogo?.id === logo.id && { borderColor: theme.text, borderWidth: 2 }]}
                  onPress={() => handleSelectLogo(logo)}
                >
                  <Image source={logo.logo} style={styles.logoImg} resizeMode="contain" />
                  <Text style={[styles.logoName, { color: theme.text }]} numberOfLines={1} ellipsizeMode="tail">{logo.name}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>
        </View>
      </Modal>

      {/* CATEGORY SELECTOR MODAL */}
      <Modal visible={showCategoryModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowCategoryModal(false)} />
          <View style={[styles.modalContent, { backgroundColor: theme.card }]}>
            <View style={[styles.modalHandle, { backgroundColor: theme.border }]} />
            <View style={[styles.modalHeader, { borderBottomColor: theme.border }]}>
              <Text style={[styles.modalTitle, { color: theme.text }]}>Seleccionar Categoría</Text>
              <TouchableOpacity onPress={() => setShowCategoryModal(false)} style={[styles.modalCloseBtn, { backgroundColor: theme.pillBg }]}>
                <Text style={[styles.modalCloseText, { color: theme.text }]}>✕</Text>
              </TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={styles.categoryGrid}>
              {filteredCategories.map(cat => (
                <TouchableOpacity
                  key={cat.id}
                  style={[styles.modalCatPill, { backgroundColor: theme.pillBg, borderColor: cat.color, borderWidth: categoryId === cat.id ? 2 : 1 }]}
                  onPress={() => {
                    setCategoryId(cat.id);
                    setShowCategoryModal(false);
                  }}
                >
                  <DynamicIcon name={cat.icon} size={20} color={cat.color} />
                  <Text style={[styles.modalCatText, { color: cat.color, marginLeft: 8 }]}>{cat.name}</Text>
                </TouchableOpacity>
              ))}
              {filteredCategories.length === 0 && (
                <Text style={[styles.emptyText, { color: theme.textMuted }]}>No hay categorías de este tipo.</Text>
              )}
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
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 10 },
  iconBtn: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
  iconText: { fontSize: 18, fontWeight: '600' },
  headerRight: { flexDirection: 'row', gap: 12, alignItems: 'center' },

  contentScroll: { paddingHorizontal: 20, paddingBottom: 20 },
  amountContainer: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 140, marginBottom: 10 },
  currencySymbol: { fontSize: 44, fontWeight: '700', marginRight: 4, marginTop: 10 },
  amountText: { fontSize: 72, fontWeight: '800', fontVariant: ['tabular-nums'], flexShrink: 1, letterSpacing: -2 },

  detailsSection: { gap: 12 },
  sectionLabel: { fontSize: 13, fontWeight: '500', marginBottom: 12, marginLeft: 4 },
  inputContainer: { borderRadius: 16, paddingHorizontal: 18, paddingVertical: 16 },
  textInput: { fontSize: 17, letterSpacing: 0 },

  pillGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  choicePill: { paddingHorizontal: 18, paddingVertical: 14, borderRadius: 20, borderWidth: 1 },
  choicePillText: { fontWeight: '600', fontSize: 15 },

  bottomActions: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 16, paddingBottom: 16 },
  categoryPillBtn: { paddingHorizontal: 18, paddingVertical: 14, borderRadius: 24, maxWidth: '60%' },
  categoryPillBtnText: { fontWeight: '600', fontSize: 16 },
  saveBtn: { paddingHorizontal: 28, paddingVertical: 14, borderRadius: 24 },
  saveBtnText: { fontWeight: '800', fontSize: 16 },

  // MODAL STYLES
  modalOverlay: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(0,0,0,0.5)' },
  modalBackdropClose: { ...StyleSheet.absoluteFillObject },
  modalContent: { borderTopLeftRadius: 24, borderTopRightRadius: 24, maxHeight: '80%', minHeight: '50%' },
  modalHandle: { width: 40, height: 4, borderRadius: 2, alignSelf: 'center', marginTop: 12 },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 16, borderBottomWidth: 1 },
  modalTitle: { fontSize: 18, fontWeight: '600' },
  modalCloseBtn: { width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  modalCloseText: { fontSize: 14, fontWeight: '600' },

  logoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, padding: 20 },
  modalLogoBox: { width: '31%', aspectRatio: 1, borderRadius: 16, alignItems: 'center', justifyContent: 'center', padding: 10, borderWidth: 2, borderColor: 'transparent' },
  logoImg: { width: 40, height: 40, marginBottom: 8 },
  logoName: { fontSize: 12, fontWeight: '500', textAlign: 'center' },
  noLogoText: { fontSize: 14, fontWeight: '600' },

  categoryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, padding: 20 },
  modalCatPill: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1 },
  modalCatText: { fontSize: 15, fontWeight: '600' },
  emptyText: { fontSize: 14, textAlign: 'center', marginTop: 20, width: '100%' },
});
