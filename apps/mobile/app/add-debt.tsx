import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView, Modal, Switch } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DateTimePicker from '@react-native-community/datetimepicker';
import DynamicIcon from '../src/components/DynamicIcon';
import AmountInput from '../src/components/AmountInput';
import DaySelector from '../src/components/DaySelector';

const FREQUENCIES = [
  { value: 'weekly', label: 'Semanal' },
  { value: 'biweekly', label: 'Quincenal' },
  { value: 'monthly', label: 'Mensual' },
  { value: 'yearly', label: 'Anual' },
];

export default function AddDebtScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [householdId, setHouseholdId] = useState<string | null>(null);
  const [categories, setCategories] = useState<any[]>([]);

  // Form State
  const [direction, setDirection] = useState<'owed_to_us' | 'we_owe'>('owed_to_us');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [person, setPerson] = useState('');
  const [categoryId, setCategoryId] = useState<string | null>(null);

  // Installments / Recurring
  const [isRecurring, setIsRecurring] = useState(false);
  const [frequency, setFrequency] = useState('monthly');
  const [installmentAmount, setInstallmentAmount] = useState('');
  const [dayOfMonth, setDayOfMonth] = useState('1');

  // Date & Modals
  const [dueDate, setDueDate] = useState(new Date());
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showCategoryModal, setShowCategoryModal] = useState(false);

  useEffect(() => {
    const fetchOptions = async () => {
      if (!user) return;
      const { data: pData } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (pData?.household_id) {
        setHouseholdId(pData.household_id);
        const { data: cats } = await supabase.from('categories').select('*').eq('household_id', pData.household_id);
        setCategories(cats || []);
      }
      setLoading(false);
    };
    fetchOptions();
  }, [user]);

  const handleSave = async () => {
    if (!amount || isNaN(Number(amount))) {
      return Alert.alert('Error', 'Ingresa un monto válido.');
    }
    if (!person.trim()) {
      return Alert.alert('Error', 'Ingresa el nombre de la persona.');
    }
    if (isRecurring && (!installmentAmount || isNaN(Number(installmentAmount)))) {
      return Alert.alert('Error', 'Ingresa de cuánto será cada cuota.');
    }

    setSaving(true);
    try {
      // 1. Insert Debt
      const { data: debtData, error: debtError } = await supabase.from('debts').insert({
        household_id: householdId,
        created_by: user?.id,
        category_id: categoryId,
        description: description.trim() || null,
        person_name: person.trim(),
        amount: Number(amount),
        amount_paid: 0,
        direction,
        due_date: dueDate.toISOString().split('T')[0],
        status: 'active',
      }).select().single();

      if (debtError) throw debtError;

      // 2. If Recurring, explicitly create a Recurring Event bound to this Debt
      if (isRecurring && debtData) {
        const calcNextDate = (day: number): string => {
            const today = new Date();
            const yr = today.getFullYear();
            const mo = today.getMonth();
            const d = today.getDate();
            const nextDate = day >= d
                ? new Date(yr, mo, day)
                : new Date(yr, mo + 1, day);
            return `${nextDate.getFullYear()}-${String(nextDate.getMonth()+1).padStart(2,'0')}-${String(nextDate.getDate()).padStart(2,'0')}T12:00:00`;
        };

        const txType = direction === 'owed_to_us' ? 'income' : 'expense';

        const { error: recError } = await supabase.from('recurring_events').insert({
          household_id: householdId,
          debt_id: debtData.id,
          name: description.trim() || 'Deuda',
          amount: Number(installmentAmount) || 0,
          type: txType,
          category_id: categoryId,
          frequency, 
          day_of_month: Number(dayOfMonth) || 1,
          next_date: calcNextDate(Number(dayOfMonth) || 1),
          is_active: true
        });
        if (recError) throw recError;
      }

      router.back();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;
  }

  const formatDateText = (d: Date) => {
    const today = new Date();
    if (d.toDateString() === today.toDateString()) return 'Hoy';
    return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' });
  };

  const isOwed = direction === 'owed_to_us';
  const txType = isOwed ? 'income' : 'expense';
  const filteredCategories = categories.filter(c => c.type === txType);
  const currentCategory = categories.find(c => c.id === categoryId);

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 10), paddingBottom: insets.bottom }]}>
      {/* HEADER */}
      <View style={styles.header}>
        <TouchableOpacity style={styles.iconBtn} onPress={() => router.back()}>
          <Text style={styles.iconText}>✕</Text>
        </TouchableOpacity>

        <View style={styles.headerRight}>
          <TouchableOpacity style={styles.headerPill} onPress={() => setShowDatePicker(true)}>
            <Text style={styles.headerPillText}>{formatDateText(dueDate)}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.iconBtn, { width: undefined, paddingHorizontal: 16 }]} onPress={() => { setDirection(isOwed ? 'we_owe' : 'owed_to_us'); setCategoryId(null); }}>
            <Text style={[styles.iconText, { fontSize: 15 }]}>{isOwed ? 'Nos deben ↓' : 'Debemos ↑'}</Text>
          </TouchableOpacity>
        </View>
      </View>

      {showDatePicker && (
        <DateTimePicker
          value={dueDate}
          mode="date"
          display="default"
          onChange={(event, selectedDate) => {
            setShowDatePicker(false);
            if (selectedDate) setDueDate(selectedDate);
          }}
        />
      )}

      <ScrollView contentContainerStyle={styles.contentScroll} showsVerticalScrollIndicator={false}>
        {/* HUGE AMOUNT */}
        <View style={styles.amountContainer}>
          <Text style={[styles.currencySymbol, { color: isOwed ? '#22C55E' : '#EF4444' }]}>$</Text>
          <AmountInput
            style={[styles.amountText, { color: isOwed ? '#22C55E' : '#EF4444', minWidth: 100, padding: 0 }]}
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
          <Text style={styles.sectionLabel}>Persona involucrada</Text>
          <View style={styles.inputContainer}>
            <TextInput
              style={styles.textInput}
              placeholder="Ej. Juan, María, Banco..."
              placeholderTextColor="#71717A"
              value={person}
              onChangeText={setPerson}
            />
          </View>

          <Text style={[styles.sectionLabel, { marginTop: 12 }]}>Descripción / Concepto</Text>
          <View style={styles.inputContainer}>
            <TextInput
              style={styles.textInput}
              placeholder="Ej. Préstamo para el auto, Cena..."
              placeholderTextColor="#71717A"
              value={description}
              onChangeText={setDescription}
            />
          </View>

          {/* RECURRING PLAN */}
          <View style={styles.recurringSection}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                <View>
                    <Text style={{ color: '#FAFAFA', fontSize: 17, fontWeight: '600' }}>Plan de Pagos (Automatizado)</Text>
                    <Text style={{ color: '#A1A1AA', fontSize: 13, marginTop: 4 }}>Crear cuotas periódicas en calendario.</Text>
                </View>
                <Switch
                    value={isRecurring}
                    onValueChange={setIsRecurring}
                    trackColor={{ false: '#3F3F46', true: '#2563EB' }}
                    thumbColor="#FAFAFA"
                />
            </View>

            {isRecurring && (
                <View style={{ marginTop: 20, gap: 16 }}>
                    <Text style={[styles.sectionLabel, { marginBottom: 0 }]}>Frecuencia de las cuotas</Text>
                    <View style={styles.freqRings}>
                        {FREQUENCIES.map(f => (
                            <TouchableOpacity 
                                key={f.value} 
                                style={[styles.freqPill, frequency === f.value && { backgroundColor: '#3B82F6', borderColor: '#3B82F6' }]}
                                onPress={() => setFrequency(f.value)}
                            >
                                <Text style={{ color: frequency === f.value ? '#FFF' : '#A1A1AA', fontWeight: '500' }}>{f.label}</Text>
                            </TouchableOpacity>
                        ))}
                    </View>

                    <Text style={[styles.sectionLabel, { marginBottom: 0 }]}>Monto exacto de cada cuota</Text>
                    <View style={styles.inputContainer}>
                        <Text style={{ color: '#A1A1AA', fontSize: 20, marginRight: 8 }}>$</Text>
                        <AmountInput
                            style={styles.textInput}
                            placeholder="0.00"
                            placeholderTextColor="#71717A"
                            value={installmentAmount}
                            onChangeText={setInstallmentAmount}
                        />
                    </View>

                    <Text style={[styles.sectionLabel, { marginBottom: 0, marginTop: 12 }]}>Día de cobro</Text>
                    <DaySelector selectedDay={dayOfMonth} onSelectDay={setDayOfMonth} color={'#2563EB'} />
                </View>
            )}
          </View>

        </View>
      </ScrollView>

      {/* FIXED BOTTOM ACTIONS */}
      <View style={styles.bottomActions}>
         <TouchableOpacity
          style={[styles.categoryPillBtn, currentCategory ? { backgroundColor: currentCategory.color } : undefined]}
          onPress={() => setShowCategoryModal(true)}
        >
          {currentCategory ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                <DynamicIcon name={currentCategory.icon} size={20} color="#FAFAFA" />
                <Text style={styles.categoryPillBtnText}>{currentCategory.name}</Text>
            </View>
          ) : (
            <Text style={styles.categoryPillBtnText}>Categoría</Text>
          )}
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.saveBtn}
          onPress={handleSave}
          disabled={saving || !amount || amount === '0' || !person.trim()}
        >
          {saving ? <ActivityIndicator color="#09090B" /> : <Text style={styles.saveBtnText}>Guardar</Text>}
        </TouchableOpacity>
      </View>

      {/* CATEGORY SELECTOR MODAL */}
      <Modal visible={showCategoryModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowCategoryModal(false)} />
          <View style={styles.modalContent}>
            <View style={styles.modalHandle} />
            <Text style={styles.modalTitle}>Filtrado por: {isOwed ? 'Ingresos' : 'Gastos'}</Text>
            <ScrollView contentContainerStyle={styles.categoryGrid}>
              {filteredCategories.map(cat => (
                <TouchableOpacity
                  key={cat.id}
                  style={[styles.modalCatPill, { borderColor: cat.color, borderWidth: categoryId === cat.id ? 2 : 1 }]}
                  onPress={() => { setCategoryId(cat.id); setShowCategoryModal(false); }}
                >
                  <DynamicIcon name={cat.icon} size={20} color={cat.color} />
                  <Text style={[styles.modalCatText, { color: cat.color, marginLeft: 8 }]}>{cat.name}</Text>
                </TouchableOpacity>
              ))}
              {filteredCategories.length === 0 && (
                <Text style={styles.emptyText}>No hay categorías para este tipo de movimiento.</Text>
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
  iconBtn: { height: 44, borderRadius: 22, backgroundColor: 'rgba(255,255,255,0.1)', alignItems: 'center', justifyContent: 'center', width: 44 },
  iconText: { color: '#FAFAFA', fontSize: 18, fontWeight: '600' },
  headerRight: { flexDirection: 'row', gap: 12, alignItems: 'center' },
  headerPill: { backgroundColor: 'rgba(255,255,255,0.1)', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20 },
  headerPillText: { color: '#FAFAFA', fontWeight: '600', fontSize: 15 },

  contentScroll: { paddingHorizontal: 20, paddingBottom: 20 },

  amountContainer: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 140, marginBottom: 20 },
  currencySymbol: { fontSize: 44, fontWeight: '700', marginRight: 4, marginTop: 10 },
  amountText: { fontSize: 72, fontWeight: '800', fontVariant: ['tabular-nums'], maxWidth: '90%', letterSpacing: -2 },

  detailsSection: { gap: 12 },
  sectionLabel: { fontSize: 13, color: '#71717A', fontWeight: '500', marginBottom: 8, marginLeft: 4 },
  inputContainer: { flexDirection: 'row', backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 16, paddingHorizontal: 18, paddingVertical: 16, alignItems: 'center' },
  textInput: { flex: 1, color: '#FAFAFA', fontSize: 17, letterSpacing: 0 },

  recurringSection: { marginTop: 20, backgroundColor: 'rgba(255,255,255,0.03)', borderRadius: 20, padding: 16, borderWidth: 1, borderColor: '#27272A' },
  freqRings: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  freqPill: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, borderWidth: 1, borderColor: '#3F3F46', backgroundColor: '#18181B' },

  bottomActions: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 16, paddingBottom: 16 },
  categoryPillBtn: { backgroundColor: '#3F3F46', paddingHorizontal: 18, paddingVertical: 14, borderRadius: 24, justifyContent: 'center' },
  categoryPillBtnText: { color: '#FFFFFF', fontWeight: '600', fontSize: 16 },
  saveBtn: { backgroundColor: '#FAFAFA', paddingHorizontal: 32, paddingVertical: 14, borderRadius: 24, minWidth: 120, alignItems: 'center' },
  saveBtnText: { color: '#000000', fontWeight: '800', fontSize: 16 },

  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'flex-end' },
  modalBackdropClose: { ...StyleSheet.absoluteFillObject },
  modalContent: { backgroundColor: '#121212', borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24, height: '50%' },
  modalHandle: { width: 40, height: 4, backgroundColor: '#3F3F46', borderRadius: 2, alignSelf: 'center', marginBottom: 20 },
  modalTitle: { color: '#A1A1AA', fontSize: 14, fontWeight: '600', marginBottom: 20, textTransform: 'uppercase' },
  categoryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, paddingBottom: 40 },
  modalCatPill: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)' },
  modalCatText: { fontSize: 15, fontWeight: '600' },
  emptyText: { color: '#71717A', fontSize: 15 },
});
