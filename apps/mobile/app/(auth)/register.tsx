import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ActivityIndicator, KeyboardAvoidingView, Platform, Alert, ScrollView } from 'react-native';
import { supabase } from '../../src/lib/supabase';
import { useRouter } from 'expo-router';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ArrowLeft01Icon } from '@hugeicons/core-free-icons';
import * as SecureStore from 'expo-secure-store';
import { useTheme } from '../../src/context/ThemeContext';

export default function RegisterScreen() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [loading, setLoading] = useState(false);
  const { theme } = useTheme();

  const handleRegister = async () => {
    if (!name || !email || !password) {
      Alert.alert('Error', 'Por favor completa todos los campos.');
      return;
    }

    setLoading(true);
    const { data: signUpData, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { full_name: name } }
    });

    if (error) {
      Alert.alert('Error', error.message);
      setLoading(false);
      return;
    }

    // If an invite code was provided, save it locally to process after login
    // This bypasses RLS issues during registration before the profile is fully established
    if (inviteCode.trim() && signUpData?.user) {
      const code = inviteCode.trim().toUpperCase();
      try {
        await SecureStore.setItemAsync('pending_invite_code', code);
      } catch (e) {
        console.error('Error saving invite code locally:', e);
      }
    }

    Alert.alert('\u00a1Cuenta creada!', 'Ya puedes iniciar sesión.');
    router.back();
    setLoading(false);
  };

  return (
    <KeyboardAvoidingView
      style={[styles.container, { backgroundColor: theme.background }]}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView contentContainerStyle={styles.content}>
        <TouchableOpacity style={styles.backBtn} onPress={() => router.back()}>
          <HugeiconsIcon icon={ArrowLeft01Icon} size={24} color={theme.textMuted} />
        </TouchableOpacity>

        <View style={styles.header}>
          <Text style={[styles.title, { color: theme.text }]}>Crea tu cuenta</Text>
          <Text style={[styles.subtitle, { color: theme.textMuted }]}>Empieza a gestionar tu dinero en pareja hoy mismo.</Text>
        </View>

        <View style={styles.form}>
          <Text style={[styles.label, { color: theme.textMuted }]}>Nombre completo o apodo</Text>
          <View style={[styles.inputContainer, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <TextInput
              style={[styles.input, { color: theme.text }]}
              placeholder="Ej. Esteban"
              placeholderTextColor={theme.textMuted}
              value={name}
              onChangeText={setName}
            />
          </View>

          <Text style={[styles.label, { color: theme.textMuted }]}>Correo electrónico</Text>
          <View style={[styles.inputContainer, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <TextInput
              style={[styles.input, { color: theme.text }]}
              placeholder="tu@email.com"
              placeholderTextColor={theme.textMuted}
              value={email}
              onChangeText={setEmail}
              autoCapitalize="none"
              keyboardType="email-address"
            />
          </View>

          <Text style={[styles.label, { color: theme.textMuted }]}>Contraseña</Text>
          <View style={[styles.inputContainer, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <TextInput
              style={[styles.input, { color: theme.text }]}
              placeholder="••••••••"
              placeholderTextColor={theme.textMuted}
              value={password}
              onChangeText={setPassword}
              secureTextEntry
            />
          </View>

          <Text style={[styles.label, { color: theme.textMuted }]}>Código de hogar (opcional)</Text>
          <Text style={[styles.label, { fontSize: 12, color: theme.textMuted, marginTop: -12, marginBottom: -8 }]}>Si tu pareja ya tiene una cuenta, ingresa su código de hogar para unirte.</Text>
          <View style={[styles.inputContainer, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <TextInput
              style={[styles.input, { color: theme.text }]}
              placeholder="Ej: AB12XY"
              placeholderTextColor={theme.textMuted}
              value={inviteCode}
              onChangeText={setInviteCode}
              autoCapitalize="characters"
              maxLength={6}
            />
          </View>
        </View>

        <View style={styles.actions}>
          <TouchableOpacity
            style={[styles.buttonPrimary, { backgroundColor: theme.primary }]}
            onPress={handleRegister}
            disabled={loading}
          >
            {loading ? <ActivityIndicator color="#FFF" /> : <Text style={styles.buttonTextPrimary}>Crear cuenta</Text>}
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000000' },
  backBtn: { marginTop: 60, marginBottom: 20 },
  content: { padding: 24, justifyContent: 'center' },
  header: { marginBottom: 48 },
  title: { fontSize: 32, fontWeight: '700', color: '#FAFAFA', letterSpacing: -0.5 },
  subtitle: { fontSize: 16, color: '#A1A1AA', marginTop: 8 },
  form: { gap: 16, marginBottom: 32 },
  label: { fontSize: 14, fontWeight: '500', color: '#E4E4E7', marginBottom: -8 },
  inputContainer: { height: 52, backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 12, borderWidth: 1, borderColor: '#27272A', paddingHorizontal: 16, justifyContent: 'center' },
  input: { flex: 1, color: '#FAFAFA', fontSize: 15 },
  actions: { gap: 12 },
  buttonPrimary: { height: 52, backgroundColor: '#2563EB', borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  buttonTextPrimary: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
});
