import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, Pressable, Animated, PanResponder, Dimensions } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { formatCurrency, formatShortDate } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Cancel01Icon, Calendar01Icon, Folder01Icon, Wallet01Icon, MoreHorizontalIcon, Edit02Icon, Delete01Icon } from '@hugeicons/core-free-icons';
import { useAuth } from '../../src/context/AuthContext';
import { useTheme } from '../../src/context/ThemeContext';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const SHEET_MAX_HEIGHT = SCREEN_HEIGHT * 0.85;
const SHEET_MIN_HEIGHT = SCREEN_HEIGHT * 0.5;

export default function TransactionDetailScreen() {
  const { id, txData } = useLocalSearchParams();
  const router = useRouter();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();

  const [loading, setLoading] = useState(true);
  const [tx, setTx] = useState<any>(null);
  const [currency, setCurrency] = useState('USD');
  const [showMenu, setShowMenu] = useState(false);

  // Animation values
  const [isExpanded, setIsExpanded] = useState(false);
  const START_OFFSET = SHEET_MAX_HEIGHT - SHEET_MIN_HEIGHT;
  const panY = useRef(new Animated.Value(SCREEN_HEIGHT)).current;
  const overlayOpacity = useRef(new Animated.Value(0)).current;

  // Track absolute pan position
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

    if (txData) {
      try {
        const parsed = JSON.parse(txData as string);
        setTx(parsed);
        setLoading(false);
      } catch (e) { }
    }

    const fetchDetail = async () => {
      if (!id || !user) return;
      try {
        const { data: pData } = await supabase.from('profiles').select('currency').eq('id', user.id).single();
        if (pData?.currency) setCurrency(pData.currency);

        const { data, error } = await supabase
          .from('transactions')
          .select(`*, categories (name, icon, color), accounts (name)`)
          .eq('id', id)
          .single();

        if (error) throw error;

        let profileInfo = null;
        if (data.created_by) {
          const { data: creator } = await supabase.from('profiles').select('name').eq('id', data.created_by).single();
          profileInfo = creator;
        }

        setTx({ ...data, profiles: profileInfo });
      } catch (err) {
        Alert.alert('Error', 'No se pudo cargar la transacción');
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
        // Prevent dragging above top of max height
        if (lastPanY + gs.dy < 0) {
          panY.setValue(-lastPanY);
        } else {
          panY.setValue(gs.dy);
        }
      },
      onPanResponderRelease: (e, gs) => {
        panY.flattenOffset();
        const velocity = gs.vy;

        if (velocity > 1.5 || lastPanY > START_OFFSET + 100) {
          closeSheet();
          return;
        }

        let snapPoint = START_OFFSET; // default 50%
        if (velocity < -0.5 || lastPanY < START_OFFSET / 2) {
          snapPoint = 0; // go to 85%
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
    setTimeout(() => router.push(`/edit-transaction?id=${tx.id}` as any), 100);
  };

  const handleDelete = () => {
    setShowMenu(false);
    Alert.alert('Eliminar Movimiento', '¿Estás seguro? Se ajustará el saldo de la cuenta automáticamente.', [
      { text: 'Cancelar', style: 'cancel' },
      {
        text: 'Eliminar', style: 'destructive', onPress: async () => {
          try {
            setLoading(true);
            // Revertir el efecto de la transacción en el saldo, de forma atómica:
            // un income eliminado resta; un expense eliminado suma.
            const revertDelta = tx.type === 'income' ? -tx.amount : tx.amount;
            await supabase.rpc('apply_account_delta', { p_account_id: tx.account_id, p_delta: revertDelta });

            if (tx.recurring_id) {
              const { data: recurringEvents } = await supabase
                .from('recurring_events')
                .select('id, next_date, frequency')
                .eq('id', tx.recurring_id);
              
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
                Alert.alert('Alerta', 'Se borró el movimiento, pero no pude encontrar tu suscripción "' + tx.description + '" para regresarle la fecha.');
              }
            }
            await supabase.from('transactions').delete().eq('id', tx.id);
            closeSheet();
          } catch (e: any) {
            Alert.alert('Error', e.message);
            setLoading(false);
          }
        }
      }
    ]);
  };

  const formatSentenceDate = (dateString: string, createdAtString?: string) => {
    const txDate = new Date(dateString + 'T12:00:00');
    const created = createdAtString ? new Date(createdAtString) : txDate;
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const targetDay = new Date(txDate.getFullYear(), txDate.getMonth(), txDate.getDate());
    const diffTime = today.getTime() - targetDay.getTime();
    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

    const formatTime = (d: Date) => d.toLocaleTimeString('es-ES', { hour: 'numeric', minute: '2-digit', hour12: true });

    if (diffDays === 0) return `hoy a las ${formatTime(created)}`;
    if (diffDays === 1) return `ayer a las ${formatTime(created)}`;

    const month = txDate.toLocaleDateString('es-ES', { month: 'long' });
    return `el ${txDate.getDate()} de ${month}`;
  };

  const activeTx = tx || (txData ? JSON.parse(txData as string) : {});
  const isIncome = activeTx?.type === 'income';
  const creatorName = activeTx?.profiles?.name || '...';
  let initial = 'U';
  if (creatorName !== '...') initial = creatorName.charAt(0).toUpperCase();

  return (
    <View style={styles.modalBg}>
      <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.6)', opacity: overlayOpacity }]}>
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
                <View style={[styles.dropdown, { top: 40, backgroundColor: theme.card, borderColor: theme.border }]}>
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

        {(!activeTx.id && !loading) ? (
          <View style={styles.center}>
            <Text style={{ color: theme.text }}>Transacción no encontrada</Text>
          </View>
        ) : (
          <View style={styles.content}>
            <View style={styles.cardHeader}>
              <View style={[styles.avatar, { backgroundColor: activeTx.categories?.color || theme.border }]}>
                <Text style={[styles.avatarText, { color: theme.background }]}>{initial}</Text>
              </View>
              <View>
                <Text style={[styles.cardTitle, { color: theme.text }]}>{creatorName}</Text>
                <Text style={[styles.cardSubtitle, { color: theme.textMuted }]}>Miembro del hogar</Text>
              </View>
            </View>

            <Text style={styles.sentence}>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>{creatorName} {isIncome ? 'recibió ' : 'gastó '}</Text>
              <Text style={[styles.boldText, isIncome ? { color: '#22C55E' } : { color: '#EF4444' }]}>{formatCurrency(activeTx.amount || 0, currency)} </Text>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>{activeTx.date ? formatSentenceDate(activeTx.date, activeTx.created_at) : '...'} por concepto de </Text>
              <Text style={[styles.boldText, { color: theme.text }]}>{(activeTx.description || activeTx.categories?.name || 'movimiento').toLowerCase()} </Text>
              {!isIncome && <Text style={[styles.grayText, { color: theme.textMuted }]}>&#34;{activeTx.categories?.name || 'General'}&#34; </Text>}
              <Text style={[styles.grayText, { color: theme.textMuted }]}>{isIncome ? 'en ' : 'desde '}</Text>
              <Text style={[styles.boldText, { color: theme.text }]}>{activeTx.accounts?.name || '...'}</Text>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>.</Text>
            </Text>

            <View style={styles.pillsContainer}>
              <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                <HugeiconsIcon icon={Calendar01Icon} size={15} color={theme.textMuted} />
                <Text style={[styles.pillText, { color: theme.text }]}>{activeTx.date ? formatShortDate(activeTx.date) : '...'}</Text>
              </View>
              <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                <HugeiconsIcon icon={Wallet01Icon} size={15} color={theme.textMuted} />
                <Text style={[styles.pillText, { color: theme.text }]}>{isIncome ? 'Ingreso' : 'Gasto'}</Text>
              </View>
              <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                <HugeiconsIcon icon={Folder01Icon} size={15} color={theme.textMuted} />
                <Text style={[styles.pillText, { color: theme.text }]}>{activeTx.categories?.name || 'General'}</Text>
              </View>
            </View>
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
  dropdown: { position: 'absolute', right: 0, borderRadius: 14, borderWidth: 1, minWidth: 160, zIndex: 100, shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.4, shadowRadius: 12 },
  dropdownItem: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 16, paddingVertical: 14 },
  dropdownText: { fontSize: 16, fontWeight: '600' },
  dropdownDivider: { height: 1 },
  content: { paddingHorizontal: 20, paddingTop: 10 },
  cardHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 24, gap: 12 },
  avatar: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  avatarText: { fontSize: 18, fontWeight: '700', color: '#FAFAFA' },
  cardTitle: { fontSize: 16, fontWeight: '700' },
  cardSubtitle: { fontSize: 13, fontWeight: '500', marginTop: 2 },
  sentence: { fontSize: 26, lineHeight: 38, letterSpacing: -0.5 },
  grayText: { fontWeight: '500' },
  boldText: { fontWeight: '800' },
  pillsContainer: { marginTop: 32, gap: 8 },
  pill: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingVertical: 10, borderRadius: 8, alignSelf: 'flex-start', borderWidth: 1 },
  pillText: { fontSize: 14, fontWeight: '600' }
});
