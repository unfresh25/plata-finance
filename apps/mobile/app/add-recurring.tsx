import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView, Modal, Image } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { SUBSCRIPTION_LOGOS, SubscriptionLogo } from '../src/data/SubscriptionLogos';
import DateTimePicker from '@react-native-community/datetimepicker';
import DynamicIcon from '../src/components/DynamicIcon';
import AmountInput from '../src/components/AmountInput';
import DaySelector from '../src/components/DaySelector';

const FREQUENCIES = ['monthly', 'weekly', 'yearly'];
const FREQ_LABELS: Record<string, string> = { monthly: 'Mensual', weekly: 'Semanal', yearly: 'Anual' };
const TYPES = ['expense', 'income'];

export default function AddRecurringScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();
  const insets = useSafeAreaInsets();

  const [saving, setSaving] = useState(false);
  const [householdId, setHouseholdId] = useState<string | null>(null);

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
    const load = async () => {
      if (!user) return;
      const { data: p } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (p?.household_id) {
        setHouseholdId(p.household_id);
        const { data: catData } = await supabase.from('categories').select('*').eq('household_id', p.household_id);
        if (catData) setCategories(catData);
      }
    };
    load();
  }, [user]);

  const currentCategory = categories.find(c => c.id === categoryId);
  const filteredCategories = categories.filter(c => c.type === type);

  const calcNextDate = (day: number): string => {
    const today = new Date();
    const yr = today.getFullYear();
    const mo = today.getMonth();
    const d = today.getDate();
    // If the day hasn't passed yet this month, use this month; otherwise next month
    const nextDate = day >= d
      ? new Date(yr, mo, day)
      : new Date(yr, mo + 1, day);
    return nextDate.toISOString().split('T')[0];
  };

  const handleSave = async () => {
    if (!name.trim()) { Alert.alert('Error', 'Ingresa un nombre.'); return; }
    if (!amount || isNaN(Number(amount))) { Alert.alert('Error', 'Monto inválido.'); return; }
    if (!categoryId) { Alert.alert('Error', 'Selecciona una categoría.'); return; }
    const day = Number(dayOfMonth);
    if (isNaN(day) || day < 1 || day > 31) { Alert.alert('Error', 'Día inválido (1-31).'); return; }
    setSaving(true);
    try {
      const { error } = await supabase.from('recurring_events').insert({
        household_id: householdId,
        category_id: categoryId,
        logo_id: selectedLogo ? selectedLogo.id : null,
        name: name.trim(),
        amount: Number(amount),
        type,
        frequency,
        day_of_month: day,
        is_active: true,
        next_date: calcNextDate(day),
      });
      if (error) throw error;
      router.back();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSaving(false);
    }
  };

  const handleSelectLogo = (logo: SubscriptionLogo) => {
    setSelectedLogo(logo);
    if (!name.trim()) {
      setName(logo.name);
    }
    setShowLogoModal(false);
  };

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

          <Text style={[styles.sectionLabel, { marginTop: 12, color: theme.textMuted }]}>Categoría</Text>
          <TouchableOpacity 
            style={[styles.inputContainer, { backgroundColor: theme.pillBg, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 14 }]}
            onPress={() => setShowCategoryModal(true)}
          >
            {currentCategory ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                <DynamicIcon name={currentCategory.icon} size={20} color={currentCategory.color} />
                <Text style={[styles.textInput, { color: theme.text }]}>{currentCategory.name}</Text>
              </View>
            ) : (
              <Text style={[styles.textInput, { color: theme.textMuted }]}>Seleccionar categoría</Text>
            )}
            <Text style={{ color: theme.textMuted, fontSize: 18 }}>›</Text>
          </TouchableOpacity>

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
          <Text style={[styles.categoryPillBtnText, { color: theme.text }]}>
            {selectedLogo ? selectedLogo.name : 'Servicio'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.saveBtn, { backgroundColor: theme.text }]}
          onPress={handleSave}
          disabled={saving || !amount || amount === '0'}
        >
          {saving ? <ActivityIndicator color={theme.background} /> : <Text style={[styles.saveBtnText, { color: theme.background }]}>Guardar</Text>}
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
