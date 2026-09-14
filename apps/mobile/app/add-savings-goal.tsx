import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView, Modal, Switch } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DateTimePicker from '@react-native-community/datetimepicker';
import DynamicIcon from '../src/components/DynamicIcon';
import * as IconList from '@hugeicons/core-free-icons';
import AmountInput from '../src/components/AmountInput';
import DaySelector from '../src/components/DaySelector';

const FREQUENCIES = [
  { value: 'weekly', label: 'Semanal' },
  { value: 'biweekly', label: 'Quincenal' },
  { value: 'monthly', label: 'Mensual' },
  { value: 'yearly', label: 'Anual' },
];

const GOAL_ICONS = [
  { id: '1', icon: 'airplane-01', name: 'Viaje', color: '#3B82F6' },
  { id: '2', icon: 'home-01', name: 'Vivienda', color: '#8B5CF6' },
  { id: '3', icon: 'car-01', name: 'Vehículo', color: '#F59E0B' },
  { id: '4', icon: 'laptop', name: 'Tecnología', color: '#10B981' },
  { id: '5', icon: 'favourite', name: 'Salud', color: '#EF4444' },
  { id: '6', icon: 'book-01', name: 'Estudios', color: '#06B6D4' },
  { id: '7', icon: 'star', name: 'Retiro', color: '#EC4899' },
  { id: '8', icon: 'piggy-bank', name: 'Ahorro', color: '#22C55E' },
];

