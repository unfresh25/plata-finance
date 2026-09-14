import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, Pressable, Animated, PanResponder, Dimensions, ActivityIndicator, TextInput, Keyboard } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { formatCurrency, formatShortDate } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Cancel01Icon, MoreHorizontalIcon, Edit02Icon, Delete01Icon, Target01Icon } from '@hugeicons/core-free-icons';
import { useAuth } from '../../src/context/AuthContext';
import { useTheme } from '../../src/context/ThemeContext';
import DynamicIcon from '../../src/components/DynamicIcon';
import AmountInput from '../../src/components/AmountInput';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const SHEET_MAX_HEIGHT = SCREEN_HEIGHT * 0.85;
const SHEET_MIN_HEIGHT = SCREEN_HEIGHT * 0.55;

export default function GoalDetailScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();

  const [loading, setLoading] = useState(true);
  const [confirming, setConfirming] = useState(false);
  const [goal, setGoal] = useState<any>(null);
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
          .from('savings_goals')
          .select(`*`)
          .eq('id', id)
          .single();

        if (error) throw error;
        setGoal(data);
      } catch (err) {
        Alert.alert('Error', 'No se pudo cargar la meta de ahorro');
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
    setTimeout(() => router.push(`/edit-savings-goal?id=${goal.id}` as any), 100);
  };

  const handleDelete = () => {
    setShowMenu(false);
    Alert.alert('Eliminar Meta', '¿Estás seguro de cancelar esta meta?', [
      { text: 'Cancelar', style: 'cancel' },
      {
        text: 'Eliminar', style: 'destructive', onPress: async () => {
          try {
            setLoading(true);
            await supabase.from('savings_goals').delete().eq('id', goal.id);
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
      Alert.alert('Error', 'Ingresa un monto de aporte válido.');
      return;
    }
    const paymentAmount = Number(payAmountStr);

    try {
      setConfirming(true);
      
      let workAccountId = goal.account_id;
      if (!workAccountId) {
         const { data: accounts } = await supabase.from('accounts').select('id, balance').eq('household_id', goal.household_id).limit(1);
         if (accounts && accounts.length > 0) workAccountId = accounts[0].id;
         if (!workAccountId) {
            Alert.alert('Error', 'No tienes cuentas para descontar el dinero.'); return;
         }
      }

      // Record transaction
      await supabase.from('transactions').insert({
        household_id: goal.household_id,
        account_id: workAccountId,
        savings_goal_id: goal.id,
        amount: paymentAmount,
        type: 'expense',
        description: `Aporte a meta: ${goal.name}`,
        date: new Date().toISOString().split('T')[0],
        created_by: user?.id
      });
      
      // Update balance
      const { data: acc } = await supabase.from('accounts').select('balance').eq('id', workAccountId).single();
      if (acc) {
          await supabase.from('accounts').update({ balance: acc.balance - paymentAmount }).eq('id', workAccountId);
      }

      // Update goal
      const newCurrent = (goal.current_amount || 0) + paymentAmount;
      const isCompleted = newCurrent >= goal.target_amount;
      
      await supabase.from('savings_contributions').insert({ goal_id: goal.id, amount: paymentAmount, created_by: user?.id, date: new Date().toISOString().split('T')[0] });
      await supabase.from('savings_goals').update({ current_amount: newCurrent, status: isCompleted ? 'completed' : 'active' }).eq('id', goal.id);

      // If there's an associated recurring_event tracking this goal, and it's met, deactivate it.
      if (isCompleted) {
          await supabase.from('recurring_events').update({ is_active: false }).eq('savings_goal_id', goal.id);
      }

      Alert.alert('Éxito', 'Aporte registrado correctamente.');
      closeSheet();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      if (confirming) setConfirming(false);
    }
  };

  if (!goal && !loading) {
    return (
      <View style={styles.modalBg}>
        <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: isDark ? 'rgba(0,0,0,0.6)' : 'rgba(0,0,0,0.3)', opacity: overlayOpacity }]} />
        <Animated.View style={[styles.sheetContainer, { backgroundColor: theme.card, transform: [{ translateY: panY }] }]}>
          <View style={styles.center}><Text style={{ color: theme.text }}>Meta no encontrada</Text></View>
        </Animated.View>
      </View>
    );
  }

  const remaining = Math.max(0, (goal?.target_amount || 0) - (goal?.current_amount || 0));
  const progressNum = goal?.target_amount > 0 ? (goal?.current_amount || 0) / goal?.target_amount : 0;
  const progressPct = Math.min(progressNum * 100, 100);

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

        {goal && (
          <View style={styles.content}>
            <View style={styles.cardHeader}>
              <View style={[styles.avatar, { backgroundColor: goal.color || theme.pillBg, borderColor: theme.border }]}>
                {goal.icon ? (
                  <DynamicIcon name={goal.icon} size={20} color={theme.background} />
                ) : (
                  <HugeiconsIcon icon={Target01Icon} size={24} color={theme.text} />
                )}
              </View>
              <View>
                <Text style={[styles.cardTitle, { color: theme.text }]}>{goal.name}</Text>
                <Text style={[styles.cardSubtitle, { color: theme.textMuted }]}>Meta de Ahorro</Text>
              </View>
            </View>

            <Text style={styles.sentence}>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>Faltan </Text>
              <Text style={[styles.boldText, { color: goal.color }]}>{formatCurrency(remaining, currency)}</Text>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>{goal.deadline ? ` para ` : '.'}</Text>
              {goal.deadline && <Text style={[styles.boldText, { color: theme.text }]}>{formatShortDate(goal.deadline)}</Text>}
            </Text>

            <View style={{ marginBottom: 32 }}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 }}>
                    <Text style={{ color: theme.text, fontWeight: '600', fontSize: 13 }}>{progressPct.toFixed(1)}% Alcanzado</Text>
                    <Text style={{ color: theme.textMuted, fontSize: 13, fontVariant: ['tabular-nums'] }}>{formatCurrency(goal.current_amount, currency)} / {formatCurrency(goal.target_amount, currency)}</Text>
                </View>
                <View style={{ height: 12, backgroundColor: theme.border, borderRadius: 6, width: '100%', overflow: 'hidden' }}>
                    <View style={{ height: '100%', backgroundColor: goal.color, width: `${progressPct}%`, borderRadius: 6 }} />
                </View>
            </View>

            <View style={[styles.actionBlock, { backgroundColor: isDark ? 'rgba(255,255,255,0.02)' : theme.pillBg, borderColor: theme.border }]}>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>¿Cuánto deseas aportar hoy?</Text>
              <View style={styles.inputContainer}>
                <Text style={[styles.currencyFlag, { color: goal.color }]}>$</Text>
                <AmountInput
                    style={[styles.payInput, { color: goal.color }]}
                    value={payAmountStr}
                    onChangeText={setPayAmountStr}
                    placeholder="0"
                    placeholderTextColor={theme.textMuted}
                    selectionColor={goal.color}
                />
              </View>
            </View>

            <TouchableOpacity 
              style={{ marginTop: 24, backgroundColor: goal.color, paddingVertical: 16, borderRadius: 24, alignItems: 'center' }}
              onPress={handleConfirmPayment}
              disabled={confirming}
            >
               {confirming ? <ActivityIndicator color="#000" /> : <Text style={{ color: '#000', fontWeight: 'bold', fontSize: 16 }}>Confirmar Aporte</Text>}
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
  dropdown: { position: 'absolute', right: 20, borderRadius: 14, borderWidth: 1, minWidth: 160, zIndex: 100, shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.4, shadowRadius: 12 },
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

  pillsContainer: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, marginBottom: 32 },
  pill: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1 },
  pillText: { fontSize: 13, fontWeight: '600' },

  actionBlock: { padding: 16, borderRadius: 20, borderWidth: 1 },
  inputContainer: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  currencyFlag: { fontSize: 32, fontWeight: '500', marginRight: 4, marginTop: 4 },
  payInput: { fontSize: 40, fontWeight: '800', fontVariant: ['tabular-nums'], flexShrink: 1 },
});
