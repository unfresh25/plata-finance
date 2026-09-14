import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, Pressable, Animated, PanResponder, Dimensions, ActivityIndicator, TextInput, Keyboard, ScrollView } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { formatCurrency, formatShortDate } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Cancel01Icon, Calendar01Icon, MoreHorizontalIcon, Edit02Icon, Delete01Icon, UserIcon } from '@hugeicons/core-free-icons';
import { useAuth } from '../../src/context/AuthContext';
import { useTheme } from '../../src/context/ThemeContext';
import AmountInput from '../../src/components/AmountInput';
import DynamicIcon from '../../src/components/DynamicIcon';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const SHEET_MAX_HEIGHT = SCREEN_HEIGHT * 0.85;
const SHEET_MIN_HEIGHT = SCREEN_HEIGHT * 0.55;

export default function DebtDetailScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();

  const [loading, setLoading] = useState(true);
  const [confirming, setConfirming] = useState(false);
  const [debt, setDebt] = useState<any>(null);
  const [accounts, setAccounts] = useState<any[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState<string | null>(null);
  const [currency, setCurrency] = useState('USD');
  const [showMenu, setShowMenu] = useState(false);
  
  // Custom amount to pay for this interaction
  const [payAmountStr, setPayAmountStr] = useState('');

  // Animation values
  const [isExpanded, setIsExpanded] = useState(false);
  const START_OFFSET = SHEET_MAX_HEIGHT - SHEET_MIN_HEIGHT;
  const panY = useRef(new Animated.Value(SCREEN_HEIGHT)).current;
  const overlayOpacity = useRef(new Animated.Value(0)).current;

  let lastPanY = START_OFFSET;
  panY.addListener(({ value }) => { lastPanY = value; });

  useEffect(() => {
    // Mount animation
    Animated.parallel([
      Animated.timing(overlayOpacity, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }),
      Animated.spring(panY, {
        toValue: START_OFFSET,
        useNativeDriver: true,
        bounciness: 0,
      })
    ]).start();

    const fetchDetail = async () => {
      if (!id || !user) return;
      try {
        const { data: pData } = await supabase.from('profiles').select('currency').eq('id', user.id).single();
        if (pData?.currency) setCurrency(pData.currency);

        const { data, error } = await supabase
          .from('debts')
          .select(`*, categories (name, icon, color)`)
          .eq('id', id)
          .single();

        if (error) throw error;
        setDebt(data);
        const remaining = (data.amount || 0) - (data.amount_paid || 0);
        setPayAmountStr(remaining > 0 ? remaining.toString() : '');

        const { data: accs } = await supabase.from('accounts').select('id, name, type, color, icon, balance').eq('household_id', data.household_id);
        if (accs) {
          setAccounts(accs);
          setSelectedAccountId(accs[0]?.id);
        }
      } catch (err) {
        Alert.alert('Error', 'No se pudo cargar la deuda');
      } finally {
        setLoading(false);
      }
    };
    fetchDetail();
  }, [id, user]);

  const closeSheet = () => {
    Animated.parallel([
      Animated.timing(overlayOpacity, {
        toValue: 0,
        duration: 200,
        useNativeDriver: true,
      }),
      Animated.timing(panY, {
        toValue: SCREEN_HEIGHT,
        duration: 200,
        useNativeDriver: true,
      })
    ]).start(() => {
      router.back();
    });
  };

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: (e, gs) => Math.abs(gs.dy) > 10,
      onPanResponderGrant: () => {
        panY.setOffset(lastPanY);
        panY.setValue(0);
      },
      onPanResponderMove: (e, gs) => {
        if (lastPanY + gs.dy < 0) {
          panY.setValue(-lastPanY);
        } else {
          panY.setValue(gs.dy);
        }
      },
      onPanResponderRelease: (e, gs) => {
        panY.flattenOffset();
        const velocity = gs.vy;

        // Si fue solo un tap (sin movimiento), ocultamos el teclado
        if (Math.abs(gs.dx) < 5 && Math.abs(gs.dy) < 5) {
          Keyboard.dismiss();
        }

        if (velocity > 1.5 || lastPanY > START_OFFSET + 100) {
          closeSheet();
          return;
        }

        let snapPoint = START_OFFSET;
        if (velocity < -0.5 || lastPanY < START_OFFSET / 2) {
          snapPoint = 0;
          setIsExpanded(true);
        } else {
          setIsExpanded(false);
        }

        Animated.spring(panY, {
          toValue: snapPoint,
          useNativeDriver: true,
          bounciness: 0,
        }).start();
      },
    })
  ).current;

  const handleEdit = () => {
    setShowMenu(false);
    router.back();
    setTimeout(() => router.push(`/edit-debt?id=${debt.id}` as any), 100);
  };

  const handleDelete = () => {
    setShowMenu(false);
    Alert.alert('Eliminar Deuda', '¿Estás seguro de eliminar esta deuda?', [
      { text: 'Cancelar', style: 'cancel' },
      {
        text: 'Eliminar', style: 'destructive', onPress: async () => {
          try {
            setLoading(true);
            await supabase.from('debts').delete().eq('id', debt.id);
            closeSheet();
          } catch (e: any) {
            Alert.alert('Error', e.message);
            setLoading(false);
          }
        }
      }
    ]);
  };

  const handleConfirmPayment = async () => {
    if (!payAmountStr || isNaN(Number(payAmountStr)) || Number(payAmountStr) <= 0) {
      Alert.alert('Error', 'Ingresa un monto de abono válido.');
      return;
    }
    const paymentAmount = Number(payAmountStr);

    try {
      setConfirming(true);
      if (!selectedAccountId) {
        Alert.alert('Error', 'Selecciona una cuenta para la transacción.');
        return;
      }
      
      const account = accounts.find(a => a.id === selectedAccountId);
      if (!account) return;
      
      const txType = debt.direction === 'owed_to_us' ? 'income' : 'expense';

      // Record transaction
      await supabase.from('transactions').insert({
        household_id: debt.household_id,
        account_id: account.id,
        category_id: debt.category_id, 
        debt_id: debt.id,
        amount: paymentAmount,
        type: txType,
        description: `Abono: ${debt.description || debt.person_name}`,
        date: new Date().toISOString().split('T')[0],
        created_by: user?.id
      });
      
      // Update balance
      const balanceChange = txType === 'income' ? paymentAmount : -paymentAmount;
      await supabase.from('accounts').update({ balance: account.balance + balanceChange }).eq('id', account.id);

      // Record specifically in debt bindings
      const newPaid = (debt.amount_paid || 0) + paymentAmount;
      const isPaid = newPaid >= debt.amount;
      
      await supabase.from('debt_payments').insert({ debt_id: debt.id, amount: paymentAmount, date: new Date().toISOString().split('T')[0] });
      await supabase.from('debts').update({ amount_paid: newPaid, status: isPaid ? 'paid' : 'active' }).eq('id', debt.id);

      // If there's an associated recurring_event tracking this debt, and it's paid off, deactivate it.
      if (isPaid) {
          await supabase.from('recurring_events').update({ is_active: false }).eq('debt_id', debt.id);
      }

      Alert.alert('Éxito', 'Abono registrado correctamente.');
      closeSheet();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      if (confirming) setConfirming(false);
    }
  };

  if (!debt && !loading) {
    return (
      <View style={styles.modalBg}>
        <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: isDark ? 'rgba(0,0,0,0.6)' : 'rgba(0,0,0,0.3)', opacity: overlayOpacity }]} />
        <Animated.View style={[styles.sheetContainer, { backgroundColor: theme.card, transform: [{ translateY: panY }] }]}>
          <View style={styles.center}><Text style={{ color: theme.text }}>Deuda no encontrada</Text></View>
        </Animated.View>
      </View>
    );
  }

  const isOwed = debt?.direction === 'owed_to_us';
  const remaining = (debt?.amount || 0) - (debt?.amount_paid || 0);

  return (
    <View style={styles.modalBg}>
      <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: isDark ? 'rgba(0,0,0,0.6)' : 'rgba(0,0,0,0.3)', opacity: overlayOpacity }]}>
        <Pressable style={StyleSheet.absoluteFillObject} onPress={closeSheet} />
      </Animated.View>

      <Animated.View
        style={[styles.sheetContainer, { backgroundColor: theme.card, transform: [{ translateY: panY }] }]}
        {...panResponder.panHandlers}
      >
        <View style={styles.handleArea}>
          <View style={[styles.sheetHandle, { backgroundColor: theme.border }]} />
        </View>

        <View style={styles.headerRow}>
          <TouchableOpacity onPress={closeSheet} style={[styles.iconBtn, { backgroundColor: theme.pillBg }]}>
            <HugeiconsIcon icon={Cancel01Icon} size={24} color={theme.text} />
          </TouchableOpacity>
          <View>
            <TouchableOpacity onPress={() => setShowMenu(v => !v)} style={[styles.iconBtn, { backgroundColor: theme.pillBg }]}>
              <HugeiconsIcon icon={MoreHorizontalIcon} size={24} color={theme.text} />
            </TouchableOpacity>
            {showMenu && (
              <>
                <Pressable style={styles.dropdownOverlay} onPress={() => setShowMenu(false)} />
                <View style={[styles.dropdown, { backgroundColor: theme.card, borderColor: theme.border, top: 40 }]}>
                  <TouchableOpacity style={styles.dropdownItem} onPress={handleEdit}>
                    <HugeiconsIcon icon={Edit02Icon} size={18} color={theme.text} />
                    <Text style={[styles.dropdownText, { color: theme.text }]}>Editar</Text>
                  </TouchableOpacity>
                  <View style={[styles.dropdownDivider, { backgroundColor: theme.border }]} />
                  <TouchableOpacity style={styles.dropdownItem} onPress={handleDelete}>
                    <HugeiconsIcon icon={Delete01Icon} size={18} color={theme.danger} />
                    <Text style={[styles.dropdownText, { color: theme.danger }]}>Eliminar</Text>
                  </TouchableOpacity>
                </View>
              </>
            )}
          </View>
        </View>

        {debt && (
          <View style={styles.content}>
            <View style={styles.cardHeader}>
              <View style={[styles.avatar, { backgroundColor: debt?.categories?.color || theme.pillBg, borderColor: theme.border }]}>
                {debt?.categories ? (
                  <DynamicIcon name={debt.categories.icon} size={16} color={theme.background} />
                ) : (
                  <HugeiconsIcon icon={UserIcon} size={24} color={theme.text} />
                )}
              </View>
              <View>
                <Text style={[styles.cardTitle, { color: theme.text }]}>{debt.person_name}</Text>
                <Text style={[styles.cardSubtitle, { color: theme.textMuted }]}>{debt.description || 'Deuda'}</Text>
              </View>
            </View>

            <Text style={styles.sentence}>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>{isOwed ? 'Nos deben ' : 'Debemos '} </Text>
              <Text style={[styles.boldText, isOwed ? { color: '#22C55E' } : { color: theme.danger }]}>{formatCurrency(remaining, currency)}</Text>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>{debt.due_date ? ` para pagar antes de ` : '.'}</Text>
              {debt.due_date && <Text style={[styles.boldText, { color: theme.text }]}>{formatShortDate(debt.due_date)}</Text>}
            </Text>

            <View style={styles.pillsContainer}>
              <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                <Text style={[styles.pillText, { color: theme.text }]}>Total: {formatCurrency(debt.amount, currency)}</Text>
              </View>
              <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                <Text style={[styles.pillText, { color: theme.text }]}>Pagado: {formatCurrency(debt.amount_paid, currency)}</Text>
              </View>
              {debt.categories && (
                <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                  <DynamicIcon name={debt.categories.icon} size={15} color={debt.categories.color} />
                  <Text style={[styles.pillText, { color: theme.text }]}>{debt.categories.name}</Text>
                </View>
              )}
            </View>

            <View style={[styles.actionBlock, { backgroundColor: isDark ? 'rgba(255,255,255,0.02)' : theme.pillBg, borderColor: theme.border }]}>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>¿Cuánto deseas abonar?</Text>
              <View style={styles.inputContainer}>
                <Text style={[styles.currencyFlag, { color: theme.textMuted }]}>$</Text>
                <AmountInput
                    style={[styles.payInput, { color: theme.text }]}
                    value={payAmountStr}
                    onChangeText={setPayAmountStr}
                    placeholder="0"
                    placeholderTextColor={theme.textMuted}
                />
              </View>
            </View>

            <View style={{ marginTop: 20 }}>
              <Text style={[styles.grayText, { color: theme.textMuted, marginBottom: 12, fontSize: 14 }]}>Cuenta involucrada</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 12, paddingRight: 20 }}>
                {accounts.map(acc => {
                  const isSelected = selectedAccountId === acc.id;
                  return (
                    <TouchableOpacity
                      key={acc.id}
                      style={[styles.accountPill, { borderColor: isSelected ? (acc.color || theme.primary) : theme.border, backgroundColor: isSelected ? `${acc.color || '#3B82F6'}15` : theme.pillBg }]}
                      onPress={() => setSelectedAccountId(acc.id)}
                    >
                      <Text style={{ fontSize: 16 }}>{acc.icon}</Text>
                      <Text style={[styles.accountPillText, { color: isSelected ? (acc.color || theme.text) : theme.text }]}>{acc.name}</Text>
                    </TouchableOpacity>
                  )
                })}
              </ScrollView>
            </View>

            <TouchableOpacity  
              style={{ marginTop: 24, backgroundColor: isOwed ? '#22C55E' : theme.danger, paddingVertical: 16, borderRadius: 24, alignItems: 'center' }}
              onPress={handleConfirmPayment}
              disabled={confirming}
            >
               {confirming ? <ActivityIndicator color="#FFF" /> : <Text style={{ color: '#FFF', fontWeight: 'bold', fontSize: 16 }}>Abonar</Text>}
            </TouchableOpacity>
          </View>
        )}
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  modalBg: { flex: 1, backgroundColor: 'transparent', justifyContent: 'flex-end' },
  sheetContainer: { height: SHEET_MAX_HEIGHT, borderTopLeftRadius: 24, borderTopRightRadius: 24 },
  handleArea: { width: '100%', height: 30, alignItems: 'center', justifyContent: 'flex-end' },
  sheetHandle: { width: 40, height: 4, borderRadius: 2, marginBottom: 10 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20 },
  iconBtn: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderRadius: 22 },
  dropdownOverlay: { position: 'absolute', top: -50, right: -50, bottom: -500, left: -500, zIndex: 90 },
  dropdown: { position: 'absolute', right: 20, borderRadius: 14, borderWidth: 1, minWidth: 160, zIndex: 100, shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.1, shadowRadius: 12 },
  dropdownItem: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 16, paddingVertical: 14 },
  dropdownText: { fontSize: 16, fontWeight: '600' },
  dropdownDivider: { height: 1 },

  content: { padding: 24, paddingTop: 32 },
  cardHeader: { flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 24 },
  avatar: { width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center', borderWidth: 1 },
  cardTitle: { fontSize: 24, fontWeight: '700' },
  cardSubtitle: { fontSize: 15, marginTop: 2, fontWeight: '500' },

  sentence: { fontSize: 30, lineHeight: 40, letterSpacing: -0.5, marginBottom: 32 },
  grayText: { fontSize: 16 },
  boldText: { fontWeight: '700' },

  pillsContainer: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, marginBottom: 24 },
  pill: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1 },
  pillText: { fontSize: 13, fontWeight: '600' },

  accountPill: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1 },
  accountPillText: { fontSize: 15, fontWeight: '600' },

  actionBlock: { padding: 16, borderRadius: 20, borderWidth: 1 },
  inputContainer: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  currencyFlag: { fontSize: 32, fontWeight: '500', marginRight: 4, marginTop: 4 },
  payInput: { fontSize: 40, fontWeight: '800', fontVariant: ['tabular-nums'], flexShrink: 1 },
});
