import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, Pressable, Animated, PanResponder, Dimensions, ScrollView, ImageBackground } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../src/lib/supabase';
import { formatCurrency } from '@jojos/core';
import TransactionItem from '../../src/components/TransactionItem';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Cancel01Icon, Edit02Icon, MoreHorizontalIcon, Delete01Icon } from '@hugeicons/core-free-icons';
import { useAuth } from '../../src/context/AuthContext';
import { useTheme } from '../../src/context/ThemeContext';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const SHEET_MAX_HEIGHT = SCREEN_HEIGHT * 0.92;
const SHEET_MIN_HEIGHT = SCREEN_HEIGHT * 0.55;

export default function AccountDetailScreen() {
  const { id, accountData } = useLocalSearchParams();
  const router = useRouter();
  const { user } = useAuth();
  const { theme, isDark } = useTheme();
  
  const [loading, setLoading] = useState(true);
  const [account, setAccount] = useState<any>(accountData ? JSON.parse(accountData as string) : null);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [members, setMembers] = useState<any[]>([]);
  const [currency, setCurrency] = useState('USD');
  const [showMenu, setShowMenu] = useState(false);

  // Animation
  const [isExpanded, setIsExpanded] = useState(false);
  const START_OFFSET = SHEET_MAX_HEIGHT - SHEET_MIN_HEIGHT;
  const panY = useRef(new Animated.Value(SCREEN_HEIGHT)).current;
  const overlayOpacity = useRef(new Animated.Value(0)).current;

  let lastPanY = START_OFFSET;
  panY.addListener(({ value }) => { lastPanY = value; });

  useEffect(() => {
    Animated.parallel([
      Animated.timing(overlayOpacity, { toValue: 1, duration: 300, useNativeDriver: true }),
      Animated.spring(panY, { toValue: START_OFFSET, useNativeDriver: true, bounciness: 0 }),
    ]).start();

    const fetchDetail = async () => {
      if (!id || !user) return;
      try {
        const { data: pData } = await supabase.from('profiles').select('household_id, currency').eq('id', user.id).single();
        if (pData?.currency) setCurrency(pData.currency);
        if (!pData?.household_id) return;

        const { data: accData, error: accErr } = await supabase.from('accounts').select('*').eq('id', id).single();
        if (accErr) throw accErr;
        setAccount(accData);

        const [txsRes, catsRes, memsRes] = await Promise.all([
          supabase.from('transactions').select('*').eq('account_id', id).order('date', { ascending: false }),
          supabase.from('categories').select('*').eq('household_id', pData.household_id),
          supabase.from('profiles').select('id, name').eq('household_id', pData.household_id),
        ]);
        setTransactions(txsRes.data || []);
        setCategories(catsRes.data || []);
        setMembers(memsRes.data || []);
      } catch (err) {
        Alert.alert('Error', 'No se pudo cargar la cuenta');
      } finally {
        setLoading(false);
      }
    };
    fetchDetail();
  }, [id, user]);

  const closeSheet = () => {
    Animated.parallel([
      Animated.timing(overlayOpacity, { toValue: 0, duration: 200, useNativeDriver: true }),
      Animated.timing(panY, { toValue: SCREEN_HEIGHT, duration: 200, useNativeDriver: true }),
    ]).start(() => router.back());
  };

  const handleEdit = () => {
    setShowMenu(false);
    router.push(`/edit-account?id=${activeAcc.id}` as any);
  };

  const handleDelete = () => {
    setShowMenu(false);
    Alert.alert('Eliminar Cuenta', '¿Estás seguro? Esta acción no se puede deshacer.', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
          try {
            await supabase.from('accounts').delete().eq('id', activeAcc.id);
            closeSheet();
          } catch (e: any) {
            Alert.alert('Error', e.message);
          }
      }},
    ]);
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
        if (lastPanY + gs.dy < 0) panY.setValue(-lastPanY);
        else panY.setValue(gs.dy);
      },
      onPanResponderRelease: (e, gs) => {
        panY.flattenOffset();
        const velocity = gs.vy;
        if (velocity > 1.5 || lastPanY > START_OFFSET + 100) { closeSheet(); return; }
        let snapPoint = START_OFFSET;
        if (velocity < -0.5 || lastPanY < START_OFFSET / 2) { snapPoint = 0; setIsExpanded(true); }
        else setIsExpanded(false);
        Animated.spring(panY, { toValue: snapPoint, useNativeDriver: true, bounciness: 0 }).start();
      },
    })
  ).current;

  const activeAcc = account || {};
  const fmt = (n: number) => formatCurrency(n || 0, currency);

  return (
    <View style={styles.modalBg}>
      <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.6)', opacity: overlayOpacity }]}>
        <Pressable style={StyleSheet.absoluteFillObject} onPress={closeSheet} />
      </Animated.View>

      <Animated.View style={[styles.sheetContainer, { backgroundColor: theme.card, transform: [{ translateY: panY }] }]}>
        <View style={styles.handleArea} {...panResponder.panHandlers}>
          <View style={[styles.sheetHandle, { backgroundColor: theme.border }]} />
        </View>

        <View style={styles.headerRow}>
          <TouchableOpacity onPress={closeSheet} style={[styles.iconBtn, { backgroundColor: theme.pillBg }]}>
            <HugeiconsIcon icon={Cancel01Icon} size={24} color={theme.text} />
          </TouchableOpacity>
          <Text style={[styles.headerTitle, { color: theme.text }]}>Detalles de Cuenta</Text>
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
                    <HugeiconsIcon icon={Delete01Icon} size={18} color="#EF4444" />
                    <Text style={[styles.dropdownText, { color: '#EF4444' }]}>Eliminar</Text>
                  </TouchableOpacity>
                </View>
              </>
            )}
          </View>
        </View>

        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          {activeAcc.id ? (
            <View style={styles.cardWrapper}>
              <ImageBackground
                source={require('../../assets/images/card-bg.png')}
                style={[styles.cardBg, { shadowColor: isDark ? '#000' : theme.text, shadowOpacity: isDark ? 0.1 : 0.05 }]}
                imageStyle={{ borderRadius: 24 }}
                resizeMode="cover"
              >
                <View style={[styles.cardOverlay, { backgroundColor: isDark ? 'rgba(0,0,0,0.2)' : 'rgba(255,255,255,0.1)' }]}>
                  <View style={styles.cardTop}>
                    <Text style={[styles.cardName, { color: isDark ? '#FFFFFF' : '#18181B', textShadowColor: isDark ? 'rgba(0,0,0,0.3)' : 'transparent' }]}>{activeAcc.name}</Text>
                    <View style={[styles.chip, { borderColor: isDark ? 'rgba(255,255,255,0.6)' : 'rgba(0,0,0,0.2)' }]}><View style={[styles.chipLine, { backgroundColor: isDark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.15)' }]} /></View>
                  </View>
                  <View style={styles.cardBottom}>
                    <View>
                      <Text style={[styles.cardSub, { color: isDark ? 'rgba(255,255,255,0.8)' : 'rgba(0,0,0,0.6)' }]}>{activeAcc.type}</Text>
                      <Text style={[styles.cardBalance, { color: isDark ? '#FFFFFF' : '#18181B', textShadowColor: isDark ? 'rgba(0,0,0,0.3)' : 'transparent' }]}>{fmt(activeAcc.balance)}</Text>
                    </View>
                    <View style={styles.mcLogo}>
                      <View style={[styles.mcCircle, { backgroundColor: '#EF4444', marginRight: -12 }]} />
                      <View style={[styles.mcCircle, { backgroundColor: '#F59E0B' }]} />
                    </View>
                  </View>
                </View>
              </ImageBackground>
            </View>
          ) : null}

          <Text style={[styles.sectionTitle, { color: theme.text }]}>Historial de Movimientos</Text>
          <View style={styles.listContainer}>
            {transactions.length === 0 ? (
              <Text style={[styles.emptyText, { color: theme.textMuted }]}>No hay transacciones en esta cuenta</Text>
            ) : transactions.map((tx, index) => {
              const cat = categories.find(c => c.id === tx.category_id);
              const creator = members.find(m => m.id === tx.created_by);
              return (
                <TransactionItem
                  key={tx.id}
                  tx={tx}
                  category={cat}
                  creator={creator}
                  currency={currency}
                  isLast={index === transactions.length - 1}
                  onPress={() => router.push({ pathname: '/transaction/[id]', params: { id: tx.id, txData: JSON.stringify(tx) } } as any)}
                  onLongPress={() => router.push(`/edit-transaction?id=${tx.id}` as any)}
                />
              );
            })}
          </View>
        </ScrollView>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  modalBg: { flex: 1, backgroundColor: 'transparent', justifyContent: 'flex-end' },
  sheetContainer: { height: SHEET_MAX_HEIGHT, borderTopLeftRadius: 24, borderTopRightRadius: 24 },
  handleArea: { width: '100%', height: 30, alignItems: 'center', justifyContent: 'flex-end' },
  sheetHandle: { width: 40, height: 4, borderRadius: 2, marginBottom: 10 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 8 },
  iconBtn: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderRadius: 22 },
  headerTitle: { fontSize: 16, fontWeight: '600' },
  content: { paddingBottom: 80 },
  cardWrapper: { paddingHorizontal: 20, paddingVertical: 16 },
  cardBg: { height: 200, borderRadius: 24, shadowOffset: { width: 0, height: 4 }, shadowRadius: 8, elevation: 4 },
  cardOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 24, padding: 20, justifyContent: 'space-between' },
  cardTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  cardName: { fontSize: 18, color: '#FFFFFF', fontWeight: '700', letterSpacing: 1, textShadowColor: 'rgba(0,0,0,0.3)', textShadowOffset: { width: 0, height: 2 }, textShadowRadius: 4 },
  chip: { width: 34, height: 24, borderRadius: 6, borderWidth: 1, borderColor: 'rgba(255,255,255,0.6)', justifyContent: 'center', alignItems: 'center' },
  chipLine: { width: '100%', height: 1, backgroundColor: 'rgba(255,255,255,0.4)' },
  cardBottom: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  cardSub: { fontSize: 12, color: 'rgba(255,255,255,0.8)', textTransform: 'uppercase', letterSpacing: 1.5, marginBottom: 4 },
  cardBalance: { fontSize: 26, fontWeight: '800', color: '#FFFFFF', letterSpacing: 1, textShadowColor: 'rgba(0,0,0,0.3)', textShadowOffset: { width: 0, height: 2 }, textShadowRadius: 4, fontVariant: ['tabular-nums'] },
  mcLogo: { flexDirection: 'row', alignItems: 'center' },
  mcCircle: { width: 32, height: 32, borderRadius: 16, opacity: 0.85 },
  dropdownOverlay: { position: 'absolute', top: -50, right: -50, bottom: -500, left: -500, zIndex: 90 },
  dropdown: { position: 'absolute', right: 0, borderRadius: 14, borderWidth: 1, minWidth: 160, zIndex: 100, shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.4, shadowRadius: 12 },
  dropdownItem: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 16, paddingVertical: 14 },
  dropdownText: { fontSize: 16, fontWeight: '600' },
  dropdownDivider: { height: 1 },
  sectionTitle: { fontSize: 18, fontWeight: '600', paddingHorizontal: 20, marginBottom: 8 },
  listContainer: { paddingHorizontal: 20 },
  emptyText: { fontSize: 14, textAlign: 'center', marginVertical: 32 },
});