export default function AddSavingsGoalScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [householdId, setHouseholdId] = useState<string | null>(null);
  const [accounts, setAccounts] = useState<any[]>([]);

  // Form State
  const [amount, setAmount] = useState('');
  const [name, setName] = useState('');
  const [selectedIcon, setSelectedIcon] = useState(GOAL_ICONS[7]);
  const [accountId, setAccountId] = useState<string | null>(null);

  // Installments / Recurring
  const [isRecurring, setIsRecurring] = useState(false);
  const [frequency, setFrequency] = useState('monthly');
  const [installmentAmount, setInstallmentAmount] = useState('');
  const [dayOfMonth, setDayOfMonth] = useState('1');

  // Date & Modals
  const [dueDate, setDueDate] = useState<Date | null>(null);
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showIconModal, setShowIconModal] = useState(false);
  const [showAccountModal, setShowAccountModal] = useState(false);

  useEffect(() => {
    const fetchOptions = async () => {
      if (!user) return;
      const { data: pData } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (pData?.household_id) {
        setHouseholdId(pData.household_id);
        const { data: accs } = await supabase.from('accounts').select('*').eq('household_id', pData.household_id);
        setAccounts(accs || []);
      }
      setLoading(false);
    };
    fetchOptions();
  }, [user]);

  const handleSave = async () => {
    if (!amount || isNaN(Number(amount))) {
      return Alert.alert('Error', 'Ingresa una meta deseada válida.');
    }
    if (!name.trim()) {
      return Alert.alert('Error', 'Ingresa el nombre de la meta.');
    }
    if (isRecurring && (!installmentAmount || isNaN(Number(installmentAmount)))) {
      return Alert.alert('Error', 'Ingresa de cuánto será cada cuota programada.');
    }

    setSaving(true);
    try {
      // 1. Insert Savings Goal
      const { data: goalData, error: goalError } = await supabase.from('savings_goals').insert({
        household_id: householdId,
        name: name.trim(),
        target_amount: Number(amount),
        current_amount: 0,
        deadline: dueDate ? dueDate.toISOString().split('T')[0] : null,
        icon: selectedIcon.icon,
        color: selectedIcon.color,
        account_id: accountId,
        status: 'active',
      }).select().single();

      if (goalError) throw goalError;

      // 2. If Recurring, explicitly create a Recurring Event bound to this Goal
      if (isRecurring && goalData) {
        const calcNextDate = (day: number): string => {
          const today = new Date();
          const yr = today.getFullYear();
          const mo = today.getMonth();
          const d = today.getDate();
          const nextDate = day >= d
            ? new Date(yr, mo, day)
            : new Date(yr, mo + 1, day);
          return `${nextDate.getFullYear()}-${String(nextDate.getMonth() + 1).padStart(2, '0')}-${String(nextDate.getDate()).padStart(2, '0')}T12:00:00`;
        };

        const { error: recError } = await supabase.from('recurring_events').insert({
          household_id: householdId,
          savings_goal_id: goalData.id,
          name: `Aporte: ${name.trim()}`,
          amount: Number(installmentAmount),
          type: 'expense', // Treats saving as an expense to remove money from the main budget
          frequency,
          day_of_month: Number(dayOfMonth) || 1,
          next_date: calcNextDate(Number(dayOfMonth) || 1),
          is_active: true,
          account_id: accountId // the origin account (where the money is theoretically withheld)
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
    return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.text} /></View>;
  }

  const formatDateText = (d: Date | null) => {
    if (!d) return '+ Fecha Límite';
    const today = new Date();
    if (d.toDateString() === today.toDateString()) return 'Hoy';
    return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' });
  };

  const selectedAccount = accounts.find(a => a.id === accountId);

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 10), paddingBottom: insets.bottom }]}>
      {/* HEADER */}
      <View style={styles.header}>
        <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.pillBg }]} onPress={() => router.back()}>
          <Text style={[styles.iconText, { color: theme.text }]}>✕</Text>
        </TouchableOpacity>

        <View style={styles.headerRight}>
          <TouchableOpacity style={[styles.headerPill, { backgroundColor: theme.pillBg }]} onPress={() => setShowDatePicker(true)}>
            <Text style={[styles.headerPillText, { color: theme.text }]}>{formatDateText(dueDate)}</Text>
          </TouchableOpacity>
        </View>
      </View>

      {showDatePicker && (
        <DateTimePicker
          value={dueDate || new Date()}
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
          <Text style={[styles.currencySymbol, { color: selectedIcon.color }]}>$</Text>
          <AmountInput
            style={[styles.amountText, { color: selectedIcon.color, minWidth: 100, padding: 0 }]}
            placeholder="0"
            placeholderTextColor="#3F3F46"
            value={amount}
            onChangeText={setAmount}
            autoFocus
            maxLength={14}
            selectionColor={selectedIcon.color}
          />
        </View>

        {/* DETAILS SECTION */}
        <View style={styles.detailsSection}>
          <Text style={[styles.sectionLabel, { color: theme.textMuted }]}>¿Qué quieres lograr?</Text>
          <View style={[styles.inputContainer, { backgroundColor: theme.pillBg }]}>
            <TextInput
              style={[styles.textInput, { color: theme.text }]}
              placeholder="Ej. Viaje a Japón, Auto nuevo..."
              placeholderTextColor={theme.textMuted}
              value={name}
              onChangeText={setName}
            />
          </View>

          <Text style={[styles.sectionLabel, { marginTop: 12, color: theme.textMuted }]}>¿Dónde reservas este dinero?</Text>
          <TouchableOpacity
            style={[styles.inputContainer, { paddingVertical: 18, backgroundColor: theme.pillBg }]}
            onPress={() => setShowAccountModal(true)}
          >
            <Text style={[styles.textInput, { color: selectedAccount ? theme.text : theme.textMuted }]}>
              {selectedAccount ? selectedAccount.name : 'Cuenta de ahorro (Opcional)'}
            </Text>
          </TouchableOpacity>

          {/* RECURRING PLAN */}
          <View style={[styles.recurringSection, { backgroundColor: isDark ? 'rgba(255,255,255,0.03)' : theme.pillBg, borderColor: theme.border }]}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
              <View>
                <Text style={{ color: theme.text, fontSize: 17, fontWeight: '600' }}>Plan de Ahorro Programado</Text>
                <Text style={{ color: theme.textMuted, fontSize: 13, marginTop: 4 }}>Deducir automáticamente en el mes.</Text>
              </View>
              <Switch
                value={isRecurring}
                onValueChange={setIsRecurring}
                trackColor={{ false: theme.border, true: selectedIcon.color }}
                thumbColor={isDark ? '#FFF' : '#FFF'}
              />
            </View>

            {isRecurring && (
              <View style={{ marginTop: 20, gap: 16 }}>
                <Text style={[styles.sectionLabel, { marginBottom: 0, color: theme.textMuted }]}>Frecuencia de aporte</Text>
                <View style={styles.freqRings}>
                  {FREQUENCIES.map(f => (
                    <TouchableOpacity
                      key={f.value}
                      style={[styles.freqPill, { backgroundColor: frequency === f.value ? selectedIcon.color : theme.card, borderColor: frequency === f.value ? selectedIcon.color : theme.border }]}
                      onPress={() => setFrequency(f.value)}
                    >
                      <Text style={{ color: frequency === f.value ? '#FFF' : theme.textMuted, fontWeight: '500' }}>{f.label}</Text>
                    </TouchableOpacity>
                  ))}
                </View>

                <Text style={[styles.sectionLabel, { marginBottom: 0, color: theme.textMuted }]}>Monto a reservar por periodo</Text>
                <View style={[styles.inputContainer, { backgroundColor: theme.card }]}>
                  <Text style={{ color: theme.textMuted, fontSize: 20, marginRight: 8 }}>$</Text>
                  <AmountInput
                    style={[styles.textInput, { color: theme.text }]}
                    placeholder="0.00"
                    placeholderTextColor={theme.textMuted}
                    value={installmentAmount}
                    onChangeText={setInstallmentAmount}
                  />
                </View>

                <Text style={[styles.sectionLabel, { marginBottom: 0, marginTop: 12, color: theme.textMuted }]}>Día del mes</Text>
                <DaySelector selectedDay={dayOfMonth} onSelectDay={setDayOfMonth} color={selectedIcon.color} />
              </View>
            )}
          </View>

        </View>
      </ScrollView>

      {/* FIXED BOTTOM ACTIONS */}
      <View style={styles.bottomActions}>
        <TouchableOpacity
          style={[styles.categoryPillBtn, { backgroundColor: selectedIcon.color }]}
          onPress={() => setShowIconModal(true)}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
            <DynamicIcon name={selectedIcon.icon} size={20} color={isDark ? '#FAFAFA' : '#FFFFFF'} />
            <Text style={styles.categoryPillBtnText}>{selectedIcon.name}</Text>
          </View>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.saveBtn, { backgroundColor: theme.text }]}
          onPress={handleSave}
          disabled={saving || !amount || amount === '0' || !name.trim()}
        >
          {saving ? <ActivityIndicator color={theme.background} /> : <Text style={[styles.saveBtnText, { color: theme.background }]}>Guardar</Text>}
        </TouchableOpacity>
      </View>

      {/* ICON SELECTOR MODAL */}
      <Modal visible={showIconModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowIconModal(false)} />
          <View style={[styles.modalContent, { backgroundColor: theme.card }]}>
            <View style={[styles.modalHandle, { backgroundColor: theme.border }]} />
            <Text style={[styles.modalTitle, { color: theme.textMuted }]}>Elige un icono visual</Text>
            <ScrollView contentContainerStyle={styles.categoryGrid}>
              {GOAL_ICONS.map(cat => (
                <TouchableOpacity
                  key={cat.id}
                  style={[styles.modalCatPill, { backgroundColor: theme.pillBg, borderColor: cat.color, borderWidth: selectedIcon.id === cat.id ? 2 : 1 }]}
                  onPress={() => { setSelectedIcon(cat); setShowIconModal(false); }}
                >
                  <DynamicIcon name={cat.icon} size={20} color={cat.color} />
                  <Text style={[styles.modalCatText, { color: cat.color, marginLeft: 8 }]}>{cat.name}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>
        </View>
      </Modal>

      {/* ACCOUNT MODAL */}
      <Modal visible={showAccountModal} animationType="fade" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowAccountModal(false)} />
          <View style={[styles.modalContent, { backgroundColor: theme.card, height: 'auto', maxHeight: '60%' }]}>
            <Text style={[styles.modalTitle, { color: theme.textMuted }]}>Cuenta Vinculada</Text>
            <ScrollView contentContainerStyle={{ paddingBottom: 20 }}>
              <TouchableOpacity
                style={[styles.modalCatPill, { backgroundColor: theme.pillBg, marginBottom: 10, borderColor: theme.border, borderWidth: accountId === null ? 2 : 1 }]}
                onPress={() => { setAccountId(null); setShowAccountModal(false); }}
              >
                <Text style={[styles.modalCatText, { color: theme.textMuted }]}>Ninguna (Solo referencial)</Text>
              </TouchableOpacity>
              {accounts.map(acc => (
                <TouchableOpacity
                  key={acc.id}
                  style={[styles.modalCatPill, { backgroundColor: theme.pillBg, marginBottom: 10, borderColor: acc.color, borderWidth: accountId === acc.id ? 2 : 1 }]}
                  onPress={() => { setAccountId(acc.id); setShowAccountModal(false); }}
                >
                  <DynamicIcon name={acc.icon} size={20} color={acc.color} />
                  <Text style={[styles.modalCatText, { color: theme.text, marginLeft: 8 }]}>{acc.name}</Text>
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

  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 10 },
  iconBtn: { height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', width: 44 },
  iconText: { fontSize: 18, fontWeight: '600' },
  headerRight: { flexDirection: 'row', gap: 12, alignItems: 'center' },
  headerPill: { paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20 },
  headerPillText: { fontWeight: '600', fontSize: 15 },

  contentScroll: { paddingHorizontal: 20, paddingBottom: 20 },

  amountContainer: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 140, marginBottom: 20 },
  currencySymbol: { fontSize: 44, fontWeight: '700', marginRight: 4, marginTop: 10 },
  amountText: { fontSize: 72, fontWeight: '800', fontVariant: ['tabular-nums'], flexShrink: 1, letterSpacing: -2 },

  detailsSection: { gap: 12 },
  sectionLabel: { fontSize: 13, fontWeight: '500', marginBottom: 8, marginLeft: 4 },
  inputContainer: { flexDirection: 'row', borderRadius: 16, paddingHorizontal: 18, paddingVertical: 16, alignItems: 'center' },
  textInput: { flex: 1, fontSize: 17, letterSpacing: 0 },

  recurringSection: { marginTop: 20, borderRadius: 20, padding: 16, borderWidth: 1 },
  freqRings: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  freqPill: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, borderWidth: 1 },

  bottomActions: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 16, paddingBottom: 16 },
  categoryPillBtn: { paddingHorizontal: 18, paddingVertical: 14, borderRadius: 24, justifyContent: 'center' },
  categoryPillBtnText: { color: '#FFFFFF', fontWeight: '600', fontSize: 16 },
  saveBtn: { paddingHorizontal: 32, paddingVertical: 14, borderRadius: 24, minWidth: 120, alignItems: 'center' },
  saveBtnText: { fontWeight: '800', fontSize: 16 },

  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'flex-end' },
  modalBackdropClose: { ...StyleSheet.absoluteFillObject },
  modalContent: { borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24, height: '50%' },
  modalHandle: { width: 40, height: 4, borderRadius: 2, alignSelf: 'center', marginBottom: 20 },
  modalTitle: { fontSize: 14, fontWeight: '600', marginBottom: 20, textTransform: 'uppercase' },
  categoryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, paddingBottom: 40 },
  modalCatPill: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20 },
  modalCatText: { fontSize: 15, fontWeight: '600' },
});
