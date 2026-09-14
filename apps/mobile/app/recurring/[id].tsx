import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, Pressable, Animated, PanResponder, Dimensions, Image, ActivityIndicator, ScrollView } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { formatCurrency, formatShortDate } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Cancel01Icon, Calendar01Icon, Folder01Icon, Wallet01Icon, MoreHorizontalIcon, Edit02Icon, Delete01Icon, Alert01Icon, Tick02Icon } from '@hugeicons/core-free-icons';
import { useAuth } from '../../src/context/AuthContext';
import { SUBSCRIPTION_LOGOS } from '../../src/data/SubscriptionLogos';
import DynamicIcon from '../../src/components/DynamicIcon';
import { useTheme } from '../../src/context/ThemeContext';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const SHEET_MAX_HEIGHT = SCREEN_HEIGHT * 0.85;
const SHEET_MIN_HEIGHT = SCREEN_HEIGHT * 0.5;

export default function RecurringDetailScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();

  const [loading, setLoading] = useState(true);
  const [confirming, setConfirming] = useState(false);
  const [event, setEvent] = useState<any>(null);
  const [accounts, setAccounts] = useState<any[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState<string | null>(null);
  const [currency, setCurrency] = useState('USD');
  const [showMenu, setShowMenu] = useState(false);

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
          .from('recurring_events')
          .select(`*, categories (name, icon, color)`)
          .eq('id', id)
          .single();

        if (error) throw error;
        setEvent(data);

        const { data: accs } = await supabase.from('accounts').select('id, name, type, color, icon, balance').eq('household_id', data.household_id);
        if (accs) {
          setAccounts(accs);
          setSelectedAccountId(data.account_id || accs[0]?.id);
        }
      } catch (err) {
        Alert.alert('Error', 'No se pudo cargar el evento recurrente');
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
    setTimeout(() => router.push(`/edit-recurring?id=${event.id}` as any), 100);
  };

  const handleDelete = () => {
    setShowMenu(false);
    Alert.alert('Eliminar Evento', '¿Estás seguro de eliminar este evento recurrente?', [
      { text: 'Cancelar', style: 'cancel' },
      {
        text: 'Eliminar', style: 'destructive', onPress: async () => {
          try {
            setLoading(true);
            await supabase.from('recurring_events').delete().eq('id', event.id);
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
    try {
      setConfirming(true);
      if (!selectedAccountId) {
        Alert.alert('Error', 'Debes seleccionar una cuenta a utilizar.');
        return;
      }
      
      const account = accounts.find(a => a.id === selectedAccountId);
      if (!account) return;
      const amount = event.amount;
      const type = event.type; 

      await supabase.from('transactions').insert({
        household_id: event.household_id,
        account_id: account.id,
        category_id: event.category_id, 
        recurring_id: event.id,
        amount: amount,
        type: type,
        description: `${event.name}`,
        date: new Date().toISOString().split('T')[0],
        created_by: user?.id
      });
      
      // Ajuste de balance atómico (evita read-modify-write).
      const balanceChange = type === 'income' ? amount : -amount;
      await supabase.rpc('apply_account_delta', { p_account_id: account.id, p_delta: balanceChange });

      const [y, m, d] = event.next_date.split('T')[0].split('-');
      const current = new Date(Number(y), Number(m) - 1, Number(d));
      if (event.frequency === 'monthly') current.setMonth(current.getMonth() + 1);
      else if (event.frequency === 'yearly') current.setFullYear(current.getFullYear() + 1);
      else if (event.frequency === 'weekly') current.setDate(current.getDate() + 7);
      else if (event.frequency === 'biweekly') current.setDate(current.getDate() + 14);
      
      const ny = current.getFullYear();
      const nm = String(current.getMonth() + 1).padStart(2, '0');
      const ndd = String(current.getDate()).padStart(2, '0');
      const newNextDate = `${ny}-${nm}-${ndd}T12:00:00`;

      await supabase.from('recurring_events').update({ next_date: newNextDate }).eq('id', event.id);

      Alert.alert('Éxito', 'Pago confirmado correctamente.');
      closeSheet();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      if (confirming) setConfirming(false);
    }
  };

  if (!event && !loading) {
    return (
      <View style={styles.modalBg}>
        <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.6)', opacity: overlayOpacity }]} />
        <Animated.View style={[styles.sheetContainer, { backgroundColor: theme.card, transform: [{ translateY: panY }] }]}>
          <View style={styles.center}><Text style={{ color: theme.text }}>Evento no encontrado</Text></View>
        </Animated.View>
      </View>
    );
  }

  const isIncome = event?.type === 'income';
  const logoMatch = event ? SUBSCRIPTION_LOGOS.find(l => l.id !== 'none' && (l.id === event.logo_id || l.name.toLowerCase() === event.name.toLowerCase())) : null;

  let frequencyLabel = 'una vez al mes';
  if (event?.frequency === 'weekly') frequencyLabel = 'cada semana';
  if (event?.frequency === 'yearly') frequencyLabel = 'una vez al año';

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

        {event && (
          <View style={styles.content}>
            <View style={styles.cardHeader}>
              <View style={[styles.avatar, { backgroundColor: event?.categories?.color || theme.border }]}>
                {logoMatch ? (
                  <Image source={logoMatch.logo} style={{ width: 32, height: 32 }} resizeMode="contain" />
                ) : event?.categories ? (
                  <DynamicIcon name={event.categories.icon} size={16} color={theme.background} />
                ) : (
                  <HugeiconsIcon icon={Calendar01Icon} size={24} color={theme.background} />
                )}
              </View>
              <View>
                <Text style={[styles.cardTitle, { color: theme.text }]}>{logoMatch ? logoMatch.name : 'Servicio'}</Text>
                <Text style={[styles.cardSubtitle, { color: theme.textMuted }]}>{event.name}</Text>
              </View>
            </View>

            <Text style={styles.sentence}>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>Tú {isIncome ? 'recibes ' : 'gastas '}</Text>
              <Text style={[styles.boldText, isIncome ? { color: '#22C55E' } : { color: theme.text }]}>{formatCurrency(event.amount || 0, currency)} </Text>
              <Text style={[styles.grayText, { color: theme.textMuted }]}>{frequencyLabel} en esta suscripción.</Text>
            </Text>

            <View style={styles.pillsContainer}>
              <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                <HugeiconsIcon icon={Calendar01Icon} size={15} color={theme.textMuted} />
                <Text style={[styles.pillText, { color: theme.text }]}>{event.next_date ? `Próximo pago: ${formatShortDate(event.next_date)}` : '...'}</Text>
              </View>
              <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                <HugeiconsIcon icon={event.is_active ? Tick02Icon : Alert01Icon} size={15} color={event.is_active ? "#22C55E" : theme.textMuted} />
                <Text style={[styles.pillText, { color: theme.text }]}>{event.is_active ? 'Activa' : 'Pausada'}</Text>
              </View>
              {event.categories && (
                <View style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }]}>
                  <DynamicIcon name={event.categories.icon} size={15} color={event.categories.color} />
                  <Text style={[styles.pillText, { color: theme.text }]}>{event.categories.name}</Text>
                </View>
              )}
            </View>

            <View style={{ marginTop: 24 }}>
              <Text style={[styles.grayText, { color: theme.textMuted, marginBottom: 12, fontSize: 14 }]}>Cuenta para el pago</Text>
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
              style={{ marginTop: 32, backgroundColor: '#22C55E', paddingVertical: 16, borderRadius: 24, alignItems: 'center' }}
              onPress={handleConfirmPayment}
              disabled={confirming}
            >
               {confirming ? <ActivityIndicator color="#000" /> : <Text style={{ color: '#000', fontWeight: 'bold', fontSize: 16 }}>Confirmar Pago</Text>}
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
  cardHeader: { flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 32 },
  avatar: { width: 24, height: 24, borderRadius: 22, alignItems: 'center', justifyContent: 'center', borderWidth: 1 },
  cardTitle: { fontSize: 24, fontWeight: '700' },
  cardSubtitle: { fontSize: 15, marginTop: 2, fontWeight: '500' },

  sentence: { fontSize: 32, lineHeight: 42, letterSpacing: -0.5, marginBottom: 40 },
  grayText: { fontWeight: '400' },
  boldText: { fontWeight: '700' },

  pillsContainer: { flexDirection: 'column', flexWrap: 'wrap', gap: 12 },
  pill: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1 },
  pillText: { fontSize: 15, fontWeight: '500' },
  accountPill: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderWidth: 1 },
  accountPillText: { fontSize: 15, fontWeight: '600' },
});
