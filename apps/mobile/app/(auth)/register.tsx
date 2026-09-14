import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ActivityIndicator, KeyboardAvoidingView, Platform, Alert, ScrollView, Image } from 'react-native';
import { supabase } from '../../src/lib/supabase';
import * as WebBrowser from 'expo-web-browser';
import * as Linking from 'expo-linking';
import { useRouter } from 'expo-router';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ArrowLeft01Icon, GoogleIcon, AppleIcon } from '@hugeicons/core-free-icons';

WebBrowser.maybeCompleteAuthSession();
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

  const handleOAuth = async (provider: 'google' | 'apple') => {
    setLoading(true);
    try {
      const redirectUrl = Linking.createURL('/(tabs)');
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider,
        options: {
          redirectTo: redirectUrl,
          skipBrowserRedirect: true,
        },
      });

      if (error) throw error;

      if (data?.url) {
        const res = await WebBrowser.openAuthSessionAsync(data.url, redirectUrl);
        if (res.type === 'success' && res.url) {
          // Supabase JS takes care of parsing the URL and saving the session
        }
      }
    } catch (e: any) {
      Alert.alert('Error Auth', e.message);
    } finally {
      setLoading(false);
    }
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
          <Image source={require('../../assets/icon.png')} style={styles.logo} />
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

          {/* === OAUTH DESHABILITADO TEMPORALMENTE ===
          <View style={styles.dividerRow}>
            <View style={[styles.dividerLine, { backgroundColor: theme.border }]} />
            <Text style={[styles.dividerText, { color: theme.textMuted }]}>O</Text>
            <View style={[styles.dividerLine, { backgroundColor: theme.border }]} />
          </View>

          <TouchableOpacity 
            style={[styles.providerButton, { backgroundColor: theme.pillBg, borderColor: theme.border }]} 
            onPress={() => handleOAuth('google')}
            disabled={loading}
          >
            <HugeiconsIcon icon={GoogleIcon} size={20} color={theme.text} />
            <Text style={[styles.providerText, { color: theme.text }]}>Registrarte con Google</Text>
          </TouchableOpacity>

          {Platform.OS === 'ios' && (
            <TouchableOpacity 
              style={[styles.providerButton, { backgroundColor: theme.pillBg, borderColor: theme.border }]} 
              onPress={() => handleOAuth('apple')}
              disabled={loading}
            >
              <HugeiconsIcon icon={AppleIcon} size={20} color={theme.text} />
              <Text style={[styles.providerText, { color: theme.text }]}>Registrarte con Apple</Text>
            </TouchableOpacity>
          )}
          */}

        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  backBtn: { marginTop: 60, marginBottom: 20 },
  content: { padding: 24, justifyContent: 'center' },
  header: { marginBottom: 40, alignItems: 'center' },
  logo: { width: 72, height: 72, borderRadius: 18, marginBottom: 16 },
  title: { fontSize: 32, fontWeight: '700', letterSpacing: -0.5, textAlign: 'center' },
  subtitle: { fontSize: 16, marginTop: 8, textAlign: 'center' },
  form: { gap: 16, marginBottom: 32 },
  label: { fontSize: 14, fontWeight: '500', marginBottom: -8 },
  inputContainer: { height: 52, borderRadius: 12, borderWidth: 1, paddingHorizontal: 16, justifyContent: 'center' },
  input: { flex: 1, fontSize: 15 },
  actions: { gap: 12 },
  buttonPrimary: { height: 52, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  buttonTextPrimary: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  dividerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 16,
  },
  dividerLine: {
    flex: 1,
    height: 1,
  },
  dividerText: {
    marginHorizontal: 16,
    fontSize: 14,
    fontWeight: '500',
  },
  providerButton: {
    height: 52,
    borderRadius: 12,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  providerText: {
    fontSize: 16,
    fontWeight: '600',
  }
});
