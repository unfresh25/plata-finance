import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DateTimePicker from '@react-native-community/datetimepicker';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Delete01Icon } from '@hugeicons/core-free-icons';
import AmountInput from '../src/components/AmountInput';

export default function EditDebtScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user } = useAuth();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [householdId, setHouseholdId] = useState<string | null>(null);

  // Form State
  const [direction, setDirection] = useState<'owed_to_us' | 'we_owe'>('owed_to_us');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [person, setPerson] = useState('');

  // Date State
  const [dueDate, setDueDate] = useState(new Date());
  const [showDatePicker, setShowDatePicker] = useState(false);

  useEffect(() => {
    const fetchOptions = async () => {
      if (!user || !id) return;
      const { data: pData } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (pData?.household_id) {
        setHouseholdId(pData.household_id);
      }

      const { data: debt } = await supabase.from('debts').select('*').eq('id', id).single();
      if (debt) {
        setDirection(debt.direction);
        setAmount(String(debt.amount));
        setDescription(debt.description || '');
        setPerson(debt.person_name || '');
        if (debt.due_date) {
            setDateFromString(debt.due_date);
        }
      }
      setLoading(false);
    };
    fetchOptions();
  }, [user, id]);

  const setDateFromString = (dateStr: string) => {
    const [y, m, d] = dateStr.split('T')[0].split('-');
    setDueDate(new Date(Number(y), Number(m) - 1, Number(d)));
  };

  const handleSave = async () => {
    if (!amount || isNaN(Number(amount))) {
      Alert.alert('Error', 'Ingresa un monto válido.');
      return;
    }
    if (!person.trim()) {
      Alert.alert('Error', 'Ingresa el nombre de la persona.');
      return;
    }

    setSaving(true);
    try {
      const { error } = await supabase.from('debts').update({
        description: description.trim() || null,
        person_name: person.trim(),
        amount: Number(amount),
        direction,
        due_date: dueDate.toISOString().split('T')[0],
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
    Alert.alert('Eliminar Deuda', '¿Estás seguro de que quieres eliminar esta deuda? Su historial transaccional podría quedar huérfano.', [
        { text: 'Cancelar', style: 'cancel' },
        { text: 'Eliminar', style: 'destructive', onPress: async () => {
            try {
                await supabase.from('debts').delete().eq('id', id);
                router.back();
            } catch (e: any) {
                Alert.alert('Error', e.message);
            }
        }}
    ]);
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
          <TouchableOpacity style={[styles.iconBtn, { width: undefined, paddingHorizontal: 16 }]} onPress={() => setDirection(isOwed ? 'we_owe' : 'owed_to_us')}>
            <Text style={[styles.iconText, { fontSize: 15 }]}>{isOwed ? 'Nos deben ↓' : 'Debemos ↑'}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.iconBtn, { backgroundColor: '#EF444420', borderWidth: 1, borderColor: '#EF444440' }]} onPress={handleDelete}>
            <HugeiconsIcon icon={Delete01Icon} size={20} color="#EF4444" />
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
        </View>
      </ScrollView>

      {/* FIXED BOTTOM ACTIONS */}
      <View style={styles.bottomActions}>
        <View />
        <TouchableOpacity
          style={styles.saveBtn}
          onPress={handleSave}
          disabled={saving || !amount || amount === '0' || !person.trim()}
        >
          {saving ? <ActivityIndicator color="#09090B" /> : <Text style={styles.saveBtnText}>Guardar</Text>}
        </TouchableOpacity>
      </View>
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
  inputContainer: { backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 16, paddingHorizontal: 18, paddingVertical: 16 },
  textInput: { color: '#FAFAFA', fontSize: 17, letterSpacing: 0 },

  bottomActions: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 16, paddingBottom: 16 },
  saveBtn: { backgroundColor: '#FAFAFA', paddingHorizontal: 28, paddingVertical: 14, borderRadius: 24, minWidth: 140, alignItems: 'center' },
  saveBtnText: { color: '#000000', fontWeight: '800', fontSize: 16 },
});
