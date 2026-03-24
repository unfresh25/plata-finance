import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView, Modal } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DateTimePicker from '@react-native-community/datetimepicker';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Delete01Icon } from '@hugeicons/core-free-icons';
import AmountInput from '../src/components/AmountInput';
import DynamicIcon from '../src/components/DynamicIcon';

const GOAL_ICONS = [
  { id: '1', icon: 'airplane', name: 'Viaje', color: '#3B82F6' },
  { id: '2', icon: 'home-02', name: 'Vivienda', color: '#8B5CF6' },
  { id: '3', icon: 'car-01', name: 'Vehículo', color: '#F59E0B' },
  { id: '4', icon: 'laptop-programming', name: 'Tecnología', color: '#10B981' },
  { id: '5', icon: 'favourite', name: 'Salud', color: '#EF4444' },
  { id: '6', icon: 'book-open-01', name: 'Estudios', color: '#06B6D4' },
  { id: '7', icon: 'star', name: 'Retiro', color: '#EC4899' },
  { id: '8', icon: 'piggy-bank', name: 'Ahorro', color: '#22C55E' },
];

export default function EditSavingsGoalScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user } = useAuth();
  const { theme } = useTheme();
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

  // Date & Modals
  const [dueDate, setDueDate] = useState<Date | null>(null);
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showIconModal, setShowIconModal] = useState(false);
  const [showAccountModal, setShowAccountModal] = useState(false);

  useEffect(() => {
    const fetchGoal = async () => {
      if (!user || !id) return;
      const { data: pData } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (pData?.household_id) {
        setHouseholdId(pData.household_id);
        const { data: accs } = await supabase.from('accounts').select('*').eq('household_id', pData.household_id);
        setAccounts(accs || []);
      }

      const { data: goal } = await supabase.from('savings_goals').select('*').eq('id', id).single();
      if (goal) {
        setAmount(String(goal.target_amount));
        setName(goal.name);
        setAccountId(goal.account_id);
        if (goal.icon && goal.color) {
            setSelectedIcon({ id: 'temp', name: 'Actual', icon: goal.icon, color: goal.color });
        }
        if (goal.deadline) {
            setDateFromString(goal.deadline);
        }
      }
      setLoading(false);
    };
    fetchGoal();
  }, [user, id]);

  const setDateFromString = (dateStr: string) => {
    const [y, m, d] = dateStr.split('T')[0].split('-');
    setDueDate(new Date(Number(y), Number(m) - 1, Number(d)));
  };

  const handleSave = async () => {
    if (!amount || isNaN(Number(amount))) {
      return Alert.alert('Error', 'Ingresa una meta deseada válida.');
    }
    if (!name.trim()) {
      return Alert.alert('Error', 'Ingresa el nombre de la meta.');
    }

    setSaving(true);
    try {
      const { error } = await supabase.from('savings_goals').update({
        name: name.trim(),
        target_amount: Number(amount),
        deadline: dueDate ? dueDate.toISOString().split('T')[0] : null,
        icon: selectedIcon.icon,
        color: selectedIcon.color,
        account_id: accountId,
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
    Alert.alert('Eliminar Meta', '¿Estás seguro de que quieres cancelar y eliminar esta meta? Se borrará el historial de pagos automatizados.', [
        { text: 'Cancelar', style: 'cancel' },
        { text: 'Eliminar', style: 'destructive', onPress: async () => {
            try {
                await supabase.from('savings_goals').delete().eq('id', id);
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
        <TouchableOpacity style={styles.iconBtn} onPress={() => router.back()}>
          <Text style={styles.iconText}>✕</Text>
        </TouchableOpacity>

        <View style={styles.headerRight}>
          <TouchableOpacity style={styles.headerPill} onPress={() => setShowDatePicker(true)}>
            <Text style={styles.headerPillText}>{formatDateText(dueDate)}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.iconBtn, { width: 44, backgroundColor: '#EF444420', borderWidth: 1, borderColor: '#EF444440' }]} onPress={handleDelete}>
             <HugeiconsIcon icon={Delete01Icon} size={20} color="#EF4444" />
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
          <Text style={styles.sectionLabel}>¿Qué quieres lograr?</Text>
          <View style={styles.inputContainer}>
            <TextInput
              style={styles.textInput}
              placeholder="Ej. Viaje a Japón, Auto nuevo..."
              placeholderTextColor="#71717A"
              value={name}
              onChangeText={setName}
            />
          </View>

          <Text style={[styles.sectionLabel, { marginTop: 12 }]}>¿Dónde reservas este dinero?</Text>
          <TouchableOpacity 
            style={[styles.inputContainer, { paddingVertical: 18 }]} 
            onPress={() => setShowAccountModal(true)}
          >
            <Text style={[styles.textInput, !selectedAccount && { color: '#71717A' }]}>
                {selectedAccount ? selectedAccount.name : 'Ninguna (Opcional)'}
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>

      {/* FIXED BOTTOM ACTIONS */}
      <View style={styles.bottomActions}>
         <TouchableOpacity
          style={[styles.categoryPillBtn, { backgroundColor: selectedIcon.color }]}
          onPress={() => setShowIconModal(true)}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <DynamicIcon name={selectedIcon.icon} size={20} color="#FAFAFA" />
              <Text style={styles.categoryPillBtnText}>{selectedIcon.name}</Text>
          </View>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.saveBtn}
          onPress={handleSave}
          disabled={saving || !amount || amount === '0' || !name.trim()}
        >
          {saving ? <ActivityIndicator color="#09090B" /> : <Text style={styles.saveBtnText}>Guardar Cambios</Text>}
        </TouchableOpacity>
      </View>

      {/* ICON SELECTOR MODAL */}
      <Modal visible={showIconModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowIconModal(false)} />
          <View style={styles.modalContent}>
            <View style={styles.modalHandle} />
            <Text style={styles.modalTitle}>Elige un icono visual</Text>
            <ScrollView contentContainerStyle={styles.categoryGrid}>
              {GOAL_ICONS.map(cat => (
                <TouchableOpacity
                  key={cat.id}
                  style={[styles.modalCatPill, { borderColor: cat.color, borderWidth: selectedIcon.id === cat.id ? 2 : 1 }]}
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
          <View style={[styles.modalContent, { height: 'auto', maxHeight: '60%' }]}>
            <Text style={styles.modalTitle}>Cuenta Vinculada</Text>
            <ScrollView contentContainerStyle={{ paddingBottom: 20 }}>
              <TouchableOpacity
                 style={[styles.modalCatPill, { marginBottom: 10, borderColor: '#3F3F46', borderWidth: accountId === null ? 2 : 1 }]}
                 onPress={() => { setAccountId(null); setShowAccountModal(false); }}
              >
                  <Text style={[styles.modalCatText, { color: '#A1A1AA' }]}>Ninguna (Solo referencial)</Text>
              </TouchableOpacity>
              {accounts.map(acc => (
                <TouchableOpacity
                  key={acc.id}
                  style={[styles.modalCatPill, { marginBottom: 10, borderColor: acc.color, borderWidth: accountId === acc.id ? 2 : 1 }]}
                  onPress={() => { setAccountId(acc.id); setShowAccountModal(false); }}
                >
                  <DynamicIcon name={acc.icon} size={20} color={acc.color} />
                  <Text style={[styles.modalCatText, { color: '#FAFAFA', marginLeft: 8 }]}>{acc.name}</Text>
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

  bottomActions: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 16, paddingBottom: 16 },
  categoryPillBtn: { paddingHorizontal: 18, paddingVertical: 14, borderRadius: 24, justifyContent: 'center' },
  categoryPillBtnText: { color: '#FFFFFF', fontWeight: '600', fontSize: 16 },
  saveBtn: { backgroundColor: '#FAFAFA', paddingHorizontal: 24, paddingVertical: 14, borderRadius: 24, minWidth: 120, alignItems: 'center' },
  saveBtnText: { color: '#000000', fontWeight: '800', fontSize: 16 },

  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'flex-end' },
  modalBackdropClose: { ...StyleSheet.absoluteFillObject },
  modalContent: { backgroundColor: '#121212', borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24, height: '50%' },
  modalHandle: { width: 40, height: 4, backgroundColor: '#3F3F46', borderRadius: 2, alignSelf: 'center', marginBottom: 20 },
  modalTitle: { color: '#A1A1AA', fontSize: 14, fontWeight: '600', marginBottom: 20, textTransform: 'uppercase' },
  categoryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, paddingBottom: 40 },
  modalCatPill: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)' },
  modalCatText: { fontSize: 15, fontWeight: '600' },
});
