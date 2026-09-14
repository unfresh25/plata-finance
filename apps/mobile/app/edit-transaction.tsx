import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView, Modal, ImageBackground } from 'react-native';
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

const CARD_WIDTH = 260;

export default function EditTransactionScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();
  const insets = useSafeAreaInsets();

  const [saving, setSaving] = useState(false);
  const [accounts, setAccounts] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [originalTx, setOriginalTx] = useState<any>(null);

  const [type, setType] = useState<'expense' | 'income'>('expense');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [accountId, setAccountId] = useState<string | null>(null);
  const [categoryId, setCategoryId] = useState<string | null>(null);
  const [date, setDate] = useState(new Date());
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showCategoryModal, setShowCategoryModal] = useState(false);

  useEffect(() => {
    const load = async () => {
      if (!user || !id) return;
      const { data: pData } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (!pData?.household_id) return;

      const [txRes, accsRes, catsRes] = await Promise.all([
        supabase.from('transactions').select('*').eq('id', id).single(),
        supabase.from('accounts').select('*').eq('household_id', pData.household_id),
        supabase.from('categories').select('*').eq('household_id', pData.household_id),
      ]);

      if (txRes.data) {
        setOriginalTx(txRes.data);
        setType(txRes.data.type);
        setAmount(String(txRes.data.amount));
        setDescription(txRes.data.description || '');
        setAccountId(txRes.data.account_id);
        setCategoryId(txRes.data.category_id);
        if (txRes.data.date) setDate(new Date(txRes.data.date + 'T12:00:00'));
      }
      setAccounts(accsRes.data || []);
      setCategories(catsRes.data || []);
    };
    load();
  }, [user, id]);

  const handleSave = async () => {
    if (!amount || isNaN(Number(amount))) { Alert.alert('Error', 'Ingresa un monto válido.'); return; }
    setSaving(true);
    try {
      const { error } = await supabase.from('transactions').update({
        type,
        amount: Number(amount),
        description: description || null,
        account_id: accountId,
        category_id: categoryId,
        date: date.toISOString().split('T')[0],
      }).eq('id', id);
      if (error) throw error;

      // Revert old balance impact and apply new
      if (originalTx && accountId) {
        const oldAccountId = originalTx.account_id;
        const newAccountId = accountId;

        // Ajustes de balance atómicos vía RPC (no read-modify-write).
        if (oldAccountId === newAccountId) {
          const revert = originalTx.type === 'income' ? -originalTx.amount : originalTx.amount;
          const apply = type === 'income' ? Number(amount) : -Number(amount);
          const netChange = revert + apply;
          if (netChange !== 0) {
            await supabase.rpc('apply_account_delta', { p_account_id: oldAccountId, p_delta: netChange });
          }
        } else {
          // Revertir en la cuenta vieja y aplicar en la nueva.
          const revert = originalTx.type === 'income' ? -originalTx.amount : originalTx.amount;
          await supabase.rpc('apply_account_delta', { p_account_id: oldAccountId, p_delta: revert });
          const apply = type === 'income' ? Number(amount) : -Number(amount);
          await supabase.rpc('apply_account_delta', { p_account_id: newAccountId, p_delta: apply });
        }
      }
      router.back();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = () => {
    Alert.alert('Eliminar', '¿Eliminar esta transacción?', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
          try {
            if (originalTx) {
              // Revertir el efecto de la transacción eliminada, de forma atómica.
              const revert = originalTx.type === 'income' ? -originalTx.amount : originalTx.amount;
              await supabase.rpc('apply_account_delta', { p_account_id: originalTx.account_id, p_delta: revert });

              if (originalTx.recurring_id) {
                const { data: recurringEvents } = await supabase
                  .from('recurring_events')
                  .select('id, next_date, frequency')
                  .eq('id', originalTx.recurring_id);
                
                if (recurringEvents && recurringEvents.length > 0) {
                  const ev = recurringEvents[0];
                  const [y, m, d] = ev.next_date.split('T')[0].split('-');
                  const current = new Date(Number(y), Number(m) - 1, Number(d));
                  
                  if (ev.frequency === 'monthly') current.setMonth(current.getMonth() - 1);
                  else if (ev.frequency === 'yearly') current.setFullYear(current.getFullYear() - 1);
                  else if (ev.frequency === 'weekly') current.setDate(current.getDate() - 7);
                  else if (ev.frequency === 'biweekly') current.setDate(current.getDate() - 14);
                  
                  const ny = current.getFullYear();
                  const nm = String(current.getMonth() + 1).padStart(2, '0');
                  const ndd = String(current.getDate()).padStart(2, '0');
                  const newNextDate = `${ny}-${nm}-${ndd}T12:00:00`;
                  
                  await supabase.from('recurring_events').update({ next_date: newNextDate }).eq('id', ev.id);
                } else {
                  Alert.alert('Alerta', 'Se borró el movimiento, pero no pude encontrar tu suscripción "' + originalTx.description + '" para regresarle la fecha.');
                }
              }
            }
            await supabase.from('transactions').delete().eq('id', id);
            router.back();
          } catch (e: any) { Alert.alert('Error', e.message); }
      }},
    ]);
  };

  const filteredCategories = categories.filter(c => c.type === type || c.type === 'both');
  const currentCategory = categories.find(c => c.id === categoryId);
  const fmt = (val: number) => new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', minimumFractionDigits: 0 }).format(val);
  const formatDateText = (d: Date) => {
    const today = new Date();
    if (d.toDateString() === today.toDateString()) return 'Hoy';
    return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' });
  };

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 10), paddingBottom: insets.bottom }]}>

      {/* HEADER */}
      <View style={styles.header}>
        <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.pillBg }]} onPress={() => router.back()}>
          <Text style={[styles.iconText, { color: theme.text }]}>✕</Text>
        </TouchableOpacity>

        <View style={styles.headerRight}>
          <TouchableOpacity style={[styles.headerPill, { backgroundColor: theme.pillBg }]} onPress={() => setShowDatePicker(true)}>
            <Text style={[styles.headerPillText, { color: theme.text }]}>{formatDateText(date)}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.iconBtn, { backgroundColor: theme.pillBg }]} onPress={() => setType(type === 'income' ? 'expense' : 'income')}>
            <Text style={[styles.iconText, { color: theme.text }]}>{type === 'income' ? '↓' : '↑'}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.iconBtn, { backgroundColor: '#EF444420', borderWidth: 1, borderColor: '#EF444440' }]} onPress={handleDelete}>
            <HugeiconsIcon icon={Delete01Icon} size={20} color="#EF4444" />
          </TouchableOpacity>
        </View>
      </View>

      {showDatePicker && (
        <DateTimePicker
          value={date}
          mode="date"
          display="default"
          onChange={(event, selectedDate) => {
            setShowDatePicker(false);
            if (selectedDate) setDate(selectedDate);
          }}
        />
      )}

      <ScrollView contentContainerStyle={styles.contentScroll} showsVerticalScrollIndicator={false}>

        {/* HUGE AMOUNT */}
        <View style={styles.amountContainer}>
          <Text style={[styles.currencySymbol, { color: type === 'income' ? '#22C55E' : theme.text }]}>$</Text>
          <AmountInput
            style={[styles.amountText, { color: type === 'income' ? '#22C55E' : theme.text, minWidth: 100, padding: 0 }]}
            placeholder="0"
            placeholderTextColor={theme.textMuted}
            value={amount}
            onChangeText={setAmount}
            autoFocus
            maxLength={14}
            selectionColor="#2563EB"
          />
        </View>

        {/* DESCRIPTION */}
        <View style={styles.sectionDivider}>
          <Text style={[styles.sectionLabel, { color: theme.textMuted }]}>Nota / Descripción</Text>
          <View style={[styles.inputContainer, { backgroundColor: theme.pillBg }]}>
            <TextInput
              style={[styles.textInput, { color: theme.text }]}
              placeholder="Ej. Tiquete de vuelo, Cena..."
              placeholderTextColor={theme.textMuted}
              value={description}
              onChangeText={setDescription}
            />
          </View>
        </View>

        {/* ACCOUNT CARDS */}
        <View style={styles.detailsSection}>
          <Text style={[styles.sectionLabel, { color: theme.textMuted }]}>Cuenta origen/destino</Text>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.accountsScroll}
            snapToInterval={CARD_WIDTH + 16}
            decelerationRate="fast"
          >
            {accounts.map(acc => {
              const isSelected = acc.id === accountId;
              return (
                <TouchableOpacity
                  key={acc.id}
                  style={[styles.creditCard, { width: CARD_WIDTH, shadowColor: isDark ? '#000' : theme.text, shadowOpacity: isDark ? 0.1 : 0.05, shadowOffset: { width: 0, height: 4 }, shadowRadius: 8, elevation: 4 }, isSelected && styles.creditCardSelected]}
                  onPress={() => setAccountId(acc.id)}
                  activeOpacity={0.8}
                >
                  <ImageBackground
                    source={require('../assets/images/card-bg.png')}
                    style={styles.cardBg}
                    imageStyle={{ borderRadius: 20 }}
                    resizeMode="cover"
                  >
                    <View style={styles.cardOverlay}>
                      <View style={styles.cardTop}>
                        <Text style={styles.cardName}>{acc.name}</Text>
                        <View style={styles.chip}><View style={styles.chipLine} /></View>
                      </View>
                      <View style={styles.cardBottom}>
                        <View>
                          <Text style={styles.cardSub}>{acc.type}</Text>
                          <Text style={styles.cardBalance}>{fmt(acc.balance)}</Text>
                        </View>
                        <View style={styles.mcLogo}>
                          <View style={[styles.mcCircle, { backgroundColor: '#EF4444', marginRight: -12 }]} />
                          <View style={[styles.mcCircle, { backgroundColor: '#F59E0B' }]} />
                        </View>
                      </View>
                    </View>
                  </ImageBackground>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>
      </ScrollView>

      {/* FIXED BOTTOM ACTIONS */}
      <View style={styles.bottomActions}>
        <TouchableOpacity
          style={[styles.categoryPillBtn, currentCategory ? { backgroundColor: currentCategory.color } : { backgroundColor: theme.pillBg }, { flexDirection: 'row', alignItems: 'center', gap: 8 }]}
          onPress={() => setShowCategoryModal(true)}
        >
          <DynamicIcon name={currentCategory?.icon} size={20} color="#FAFAFA" />
          <Text style={[styles.categoryPillBtnText, !currentCategory && { color: theme.text }]}>
            {currentCategory ? currentCategory.name : 'Categoría'}
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

      {/* CATEGORY SELECTOR MODAL */}
      <Modal visible={showCategoryModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowCategoryModal(false)} />
          <View style={[styles.modalContent, { backgroundColor: theme.card }]}>
            <View style={[styles.modalHandle, { backgroundColor: theme.border }]} />
            <View style={styles.modalHeader}>
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
                  onPress={() => { setCategoryId(cat.id); setShowCategoryModal(false); }}
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
  headerRight: { flexDirection: 'row', gap: 10, alignItems: 'center' },
  headerPill: { paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20 },
  headerPillText: { fontWeight: '600', fontSize: 15 },

  contentScroll: { paddingHorizontal: 20, paddingBottom: 20 },

  amountContainer: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 140, marginBottom: 10 },
  currencySymbol: { fontSize: 44, fontWeight: '700', marginRight: 4, marginTop: 10 },
  amountText: { fontSize: 72, fontWeight: '800', fontVariant: ['tabular-nums'], flexShrink: 1, letterSpacing: -2 },

  sectionDivider: { marginBottom: 24 },
  sectionLabel: { fontSize: 13, fontWeight: '500', marginBottom: 12, marginLeft: 4 },

  inputContainer: { borderRadius: 16, paddingHorizontal: 18, paddingVertical: 16 },
  textInput: { fontSize: 17, letterSpacing: 0 },

  detailsSection: { gap: 12 },
  accountsScroll: { gap: 16, paddingRight: 20, paddingBottom: 10 },
  creditCard: { height: 150, borderRadius: 20, borderWidth: 2, borderColor: 'transparent' },
  creditCardSelected: { borderColor: '#3B82F6' },
  cardBg: { flex: 1, width: '100%', height: '100%' },
  cardOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.3)', padding: 18, justifyContent: 'space-between', borderRadius: 20 },
  cardTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  cardName: { color: '#FFF', fontSize: 16, fontWeight: '600', letterSpacing: 0.5 },
  chip: { width: 34, height: 24, backgroundColor: '#D4AF37', borderRadius: 6, overflow: 'hidden', justifyContent: 'center' },
  chipLine: { width: '100%', height: 1, backgroundColor: 'rgba(0,0,0,0.2)' },
  cardBottom: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  cardSub: { color: '#E4E4E7', fontSize: 12, fontWeight: '500', opacity: 0.8 },
  cardBalance: { color: '#FFF', fontSize: 20, fontWeight: '800', fontVariant: ['tabular-nums'] },
  mcLogo: { flexDirection: 'row', alignItems: 'center' },
  mcCircle: { width: 24, height: 24, borderRadius: 12, opacity: 0.9 },

  bottomActions: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 16, paddingBottom: 16 },
  categoryPillBtn: { paddingHorizontal: 18, paddingVertical: 14, borderRadius: 24 },
  categoryPillBtnText: { color: '#FFFFFF', fontWeight: '600', fontSize: 16 },
  saveBtn: { paddingHorizontal: 28, paddingVertical: 14, borderRadius: 24 },
  saveBtnText: { fontWeight: '800', fontSize: 16 },

  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'flex-end' },
  modalBackdropClose: { ...StyleSheet.absoluteFillObject },
  modalContent: { borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24, height: '50%' },
  modalHandle: { width: 40, height: 4, borderRadius: 2, alignSelf: 'center', marginBottom: 20 },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 },
  modalTitle: { fontSize: 18, fontWeight: '700' },
  modalCloseBtn: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center' },
  modalCloseText: { fontSize: 16, fontWeight: '700' },
  categoryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, paddingBottom: 40 },
  modalCatPill: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1 },
  modalCatIcon: { fontSize: 18, marginRight: 8 },
  modalCatText: { fontSize: 15, fontWeight: '600' },
  emptyText: { fontSize: 15 },
});
