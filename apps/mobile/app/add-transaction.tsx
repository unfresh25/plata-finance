import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ActivityIndicator, Alert, ScrollView, Modal, ImageBackground } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme } from '../src/context/ThemeContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DateTimePicker from '@react-native-community/datetimepicker';
import AmountInput from '../src/components/AmountInput';
import * as ImagePicker from 'expo-image-picker';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ScanIcon, Album02Icon } from '@hugeicons/core-free-icons';
import DynamicIcon from '../src/components/DynamicIcon';

const CARD_WIDTH = 260; // Slightly smaller for the horizontal list

export default function AddTransactionScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [analyzingImage, setAnalyzingImage] = useState(false);

  const [accounts, setAccounts] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [householdId, setHouseholdId] = useState<string | null>(null);

  // Form State
  const [type, setType] = useState<'expense' | 'income'>('expense');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [accountId, setAccountId] = useState<string | null>(null);
  const [categoryId, setCategoryId] = useState<string | null>(null);

  // Date State
  const [date, setDate] = useState(new Date());
  const [showDatePicker, setShowDatePicker] = useState(false);

  // Modal State
  const [showCategoryModal, setShowCategoryModal] = useState(false);

  useEffect(() => {
    const fetchOptions = async () => {
      if (!user) return;
      const { data: pData } = await supabase.from('profiles').select('household_id').eq('id', user.id).single();

      if (pData?.household_id) {
        setHouseholdId(pData.household_id);
        const [accs, cats] = await Promise.all([
          supabase.from('accounts').select('*').eq('household_id', pData.household_id),
          supabase.from('categories').select('*').eq('household_id', pData.household_id)
        ]);

        setAccounts(accs.data || []);
        if (accs.data && accs.data.length > 0) setAccountId(accs.data[0].id);

        setCategories(cats.data || []);
      }
      setLoading(false);
    };
    fetchOptions();
  }, [user]);

  const handleSave = async () => {
    if (!amount || isNaN(Number(amount))) {
      Alert.alert('Error', 'Ingresa un monto válido.');
      return;
    }
    if (!accountId) {
      Alert.alert('Error', 'Debes seleccionar una cuenta.');
      return;
    }

    setSaving(true);
    try {
      const { error } = await supabase.from('transactions').insert({
        household_id: householdId,
        category_id: categoryId,
        account_id: accountId,
        created_by: user?.id,
        amount: Number(amount),
        type,
        date: date.toISOString().split('T')[0],
        description: description || null,
      });

      if (error) throw error;

      // Update account balance
      const account = accounts.find(a => a.id === accountId);
      if (account) {
        const newBalance = type === 'income'
          ? account.balance + Number(amount)
          : account.balance - Number(amount);

        await supabase.from('accounts').update({ balance: newBalance }).eq('id', account.id);
      }

      router.back();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setSaving(false);
    }
  };

  const processImageWithGemini = async (base64Img: string, mimeType: string) => {
    setAnalyzingImage(true);
    try {
      // Intenta leer la API key desde .env. Si no hay, pide al usuario añadirla.
      const apiKey = process.env.EXPO_PUBLIC_GEMINI_API_KEY;
      if (!apiKey) {
        Alert.alert('Configuración faltante', 'Falta agregar EXPO_PUBLIC_GEMINI_API_KEY en tu archivo .env para usar el OCR visual.');
        setAnalyzingImage(false);
        return;
      }

      const prompt = `
        Eres un asistente de finanzas. Extrae la información clave del siguiente recibo o factura.
        Responde ÚNICAMENTE con un JSON válido que contenga:
        "amount": el total a pagar (número, sin signos),
        "description": nombre del local o un resumen corto de qué fue el gasto,
        "date": fecha en formato YYYY-MM-DD si es legible.
      `;

      const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              { inlineData: { mimeType, data: base64Img } }
            ]
          }],
          generationConfig: {
            responseMimeType: "application/json"
          }
        })
      });

      const data = await response.json();
      if (data.candidates && data.candidates[0].content.parts[0].text) {
        let jsonStr = data.candidates[0].content.parts[0].text;
        // Limpiar backticks si los envía
        if (jsonStr.includes('```')) {
          jsonStr = jsonStr.replace(/```(json)?|```/g, '').trim();
        }
        const parsed = JSON.parse(jsonStr);

        if (parsed.amount) setAmount(String(parsed.amount));
        if (parsed.description) setDescription(parsed.description);
        if (parsed.date) {
          const parsedDate = new Date(parsed.date);
          if (!isNaN(parsedDate.getTime())) setDate(parsedDate);
        }
        setType('expense'); // Asumimos gasto para un recibo
      } else {
        throw new Error('No se pudo extraer la información visual.');
      }
    } catch (error: any) {
      Alert.alert('Error de OCR', error.message || 'Hubo un problema procesando la imagen.');
    } finally {
      setAnalyzingImage(false);
    }
  };

  const pickImage = async (useCamera: boolean = false) => {
    const options: ImagePicker.ImagePickerOptions = {
      mediaTypes: ['images'],
      allowsEditing: true,
      quality: 0.7,
      base64: true,
    };

    let result;
    if (useCamera) {
      const perms = await ImagePicker.requestCameraPermissionsAsync();
      if (!perms.granted) return Alert.alert('Permiso denegado', 'Necesitas dar permiso de cámara.');
      result = await ImagePicker.launchCameraAsync(options);
    } else {
      result = await ImagePicker.launchImageLibraryAsync(options);
    }

    if (!result.canceled && result.assets[0].base64) {
      const asset = result.assets[0];
      const mime = asset.mimeType || 'image/jpeg';
      processImageWithGemini(asset.base64 as string, mime);
    }
  };

  if (loading) {
    return <View style={[styles.center, { backgroundColor: theme.background }]}><ActivityIndicator color={theme.primary} /></View>;
  }

  const currentCategory = categories.find(c => c.id === categoryId);
  const filteredCategories = categories.filter(c => c.type === type);
  const selectedAccount = accounts.find(acc => acc.id === accountId); // Added selectedAccount

  const formatDateText = (d: Date) => {
    const today = new Date();
    if (d.toDateString() === today.toDateString()) return 'Hoy';
    return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' });
  };
  // Helper para mostrar balances en la tarjeta
  const fmt = (val: number) => new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', minimumFractionDigits: 0 }).format(val);

  return (
    <View style={[styles.container, { backgroundColor: theme.background, paddingTop: Math.max(insets.top, 10), paddingBottom: insets.bottom }]}>

      {/* HEADER */}
      <View style={styles.header}>
        <TouchableOpacity style={styles.iconBtn} onPress={() => router.back()}>
          <Text style={styles.iconText}>✕</Text>
        </TouchableOpacity>

        <View style={styles.headerRight}>
          <TouchableOpacity style={styles.headerPill} onPress={() => setShowDatePicker(true)}>
            <Text style={styles.headerPillText}>{formatDateText(date)}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.iconBtn} onPress={() => setType(type === 'income' ? 'expense' : 'income')}>
            <Text style={styles.iconText}>{type === 'income' ? '↓' : '↑'}</Text>
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
          <Text style={[styles.currencySymbol, { color: type === 'income' ? '#22C55E' : '#FAFAFA' }]}>$</Text>
          <AmountInput
            style={[styles.amountText, { color: type === 'income' ? '#22C55E' : '#FAFAFA', minWidth: 100, padding: 0 }]}
            placeholder="0"
            placeholderTextColor="#3F3F46"
            value={amount}
            onChangeText={setAmount}
            autoFocus
            maxLength={14}
            selectionColor="#2563EB"
          />
        </View>

        {/* ATTACHMENTS */}
        <View style={styles.sectionDivider}>
          <Text style={styles.sectionLabel}>Adjuntos</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.attachmentsScroll}>
            <TouchableOpacity style={styles.attachmentPill} onPress={() => pickImage(true)} disabled={analyzingImage}>
              {analyzingImage ? <ActivityIndicator size="small" color="#FFF" /> : <HugeiconsIcon icon={ScanIcon} size={20} color="#FAFAFA" />}
              <Text style={styles.pillText}>{analyzingImage ? 'Escaneando...' : 'Scan'}</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.attachmentPill} onPress={() => pickImage(false)} disabled={analyzingImage}>
              <HugeiconsIcon icon={Album02Icon} size={20} color="#FAFAFA" />
              <Text style={styles.pillText}>Fotos</Text>
            </TouchableOpacity>

          </ScrollView>
        </View>

        {/* DETAILS SECTION */}
        <View style={styles.detailsSection}>
          <Text style={styles.sectionLabel}>Nota / Descripción</Text>

          <View style={styles.inputContainer}>
            <TextInput
              style={styles.textInput}
              placeholder="Ej. Tiquete de vuelo, Cena..."
              placeholderTextColor="#71717A"
              value={description}
              onChangeText={setDescription}
            />
          </View>

          <Text style={[styles.sectionLabel, { marginTop: 12 }]}>Cuenta origen/destino</Text>

          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.accountsScroll}
            snapToInterval={CARD_WIDTH + 16} // card width + gap
            decelerationRate="fast"
          >
            {accounts.map(acc => {
              const isSelected = acc.id === accountId;
              return (
                <TouchableOpacity
                  key={acc.id}
                  style={[
                    styles.creditCard,
                    { width: CARD_WIDTH },
                    isSelected && styles.creditCardSelected
                  ]}
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
              )
            })}
          </ScrollView>

        </View>
      </ScrollView>

      {/* FIXED BOTTOM ACTIONS */}
      <View style={styles.bottomActions}>
        <TouchableOpacity
          style={[styles.categoryPillBtn, currentCategory ? { backgroundColor: currentCategory.color } : undefined, { flexDirection: 'row', alignItems: 'center', gap: 8 }]}
          onPress={() => setShowCategoryModal(true)}
        >
          <DynamicIcon name={currentCategory?.icon} size={20} color="#FAFAFA" />
          <Text style={styles.categoryPillBtnText}>
            {currentCategory ? currentCategory.name : 'Categoría'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.saveBtn}
          onPress={handleSave}
          disabled={saving || !amount || amount === '0'}
        >
          {saving ? <ActivityIndicator color="#09090B" /> : <Text style={styles.saveBtnText}>Guardar</Text>}
        </TouchableOpacity>
      </View>

      {/* CATEGORY SELECTOR MODAL */}
      <Modal visible={showCategoryModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <TouchableOpacity style={styles.modalBackdropClose} activeOpacity={1} onPress={() => setShowCategoryModal(false)} />
          <View style={styles.modalContent}>
            <View style={styles.modalHandle} />
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Seleccionar Categoría</Text>
              <TouchableOpacity onPress={() => setShowCategoryModal(false)} style={styles.modalCloseBtn}>
                <Text style={styles.modalCloseText}>✕</Text>
              </TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={styles.categoryGrid}>
              {filteredCategories.map(cat => (
                <TouchableOpacity
                  key={cat.id}
                  style={[styles.modalCatPill, { borderColor: cat.color, borderWidth: categoryId === cat.id ? 2 : 1 }]}
                  onPress={() => {
                    setCategoryId(cat.id);
                    setShowCategoryModal(false);
                  }}
                >
                  <DynamicIcon name={cat.icon} size={20} color={cat.color} />
                  <Text style={[styles.modalCatText, { color: cat.color, marginLeft: 8 }]}>{cat.name}</Text>
                </TouchableOpacity>
              ))}
              {filteredCategories.length === 0 && (
                <Text style={styles.emptyText}>No hay categorías de este tipo.</Text>
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
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },

  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 10 },
  iconBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: 'rgba(255,255,255,0.1)', alignItems: 'center', justifyContent: 'center' },
  iconText: { color: '#FAFAFA', fontSize: 18, fontWeight: '600' },
  headerRight: { flexDirection: 'row', gap: 12, alignItems: 'center' },
  headerPill: { backgroundColor: 'rgba(255,255,255,0.1)', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20 },
  headerPillText: { color: '#FAFAFA', fontWeight: '600', fontSize: 15 },

  contentScroll: { paddingHorizontal: 20, paddingBottom: 20 },

  amountContainer: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', height: 140, marginBottom: 10 },
  currencySymbol: { fontSize: 44, fontWeight: '700', marginRight: 4, marginTop: 10 },
  amountText: { fontSize: 72, fontWeight: '800', fontVariant: ['tabular-nums'], maxWidth: '90%', letterSpacing: -2 },

  sectionDivider: { marginBottom: 24 },
  sectionLabel: { fontSize: 13, color: '#71717A', fontWeight: '500', marginBottom: 12, marginLeft: 4 },

  attachmentsScroll: { gap: 12, paddingRight: 20 },
  attachmentPill: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.1)', paddingHorizontal: 18, paddingVertical: 14, borderRadius: 20, gap: 10 },
  pillIcon: { fontSize: 18, color: '#FAFAFA' },
  pillText: { fontSize: 16, color: '#FAFAFA', fontWeight: '500' },

  detailsSection: { gap: 12 },
  inputContainer: { backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 16, paddingHorizontal: 18, paddingVertical: 16 },
  textInput: { color: '#FAFAFA', fontSize: 17, letterSpacing: 0 },

  accountsScroll: { gap: 16, paddingRight: 20, paddingBottom: 10 },
  creditCard: { height: 150, borderRadius: 20, overflow: 'hidden', borderWidth: 2, borderColor: 'transparent' },
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
  categoryPillBtn: { backgroundColor: '#3F3F46', paddingHorizontal: 18, paddingVertical: 14, borderRadius: 24 },
  categoryPillBtnText: { color: '#FFFFFF', fontWeight: '600', fontSize: 16 },
  saveBtn: { backgroundColor: '#FAFAFA', paddingHorizontal: 28, paddingVertical: 14, borderRadius: 24 },
  saveBtnText: { color: '#000000', fontWeight: '800', fontSize: 16 },

  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'flex-end' },
  modalBackdropClose: { ...StyleSheet.absoluteFillObject },
  modalContent: { backgroundColor: '#121212', borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24, height: '50%' },
  modalHandle: { width: 40, height: 4, backgroundColor: '#3F3F46', borderRadius: 2, alignSelf: 'center', marginBottom: 20 },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 },
  modalTitle: { color: '#FAFAFA', fontSize: 18, fontWeight: '700' },
  modalCloseBtn: { width: 36, height: 36, backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 18, alignItems: 'center', justifyContent: 'center' },
  modalCloseText: { color: '#FAFAFA', fontSize: 16, fontWeight: '700' },
  categoryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, paddingBottom: 40 },
  modalCatPill: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' },
  modalCatIcon: { fontSize: 18, marginRight: 8 },
  modalCatText: { fontSize: 15, fontWeight: '600' },
  emptyText: { color: '#71717A', fontSize: 15 },
});
