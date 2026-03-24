import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, Pressable, Animated, PanResponder, Dimensions, ActivityIndicator, TextInput, Keyboard } from 'react-native';
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

  const [loading, setLoading] = useState(true);
  const [confirming, setConfirming] = useState(false);
  const [debt, setDebt] = useState<any>(null);
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
      const { data: accounts } = await supabase.from('accounts').select('id, balance').eq('household_id', debt.household_id).limit(1);
      if (!accounts || accounts.length === 0) {
        Alert.alert('Error', 'No tienes cuentas creadas para descontar / recibir el dinero.');
        return;
      }
      
      const account = accounts[0];
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
        <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.6)', opacity: overlayOpacity }]} />
        <Animated.View style={[styles.sheetContainer, { transform: [{ translateY: panY }] }]}>
          <View style={styles.center}><Text style={{ color: '#FAFAFA' }}>Deuda no encontrada</Text></View>
        </Animated.View>
      </View>
    );
  }

  const isOwed = debt?.direction === 'owed_to_us';
  const remaining = (debt?.amount || 0) - (debt?.amount_paid || 0);

  return (
    <View style={styles.modalBg}>
      <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.6)', opacity: overlayOpacity }]}>
        <Pressable style={StyleSheet.absoluteFillObject} onPress={closeSheet} />
      </Animated.View>

      <Animated.View
        style={[styles.sheetContainer, { transform: [{ translateY: panY }] }]}
        {...panResponder.panHandlers}
      >
        <View style={styles.handleArea}>
          <View style={styles.sheetHandle} />
        </View>

        <View style={styles.headerRow}>
          <TouchableOpacity onPress={closeSheet} style={styles.iconBtn}>
            <HugeiconsIcon icon={Cancel01Icon} size={24} color="#FAFAFA" />
          </TouchableOpacity>
          <View>
            <TouchableOpacity onPress={() => setShowMenu(v => !v)} style={styles.iconBtn}>
              <HugeiconsIcon icon={MoreHorizontalIcon} size={24} color="#FAFAFA" />
            </TouchableOpacity>
            {showMenu && (
              <>
                <Pressable style={styles.dropdownOverlay} onPress={() => setShowMenu(false)} />
                <View style={[styles.dropdown, { top: 40 }]}>
                  <TouchableOpacity style={styles.dropdownItem} onPress={handleEdit}>
                    <HugeiconsIcon icon={Edit02Icon} size={18} color="#FAFAFA" />
                    <Text style={styles.dropdownText}>Editar</Text>
                  </TouchableOpacity>
                  <View style={styles.dropdownDivider} />
                  <TouchableOpacity style={styles.dropdownItem} onPress={handleDelete}>
                    <HugeiconsIcon icon={Delete01Icon} size={18} color="#EF4444" />
                    <Text style={[styles.dropdownText, { color: '#EF4444' }]}>Eliminar</Text>
                  </TouchableOpacity>
                </View>
              </>
            )}
          </View>
        </View>

        {debt && (
          <View style={styles.content}>
            <View style={styles.cardHeader}>
              <View style={[styles.avatar, { backgroundColor: debt?.categories?.color || '#18181B' }]}>
                {debt?.categories ? (
                  <DynamicIcon name={debt.categories.icon} size={16} color="#FAFAFA" />
                ) : (
                  <HugeiconsIcon icon={UserIcon} size={24} color="#FAFAFA" />
                )}
              </View>
              <View>
                <Text style={styles.cardTitle}>{debt.person_name}</Text>
                <Text style={styles.cardSubtitle}>{debt.description || 'Deuda'}</Text>
              </View>
            </View>

            <Text style={styles.sentence}>
              <Text style={styles.grayText}>{isOwed ? 'Nos deben ' : 'Debemos '} </Text>
              <Text style={[styles.boldText, isOwed ? { color: '#22C55E' } : { color: '#EF4444' }]}>{formatCurrency(remaining, currency)}</Text>
              <Text style={styles.grayText}>{debt.due_date ? ` para pagar antes de ` : '.'}</Text>
              {debt.due_date && <Text style={styles.boldText}>{formatShortDate(debt.due_date)}</Text>}
            </Text>

            <View style={styles.pillsContainer}>
              <View style={styles.pill}>
                <Text style={styles.pillText}>Total: {formatCurrency(debt.amount, currency)}</Text>
              </View>
              <View style={styles.pill}>
                <Text style={styles.pillText}>Pagado: {formatCurrency(debt.amount_paid, currency)}</Text>
              </View>
              {debt.categories && (
                <View style={styles.pill}>
                  <DynamicIcon name={debt.categories.icon} size={15} color={debt.categories.color} />
                  <Text style={styles.pillText}>{debt.categories.name}</Text>
                </View>
              )}
            </View>

            <View style={styles.actionBlock}>
              <Text style={styles.grayText}>¿Cuánto deseas abonar?</Text>
              <View style={styles.inputContainer}>
                <Text style={styles.currencyFlag}>$</Text>
                <AmountInput
                    style={styles.payInput}
                    value={payAmountStr}
                    onChangeText={setPayAmountStr}
                    placeholder="0"
                    placeholderTextColor="#71717A"
                />
              </View>
            </View>

            <TouchableOpacity 
              style={{ marginTop: 24, backgroundColor: isOwed ? '#22C55E' : '#EF4444', paddingVertical: 16, borderRadius: 24, alignItems: 'center' }}
              onPress={handleConfirmPayment}
              disabled={confirming}
            >
               {confirming ? <ActivityIndicator color="#FFF" /> : <Text style={{ color: isOwed ? '#000' : '#FFF', fontWeight: 'bold', fontSize: 16 }}>Abonar</Text>}
            </TouchableOpacity>
          </View>
        )}
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  modalBg: { flex: 1, backgroundColor: 'transparent', justifyContent: 'flex-end' },
  sheetContainer: { backgroundColor: '#09090B', height: SHEET_MAX_HEIGHT, borderTopLeftRadius: 24, borderTopRightRadius: 24 },
  handleArea: { width: '100%', height: 30, alignItems: 'center', justifyContent: 'flex-end' },
  sheetHandle: { width: 40, height: 4, backgroundColor: '#3F3F46', borderRadius: 2, marginBottom: 10 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20 },
  iconBtn: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', backgroundColor: '#18181B', borderRadius: 22 },
  dropdownOverlay: { position: 'absolute', top: -50, right: -50, bottom: -500, left: -500, zIndex: 90 },
  dropdown: { position: 'absolute', right: 20, backgroundColor: '#18181B', borderRadius: 14, borderWidth: 1, borderColor: '#27272A', minWidth: 160, zIndex: 100, shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.4, shadowRadius: 12 },
  dropdownItem: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 16, paddingVertical: 14 },
  dropdownText: { fontSize: 16, fontWeight: '600', color: '#FAFAFA' },
  dropdownDivider: { height: 1, backgroundColor: '#27272A' },

  content: { padding: 24, paddingTop: 32 },
  cardHeader: { flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 24 },
  avatar: { width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center', backgroundColor: '#18181B', borderWidth: 1, borderColor: '#27272A' },
  cardTitle: { fontSize: 24, fontWeight: '700', color: '#FAFAFA' },
  cardSubtitle: { fontSize: 15, color: '#A1A1AA', marginTop: 2, fontWeight: '500' },

  sentence: { fontSize: 30, lineHeight: 40, letterSpacing: -0.5, marginBottom: 32 },
  grayText: { color: '#A1A1AA', fontSize: 16 },
  boldText: { fontWeight: '700', color: '#FAFAFA' },

  pillsContainer: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, marginBottom: 32 },
  pill: { flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: 'rgba(255,255,255,0.05)', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)' },
  pillText: { color: '#E4E4E7', fontSize: 13, fontWeight: '600' },

  actionBlock: { backgroundColor: 'rgba(255,255,255,0.02)', padding: 16, borderRadius: 20, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)' },
  inputContainer: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  currencyFlag: { fontSize: 32, color: '#A1A1AA', fontWeight: '500', marginRight: 4, marginTop: 4 },
  payInput: { fontSize: 40, fontWeight: '800', color: '#FAFAFA', fontVariant: ['tabular-nums'], minWidth: 150 },
});
