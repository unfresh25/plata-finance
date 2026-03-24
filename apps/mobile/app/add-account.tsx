import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView, Modal, Dimensions, ImageBackground } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DynamicIcon from '../src/components/DynamicIcon';
import AmountInput from '../src/components/AmountInput';

const COLOR_MAP: Record<string, string> = {
  debit: '#2563EB', credit: '#EF4444', cash: '#22C55E', savings: '#F59E0B',
};
const TYPES = [
  { val: 'debit', label: 'Débito' },
  { val: 'credit', label: 'Crédito' },
  { val: 'cash', label: 'Efectivo' },
  { val: 'savings', label: 'Ahorros' },
];

export default function AddAccountScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(false);
  const [householdId, setHouseholdId] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [type, setType] = useState('debit');
  const [balance, setBalance] = useState('');

  useEffect(() => {
    const fetchHousehold = async () => {
      if (!user) return;
      const { data } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();
      if (data?.household_id) setHouseholdId(data.household_id);
    };
    fetchHousehold();
  }, [user]);

  const handleSave = async () => {
    if (!name.trim()) return Alert.alert('Error', 'Ingresa un nombre para la cuenta.');
    setLoading(true);
    let targetHouseholdId = householdId;
    if (!targetHouseholdId && user) {
      try {
        const { data: hh } = await supabase.from('households').insert({ name: 'Hogar Principal' }).select().single();
        if (hh) {
          await supabase.from('profiles').update({ household_id: hh.id }).eq('id', user.id);
          targetHouseholdId = hh.id;
        }
      } catch (e: any) {
        setLoading(false);
        return Alert.alert('Error', e.message);
      }
    }
    try {
      const { error } = await supabase.from('accounts').insert({
        household_id: targetHouseholdId,
        owner_id: user?.id,
        name,
        type,
        balance: Number(balance) || 0,
        icon: { debit: '🏦', credit: '💳', cash: '💵', savings: '🐷' }[type] ?? '💰',
        color: COLOR_MAP[type] ?? '#2563EB',
      });
      if (error) throw error;
      router.back();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setLoading(false);
    }
  };

  const cardColor = COLOR_MAP[type] || '#2563EB';
  const displayBalance = balance ? `$${Number(balance).toLocaleString('es-CO')}` : '$0';
  const selectedIcon = { color: cardColor }; // Define selectedIcon for use in AmountInput

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 8) }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.closeBtn}>
          <Text style={styles.closeBtnText}>✕</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Nueva Cuenta</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        {/* LIVE CARD PREVIEW */}
        <View style={styles.cardWrapper}>
          <ImageBackground
            source={require('../assets/images/card-bg.png')}
            style={styles.cardBg}
            imageStyle={{ borderRadius: 24 }}
            resizeMode="cover"
          >
            <View style={[styles.cardOverlay, { borderColor: `${cardColor}60` }]}>
              <View style={styles.cardTop}>
                <Text style={styles.cardName}>{name || 'Nombre de Cuenta'}</Text>
                <View style={styles.chip}><View style={styles.chipLine} /></View>
              </View>
              <View style={styles.cardBottom}>
                <View>
                  <Text style={styles.cardType}>{TYPES.find(t => t.val === type)?.label?.toUpperCase()}</Text>
                  <Text style={styles.cardBalance}>{displayBalance}</Text>
                </View>
                <View style={styles.mcLogo}>
                  <View style={[styles.mcCircle, { backgroundColor: '#EF4444', marginRight: -12 }]} />
                  <View style={[styles.mcCircle, { backgroundColor: '#F59E0B' }]} />
                </View>
              </View>
            </View>
          </ImageBackground>
        </View>

        {/* TYPE PILLS */}
        <View style={styles.section}>
          <Text style={styles.label}>Tipo de Cuenta</Text>
          <View style={styles.pillRow}>
            {TYPES.map(({ val, label }) => (
              <TouchableOpacity
                key={val}
                style={[styles.pill, type === val && { backgroundColor: cardColor, borderColor: cardColor }]}
                onPress={() => setType(val)}
              >
                <Text style={[styles.pillText, type === val && styles.pillTextActive]}>{label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* NAME */}
        <View style={styles.section}>
          <Text style={styles.label}>Nombre</Text>
          <TextInput
            style={styles.input}
            placeholder="Ej: Tarjeta Crédito Nu"
            placeholderTextColor="#71717A"
            value={name}
            onChangeText={setName}
          />
        </View>

        {/* BALANCE */}
        <View style={styles.section}>
          <Text style={styles.label}>Balance Inicial</Text>
          <AmountInput
            style={styles.input}
            placeholder="0.00"
            placeholderTextColor="#71717A"
            value={balance}
            onChangeText={setBalance}
          />
        </View>
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: insets.bottom + 16 }]}>
        <TouchableOpacity style={[styles.saveBtn, { backgroundColor: cardColor }]} onPress={handleSave} disabled={loading}>
          {loading ? <ActivityIndicator color="#FFF" /> : <Text style={styles.saveBtnText}>Guardar Cuenta</Text>}
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingBottom: 12 },
  closeBtn: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 20 },
  closeBtnText: { color: '#FAFAFA', fontSize: 18, fontWeight: '600' },
  title: { fontSize: 18, fontWeight: '700', color: '#FAFAFA' },
  content: { paddingBottom: 40 },

  cardWrapper: { marginHorizontal: 20, marginBottom: 28 },
  cardBg: { height: 200, borderRadius: 24 },
  cardOverlay: { flex: 1, borderRadius: 24, borderWidth: 1.5, padding: 22, justifyContent: 'space-between', backgroundColor: 'rgba(0,0,0,0.18)' },
  cardTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  cardName: { fontSize: 18, color: '#FFF', fontWeight: '700', flex: 1, letterSpacing: 0.3 },
  chip: { width: 34, height: 24, borderRadius: 6, borderWidth: 1, borderColor: 'rgba(255,255,255,0.6)', justifyContent: 'center', alignItems: 'center' },
  chipLine: { width: '100%' as any, height: 1, backgroundColor: 'rgba(255,255,255,0.4)' },
  cardBottom: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  cardType: { fontSize: 11, color: 'rgba(255,255,255,0.8)', letterSpacing: 1.5, marginBottom: 4 },
  cardBalance: { fontSize: 28, fontWeight: '800', color: '#FFF', letterSpacing: 0.5 },
  mcLogo: { flexDirection: 'row', alignItems: 'center' },
  mcCircle: { width: 32, height: 32, borderRadius: 16, opacity: 0.85 },

  section: { marginHorizontal: 20, marginBottom: 20 },
  label: { fontSize: 13, color: '#71717A', fontWeight: '500', marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.8 },
  pillRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  pill: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' },
  pillText: { color: '#A1A1AA', fontWeight: '600', fontSize: 14 },
  pillTextActive: { color: '#FFF' },
  input: { backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 14, borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)', color: '#FAFAFA', paddingHorizontal: 18, height: 54, fontSize: 18, letterSpacing: 0 },

  footer: { paddingHorizontal: 20, paddingTop: 12, borderTopWidth: 1, borderTopColor: '#18181B' },
  saveBtn: { height: 56, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  saveBtnText: { color: '#FFF', fontSize: 17, fontWeight: '700' },
});
