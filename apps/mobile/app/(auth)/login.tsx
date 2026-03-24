import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ActivityIndicator, KeyboardAvoidingView, Platform, Alert } from 'react-native';
import { supabase } from '../../src/lib/supabase';

import { useRouter } from 'expo-router';
import { useTheme } from '../../src/context/ThemeContext';

export default function LoginScreen() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { theme } = useTheme();

  const handleAuth = async () => {
    if (!email || !password) {
      Alert.alert('Error', 'Por favor ingresa un correo y contraseña válidos.');
      return;
    }
    
    setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    
    if (error) {
      Alert.alert('Error', error.message);
    }
    setLoading(false);
  };

  return (
    <KeyboardAvoidingView 
      style={[styles.container, { backgroundColor: theme.background }]} 
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.content}>
        <View style={styles.header}>
          <Text style={[styles.title, { color: theme.text }]}>Jojo's Finance</Text>
          <Text style={[styles.subtitle, { color: theme.textMuted }]}>Gestiona tus finanzas en pareja</Text>
        </View>

        <View style={styles.form}>
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
        </View>

        <View style={styles.actions}>
          <TouchableOpacity 
            style={[styles.buttonPrimary, { backgroundColor: theme.primary }]} 
            onPress={handleAuth}
            disabled={loading}
          >
            {loading ? <ActivityIndicator color="#FFF" /> : <Text style={styles.buttonTextPrimary}>Iniciar Sesión</Text>}
          </TouchableOpacity>

          <TouchableOpacity 
            style={[styles.buttonSecondary, { borderColor: theme.border }]} 
            onPress={() => router.push('/(auth)/register')}
            disabled={loading}
          >
            <Text style={[styles.buttonTextSecondary, { color: theme.text }]}>Crear Cuenta</Text>
          </TouchableOpacity>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  content: {
    flex: 1,
    padding: 24,
    justifyContent: 'center',
  },
  header: {
    marginBottom: 48,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    color: '#FAFAFA',
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 16,
    color: '#A1A1AA',
    marginTop: 8,
  },
  form: {
    gap: 16,
    marginBottom: 32,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    color: '#E4E4E7',
    marginBottom: -8,
  },
  inputContainer: {
    height: 52,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#27272A',
    paddingHorizontal: 16,
    justifyContent: 'center',
  },
  input: {
    flex: 1,
    color: '#FAFAFA',
    fontSize: 15,
  },
  actions: {
    gap: 12,
  },
  buttonPrimary: {
    height: 52,
    backgroundColor: '#2563EB',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonTextPrimary: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  buttonSecondary: {
    height: 52,
    backgroundColor: 'transparent',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#27272A',
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonTextSecondary: {
    color: '#E4E4E7',
    fontSize: 16,
    fontWeight: '600',
  },
});
