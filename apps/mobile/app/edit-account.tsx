import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView, ImageBackground } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Delete01Icon } from '@hugeicons/core-free-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../src/context/ThemeContext';
import AmountInput from '../src/components/AmountInput';
import DynamicIcon from '../src/components/DynamicIcon';

const COLOR_MAP: Record<string, string> = {
  debit: '#2563EB', credit: '#EF4444', cash: '#22C55E', savings: '#F59E0B',
};
const TYPES = [
  { val: 'debit', label: 'Débito' },
  { val: 'credit', label: 'Crédito' },
  { val: 'cash', label: 'Efectivo' },
  { val: 'savings', label: 'Ahorros' },
];

export default function EditAccountScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const { theme, isDark } = useTheme();

  const [saving, setSaving] = useState(false);
  const [name, setName] = useState('');
  const [balance, setBalance] = useState('');
  const [type, setType] = useState('debit');

  useEffect(() => {
    const load = async () => {
      if (!id) return;
      const { data } = await supabase.from('accounts').select('*').eq('id', id).single();
      if (data) { setName(data.name); setBalance(String(data.balance)); setType(data.type); }
    };
    load();
  }, [id]);

  const handleSave = async () => {
    if (!name.trim()) { Alert.alert('Error', 'Ingresa un nombre.'); return; }
    if (isNaN(Number(balance))) { Alert.alert('Error', 'Balance inválido.'); return; }
    setSaving(true);
    try {
      const { error } = await supabase.from('accounts').update({
        name: name.trim(),
        balance: Number(balance),
        type,
        color: COLOR_MAP[type] ?? '#2563EB',
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
    Alert.alert('Eliminar Cuenta', '¿Eliminar esta cuenta? Se eliminarán también todas sus transacciones.', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
          try {
            await supabase.from('transactions').delete().eq('account_id', id);
            await supabase.from('accounts').delete().eq('id', id);
            router.back();
          } catch (e: any) { Alert.alert('Error', e.message); }
      }},
    ]);
  };

  const cardColor = COLOR_MAP[type] || '#2563EB';
  const displayBalance = balance ? `$${Number(balance).toLocaleString('es-CO')}` : '$0';

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 8) }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={[styles.closeBtn, { backgroundColor: theme.pillBg }]}>
          <Text style={[styles.closeBtnText, { color: theme.text }]}>✕</Text>
        </TouchableOpacity>
        <Text style={[styles.title, { color: theme.text }]}>Editar Cuenta</Text>
        <TouchableOpacity onPress={handleDelete} style={[styles.deleteIconBtn, { backgroundColor: isDark ? '#EF444415' : 'rgba(239, 68, 68, 0.05)' }]}>
          <HugeiconsIcon icon={Delete01Icon} size={20} color={theme.danger} />
        </TouchableOpacity>
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        {/* LIVE CARD PREVIEW */}
        <View style={styles.cardWrapper}>
          <ImageBackground
            source={require('../assets/images/card-bg.png')}
            style={[styles.cardBg, { shadowColor: isDark ? '#000' : theme.text, shadowOpacity: isDark ? 0.1 : 0.05, shadowOffset: { width: 0, height: 4 }, shadowRadius: 8, elevation: 4 }]}
            imageStyle={{ borderRadius: 24 }}
            resizeMode="cover"
          >
            <View style={[styles.cardOverlay, { borderColor: `${cardColor}60`, backgroundColor: isDark ? 'rgba(0,0,0,0.18)' : 'rgba(255,255,255,0.15)' }]}>
              <View style={styles.cardTop}>
                <Text style={[styles.cardName, { color: isDark ? '#FFFFFF' : '#18181B', textShadowColor: isDark ? 'rgba(0,0,0,0.3)' : 'transparent' }]}>{name || 'Nombre de Cuenta'}</Text>
                <View style={[styles.chip, { borderColor: isDark ? 'rgba(255,255,255,0.6)' : 'rgba(0,0,0,0.2)' }]}><View style={[styles.chipLine, { backgroundColor: isDark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.15)' }]} /></View>
              </View>
              <View style={styles.cardBottom}>
                <View>
                  <Text style={[styles.cardType, { color: isDark ? 'rgba(255,255,255,0.8)' : 'rgba(0,0,0,0.6)' }]}>{TYPES.find(t => t.val === type)?.label?.toUpperCase()}</Text>
                  <Text style={[styles.cardBalance, { color: isDark ? '#FFFFFF' : '#18181B', textShadowColor: isDark ? 'rgba(0,0,0,0.3)' : 'transparent' }]}>{displayBalance}</Text>
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
          <Text style={[styles.label, { color: theme.textMuted }]}>Tipo de Cuenta</Text>
          <View style={styles.pillRow}>
            {TYPES.map(({ val, label }) => (
              <TouchableOpacity
                key={val}
                style={[styles.pill, { backgroundColor: theme.pillBg, borderColor: theme.border }, type === val && { backgroundColor: cardColor, borderColor: cardColor }]}
                onPress={() => setType(val)}
              >
                <Text style={[styles.pillText, { color: theme.textMuted }, type === val && { color: '#FFF' }]}>{label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* NAME */}
        <View style={styles.section}>
          <Text style={[styles.label, { color: theme.textMuted }]}>Nombre</Text>
          <TextInput
            style={[styles.input, { backgroundColor: theme.card, borderColor: theme.border, color: theme.text }]}
            placeholder="Ej: Tarjeta Crédito Nu"
            placeholderTextColor={theme.textMuted}
            value={name}
            onChangeText={setName}
          />
        </View>

        {/* BALANCE */}
        <View style={styles.section}>
          <Text style={[styles.label, { color: theme.textMuted }]}>Balance Actual</Text>
          <AmountInput
            style={[styles.input, { backgroundColor: theme.card, borderColor: theme.border, color: theme.text }]}
            placeholder="0"
            placeholderTextColor={theme.textMuted}
            value={balance}
            onChangeText={setBalance}
          />
        </View>
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: insets.bottom + 16, borderTopColor: theme.border }]}>
        <TouchableOpacity style={[styles.saveBtn, { backgroundColor: cardColor }]} onPress={handleSave} disabled={saving}>
          {saving ? <ActivityIndicator color="#FFF" /> : <Text style={styles.saveBtnText}>Guardar Cambios</Text>}
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingBottom: 12 },
  closeBtn: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 20 },
  closeBtnText: { fontSize: 18, fontWeight: '600' },
  title: { fontSize: 18, fontWeight: '700' },
  deleteIconBtn: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 20, borderWidth: 1, borderColor: '#EF444440' },
  content: { paddingBottom: 40 },

  cardWrapper: { marginHorizontal: 20, marginBottom: 28 },
  cardBg: { height: 200, borderRadius: 24 },
  cardOverlay: { flex: 1, borderRadius: 24, borderWidth: 1.5, padding: 22, justifyContent: 'space-between' },
  cardTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  cardName: { fontSize: 18, color: '#FFF', fontWeight: '700', flex: 1, letterSpacing: 0.3, textShadowColor: 'rgba(0,0,0,0.3)', textShadowOffset: { width: 0, height: 2 }, textShadowRadius: 4 },
  chip: { width: 34, height: 24, borderRadius: 6, borderWidth: 1, borderColor: 'rgba(255,255,255,0.6)', justifyContent: 'center', alignItems: 'center' },
  chipLine: { width: '100%' as any, height: 1, backgroundColor: 'rgba(255,255,255,0.4)' },
  cardBottom: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  cardType: { fontSize: 11, color: 'rgba(255,255,255,0.8)', letterSpacing: 1.5, marginBottom: 4 },
  cardBalance: { fontSize: 28, fontWeight: '800', color: '#FFF', letterSpacing: 0.5, textShadowColor: 'rgba(0,0,0,0.3)', textShadowOffset: { width: 0, height: 2 }, textShadowRadius: 4 },
  mcLogo: { flexDirection: 'row', alignItems: 'center' },
  mcCircle: { width: 32, height: 32, borderRadius: 16, opacity: 0.85 },

  section: { marginHorizontal: 20, marginBottom: 20 },
  label: { fontSize: 13, fontWeight: '500', marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.8 },
  pillRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  pill: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, borderWidth: 1 },
  pillText: { fontWeight: '600', fontSize: 14 },
  input: { borderRadius: 14, borderWidth: 1, paddingHorizontal: 18, height: 54, fontSize: 18, letterSpacing: 0 },

  footer: { paddingHorizontal: 20, paddingTop: 12, borderTopWidth: 1 },
  saveBtn: { height: 56, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  saveBtnText: { color: '#FFF', fontSize: 17, fontWeight: '700' },
});
