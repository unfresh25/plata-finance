import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Switch, Alert, ScrollView, ActivityIndicator, ActionSheetIOS, Platform, Pressable } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { supabase } from '../src/lib/supabase';
import { useAuth } from '../src/context/AuthContext';
import { useTheme, ThemeMode } from '../src/context/ThemeContext';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { DashboardSquare01Icon, Logout01Icon, Home01Icon, Settings01Icon, MonitorDotIcon, PlusSignIcon, Copy01Icon, UserGroupIcon, Edit02Icon, Coins02Icon, Moon02Icon, Sun02Icon } from '@hugeicons/core-free-icons';
import * as Clipboard from 'expo-clipboard';
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system/legacy';
import { decode } from 'base64-arraybuffer';
import { Image } from 'react-native';
import { forceHeaderUpdate } from '../src/components/TabHeader';
import { PromptModal, PromptConfig } from '../src/components/PromptModal';

export default function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const { theme, mode, setMode } = useTheme();

  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState<any>(null);
  const [household, setHousehold] = useState<any>(null);
  const [members, setMembers] = useState<any[]>([]);
  const [inviteCode, setInviteCode] = useState<string | null>(null);

  // Prompt cross-platform (Alert.prompt no existe en Android).
  const [prompt, setPrompt] = useState<{ config: PromptConfig; onConfirm: (v: string) => void } | null>(null);
  const askPrompt = (config: PromptConfig, onConfirm: (v: string) => void) => setPrompt({ config, onConfirm });

  const [showCurrencyMenu, setShowCurrencyMenu] = useState(false);
  const [showThemeMenu, setShowThemeMenu] = useState(false);

  useEffect(() => {
    const fetchProfile = async () => {
      if (!user) return;
      try {
        const { data: pData } = await supabase.from('profiles').select('*, households(*)').eq('id', user.id).single();
        if (pData) {
          setProfile(pData);
          const hh = pData.households;
          setHousehold(hh);
          if (hh) {
            setInviteCode(hh.invite_code || null);
            // Fetch household members
            const { data: mems } = await supabase.from('profiles').select('id, name, avatar_url').eq('household_id', hh.id);
            setMembers(mems || []);
          }
        }
      } catch (e) {
        console.warn(e);
      } finally {
        setLoading(false);
      }
    };
    fetchProfile();
  }, [user]);

  const handleSignOut = async () => {
    Alert.alert('Cerrar Sesión', '¿Estás seguro de que deseas salir?', [
      { text: 'Cancelar', style: 'cancel' },
      {
        text: 'Sí, salir', style: 'destructive', onPress: async () => {
          await supabase.auth.signOut();
          setTimeout(() => router.replace('/(auth)/login' as any), 100);
        }
      }
    ]);
  };

  const handleCreateHousehold = () => {
    askPrompt(
      { title: 'Nuevo Hogar', message: 'Ingresa el nombre del nuevo hogar:', placeholder: 'Nombre del hogar', confirmLabel: 'Crear' },
      async (name: string) => {
        try {
          // RPC atómica y segura: crea el hogar, vincula el perfil y siembra
          // categorías por defecto en una sola transacción server-side.
          const { data, error } = await supabase.rpc('create_household', { p_name: name });
          if (error) throw error;
          const hh = Array.isArray(data) ? data[0] : data;
          if (hh) {
            Alert.alert('Éxito', `Hogar "${hh.name}" creado correctamente.\nCódigo de invitación: ${hh.invite_code}`);
            setHousehold(hh);
            setInviteCode(hh.invite_code);
            setMembers([{ id: user?.id, name: profile?.name, email: user?.email, avatar_url: profile?.avatar_url }]);
            forceHeaderUpdate({});
          }
        } catch (e: any) {
          Alert.alert('Error', e.message);
        }
      }
    );
  };

  const handleGenerateInviteCode = async () => {
    try {
      const code = Math.random().toString(36).substring(2, 8).toUpperCase();
      const { error } = await supabase.from('households').update({ invite_code: code }).eq('id', household?.id);
      if (error) throw error;
      setInviteCode(code);
      await Clipboard.setStringAsync(code);
      Alert.alert('Código generado', `Tu código de invitación es:\n\n${code}\n\nYa está copiado al portapapeles. Compártelo con tu pareja durante el registro.`);
    } catch (e: any) {
      Alert.alert('Error', e.message);
    }
  };

  const handleJoinHousehold = () => {
    askPrompt(
      { title: 'Unirse a Hogar', message: 'Ingresa el código de invitación:', placeholder: 'CÓDIGO', confirmLabel: 'Unirse', autoCapitalize: 'characters' },
      async (code: string) => {
        try {
          // RPC SECURITY DEFINER: valida el código y vincula el perfil server-side.
          // Evita exponer la tabla households y el UPDATE directo de household_id.
          const { data, error } = await supabase.rpc('join_household', { p_code: code.trim().toUpperCase() });
          if (error) throw error;
          const hh = Array.isArray(data) ? data[0] : data;
          if (!hh) throw new Error('Código de invitación inválido o vencido.');

          Alert.alert('Éxito', `Te has unido exitosamente a "${hh.name}".`);
          setHousehold(hh);
          setInviteCode(hh.invite_code);
          forceHeaderUpdate({});
          const { data: mems } = await supabase.from('profiles').select('id, name, avatar_url').eq('household_id', hh.id);
          setMembers(mems || []);
        } catch (e: any) {
          Alert.alert('Error', e.message);
        }
      }
    );
  };

  const handleCurrencySelect = async (selected: string) => {
    setShowCurrencyMenu(false);
    await supabase.from('profiles').update({ currency: selected }).eq('id', user?.id);
    setProfile({ ...profile, currency: selected });
  };

  const handleThemeSelect = (selectedMode: ThemeMode) => {
    setShowThemeMenu(false);
    setMode(selectedMode);
  };

  // Safe username extraction
  const userName = user?.user_metadata?.full_name || user?.user_metadata?.name || user?.user_metadata?.display_name || profile?.name || 'Usuario';
  const initial = userName.charAt(0).toUpperCase();

  const handleEditName = () => {
    askPrompt(
      { title: 'Editar Nombre', message: 'Ingresa tu nuevo nombre para mostrar:', placeholder: 'Tu nombre', defaultValue: userName, confirmLabel: 'Guardar' },
      async (newName: string) => {
        try {
          const finalName = newName.trim();
          // Actualiza metadata de Auth y la tabla profiles (ambos permitidos por RLS: perfil propio).
          await supabase.auth.updateUser({ data: { full_name: finalName } });
          await supabase.from('profiles').update({ name: finalName }).eq('id', user?.id);
          setProfile({ ...profile, name: finalName });
          Alert.alert('Éxito', 'Nombre actualizado correctamente.');
        } catch (e: any) {
          Alert.alert('Error', e.message);
        }
      }
    );
  };

  const handleChangeAvatar = async () => {
    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.5,
      });

      if (!result.canceled && result.assets[0].uri) {
        setLoading(true);
        const { uri } = result.assets[0];
        const fileExt = uri.substring(uri.lastIndexOf('.'));
        const fileName = `${user?.id}-${Date.now()}${fileExt}`;

        // Read file in base64 using expo-file-system (avoids fetch().blob() bug on iOS)
        const base64 = await FileSystem.readAsStringAsync(uri, { encoding: 'base64' });

        // Subir a storage 'avatars'
        const { error: uploadError } = await supabase.storage.from('avatars').upload(fileName, decode(base64), {
          contentType: 'image/jpeg',
          upsert: true
        });

        if (uploadError) throw new Error(`Error subiendo imagen: ${uploadError.message}. Asegúrate de que el bucket 'avatars' exista y sea público.`);

        // Obtener la URL pública y agregar un cache-buster para forzar actualización visual y en cache
        const { data: { publicUrl } } = supabase.storage.from('avatars').getPublicUrl(fileName);
        const publicUrlWithCacheBust = `${publicUrl}?t=${Date.now()}`;

        // Actualizar la tabla profiles con la url
        const { error: dbError } = await supabase.from('profiles').update({ avatar_url: publicUrlWithCacheBust }).eq('id', user?.id);
        if (dbError) throw dbError;

        setProfile({ ...profile, avatar_url: publicUrlWithCacheBust });
        forceHeaderUpdate({ avatarUrl: publicUrlWithCacheBust, initial });

        Alert.alert('Éxito', 'Tu foto de perfil ha sido actualizada y cacheada en el dispositivo.');
      }
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={[styles.container, { paddingTop: Math.max(insets.top, 12), backgroundColor: theme.background }]}>
      <View style={[styles.header, { borderBottomColor: theme.border }]}>
        <Text style={[styles.title, { color: theme.text }]}>Ajustes</Text>
        <TouchableOpacity onPress={() => router.back()}>
          <Text style={[styles.closeBtn, { color: theme.primary }]}>Hecho</Text>
        </TouchableOpacity>
      </View>

      <ScrollView contentContainerStyle={styles.content}>

        {/* User Card */}
        <View style={[styles.userCard, { backgroundColor: theme.card, borderColor: theme.border }]}>
          <TouchableOpacity onPress={handleChangeAvatar}>
            <View style={[styles.avatar, { backgroundColor: theme.primary }]}>
              {profile?.avatar_url ? (
                <Image source={{ uri: profile.avatar_url }} style={{ width: '100%', height: '100%', borderRadius: 28 }} />
              ) : (
                <Text style={styles.avatarText}>{initial}</Text>
              )}
            </View>
          </TouchableOpacity>
          <TouchableOpacity style={styles.userInfo} onPress={handleEditName}>
            <Text style={[styles.userName, { color: theme.text }]}>{userName} <HugeiconsIcon icon={Edit02Icon} size={14} color={theme.textMuted} /></Text>
            <Text style={[styles.userEmail, { color: theme.textMuted }]}>{user?.email}</Text>
          </TouchableOpacity>
        </View>

        {/* Household Section */}
        <Text style={[styles.sectionTitle, { color: theme.textMuted }]}>TU HOGAR</Text>
        <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
          <View style={styles.row}>
            <View style={styles.rowLeft}>
              <HugeiconsIcon icon={Home01Icon} size={24} color={theme.textMuted} />
              <View style={{ marginLeft: 12 }}>
                <Text style={[styles.rowTitle, { color: theme.text }]}>{household?.name || 'Sin Hogar'}</Text>
                <Text style={[styles.rowSubtitle, { color: theme.textMuted }]}>Hogar Actual</Text>
              </View>
            </View>
          </View>
          <View style={[styles.divider, { backgroundColor: theme.border }]} />
          {/* Invite Code */}
          {household && (
            <TouchableOpacity style={styles.row} onPress={handleGenerateInviteCode}>
              <View style={styles.rowLeft}>
                <HugeiconsIcon icon={Copy01Icon} size={24} color={theme.primary} />
                <View style={{ marginLeft: 12 }}>
                  <Text style={[styles.rowTitle, { color: theme.primary }]}>Código de Invitación</Text>
                  {inviteCode
                    ? <Text style={[styles.rowSubtitle, { color: theme.textMuted }]}>{inviteCode} — toca para regenerar</Text>
                    : <Text style={[styles.rowSubtitle, { color: theme.textMuted }]}>Toca para generar y compartir</Text>
                  }
                </View>
              </View>
            </TouchableOpacity>
          )}
          <View style={[styles.divider, { backgroundColor: theme.border }]} />
          <TouchableOpacity style={styles.row} onPress={handleCreateHousehold}>
            <View style={styles.rowLeft}>
              <HugeiconsIcon icon={PlusSignIcon} size={24} color={theme.text} />
              <Text style={[styles.rowTitle, { marginLeft: 12, color: theme.text }]}>Crear Nuevo Hogar</Text>
            </View>
          </TouchableOpacity>
          <View style={[styles.divider, { backgroundColor: theme.border }]} />
          <TouchableOpacity style={styles.row} onPress={handleJoinHousehold}>
            <View style={styles.rowLeft}>
              <HugeiconsIcon icon={UserGroupIcon} size={24} color={theme.text} />
              <Text style={[styles.rowTitle, { marginLeft: 12, color: theme.text }]}>Unirse a un Hogar Existente</Text>
            </View>
          </TouchableOpacity>
        </View>

        {/* Members */}
        {members.length > 0 && (
          <>
            <Text style={[styles.sectionTitle, { color: theme.textMuted }]}>MIEMBROS</Text>
            <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
              {members.map((m, i) => (
                <View key={m.id} style={[styles.row, i < members.length - 1 && { borderBottomWidth: 1, borderBottomColor: theme.border }]}>
                  <View style={styles.rowLeft}>
                    <View style={[styles.memberAvatar, { backgroundColor: theme.pillBg }]}>
                      {m.avatar_url ? (
                        <Image source={{ uri: m.avatar_url }} style={{ width: '100%', height: '100%', borderRadius: 18 }} />
                      ) : (
                        <Text style={[styles.memberAvatarText, { color: theme.text }]}>{(m.name || m.email || '?').charAt(0).toUpperCase()}</Text>
                      )}
                    </View>
                    <View style={{ marginLeft: 12 }}>
                      <Text style={[styles.rowTitle, { color: theme.text }]}>{m.name || 'Usuario'}</Text>
                      <Text style={[styles.rowSubtitle, { color: theme.textMuted }]}>{m.email}</Text>
                    </View>
                  </View>
                  {m.id === user?.id && <Text style={[styles.youBadge, { backgroundColor: theme.primary, color: '#FFF' }]}>Tú</Text>}
                </View>
              ))}
            </View>
          </>
        )}

        {/* Settings Section */}
        <Text style={[styles.sectionTitle, { color: theme.textMuted }]}>PREFERENCIAS</Text>
        <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border, overflow: 'visible' }]}>

          <TouchableOpacity style={[styles.row, { borderBottomWidth: 1, borderBottomColor: theme.border }]} onPress={() => router.push('/categories' as any)}>
            <View style={styles.rowLeft}>
              <HugeiconsIcon icon={DashboardSquare01Icon} size={24} color={theme.textMuted} />
              <Text style={[styles.rowTitle, { marginLeft: 12, color: theme.text }]}>Gestionar Categorías</Text>
            </View>
            <Text style={[styles.rowValue, { color: theme.textMuted }]}>›</Text>
          </TouchableOpacity>

          <View style={{ zIndex: showCurrencyMenu ? 2 : 1 }}>
            <TouchableOpacity style={[styles.row, { borderBottomWidth: 1, borderBottomColor: theme.border }]} onPress={() => setShowCurrencyMenu(!showCurrencyMenu)}>
              <View style={styles.rowLeft}>
                <HugeiconsIcon icon={Coins02Icon} size={24} color={theme.textMuted} />
                <Text style={[styles.rowTitle, { marginLeft: 12, color: theme.text }]}>Divisa Principal</Text>
              </View>
              <Text style={[styles.rowValue, { color: theme.text }]}>{profile?.currency || 'USD'} ▾</Text>
            </TouchableOpacity>

            {showCurrencyMenu && (
              <>
                <Pressable style={styles.dropdownOverlay} onPress={() => setShowCurrencyMenu(false)} />
                <View style={[styles.dropdown, { top: 50, right: 16, backgroundColor: theme.card, borderColor: theme.border }]}>
                  <View style={{ borderRadius: 14, overflow: 'hidden', maxHeight: 240 }}>
                    <ScrollView nestedScrollEnabled showsVerticalScrollIndicator={false}>
                      {['USD', 'COP', 'EUR', 'MXN', 'ARS', 'CLP', 'PEN'].map((c, i) => (
                        <TouchableOpacity key={c} style={[styles.dropdownItem, i > 0 && { borderTopWidth: 1, borderTopColor: theme.border }]} onPress={() => handleCurrencySelect(c)}>
                          <Text style={[styles.dropdownText, { color: profile?.currency === c ? theme.primary : theme.text }]}>{c}</Text>
                        </TouchableOpacity>
                      ))}
                    </ScrollView>
                  </View>
                </View>
              </>
            )}
          </View>

          <View style={{ zIndex: showThemeMenu ? 2 : 1 }}>
            <TouchableOpacity style={styles.row} onPress={() => setShowThemeMenu(!showThemeMenu)}>
              <View style={styles.rowLeft}>
                <HugeiconsIcon icon={mode === 'dark' ? Moon02Icon : mode === 'light' ? Sun02Icon : MonitorDotIcon} size={24} color={theme.textMuted} />
                <Text style={[styles.rowTitle, { marginLeft: 12, color: theme.text }]}>Apariencia</Text>
              </View>
              <Text style={[styles.rowValue, { color: theme.text }]}>
                {mode === 'dark' ? 'Oscuro' : mode === 'light' ? 'Claro' : 'Sistema'} ▾
              </Text>
            </TouchableOpacity>

            {showThemeMenu && (
              <>
                <Pressable style={styles.dropdownOverlay} onPress={() => setShowThemeMenu(false)} />
                <View style={[styles.dropdown, { bottom: 50, right: 16, backgroundColor: theme.card, borderColor: theme.border }]}>
                  {[
                    { val: 'system', label: 'Sistema' },
                    { val: 'light', label: 'Claro' },
                    { val: 'dark', label: 'Oscuro' }
                  ].map((m, i) => (
                    <TouchableOpacity key={m.val} style={[styles.dropdownItem, i > 0 && { borderTopWidth: 1, borderTopColor: theme.border }]} onPress={() => handleThemeSelect(m.val as ThemeMode)}>
                      <Text style={[styles.dropdownText, { color: mode === m.val ? theme.primary : theme.text }]}>{m.label}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </>
            )}
          </View>
        </View>

        {/* Destructive Section */}
        <View style={[styles.card, { marginTop: 32, backgroundColor: theme.card, borderColor: theme.border }]}>
          <TouchableOpacity style={styles.row} onPress={handleSignOut}>
            <View style={styles.rowLeft}>
              <HugeiconsIcon icon={Logout01Icon} size={24} color={theme.danger} />
              <Text style={[styles.rowTitle, { marginLeft: 12, color: theme.danger }]}>Cerrar Sesión</Text>
            </View>
          </TouchableOpacity>
        </View>

        <Text style={styles.versionText}>Plata v1.0.0</Text>

      </ScrollView>

      {prompt && (
        <PromptModal
          visible={!!prompt}
          config={prompt.config}
          onCancel={() => setPrompt(null)}
          onConfirm={(value) => {
            const cb = prompt.onConfirm;
            setPrompt(null);
            cb(value);
          }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { justifyContent: 'center', alignItems: 'center' },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 16, borderBottomWidth: 1 },
  title: { fontSize: 20, fontWeight: '700' },
  closeBtn: { fontSize: 16, fontWeight: '600' },
  content: { padding: 20, paddingBottom: 60 },

  userCard: { flexDirection: 'row', alignItems: 'center', padding: 20, borderRadius: 16, borderWidth: 1, marginBottom: 32 },
  avatar: { width: 56, height: 56, borderRadius: 28, justifyContent: 'center', alignItems: 'center', marginRight: 16 },
  avatarText: { fontSize: 24, fontWeight: '700', color: '#FFFFFF' },
  userInfo: { flex: 1 },
  userName: { fontSize: 18, fontWeight: '700', marginBottom: 4 },
  userEmail: { fontSize: 14 },

  sectionTitle: { fontSize: 13, fontWeight: '600', marginBottom: 8, marginLeft: 8, letterSpacing: 1 },
  card: { borderRadius: 16, borderWidth: 1, overflow: 'hidden', marginBottom: 24 },
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: 16 },
  rowLeft: { flexDirection: 'row', alignItems: 'center' },
  rowTitle: { fontSize: 16, fontWeight: '500' },
  rowSubtitle: { fontSize: 13, marginTop: 2 },
  rowValue: { fontSize: 16 },
  divider: { height: 1, marginLeft: 52 },

  versionText: { textAlign: 'center', fontSize: 12, marginTop: 16 },
  memberAvatar: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center' },
  memberAvatarText: { fontSize: 16, fontWeight: '700' },
  youBadge: { fontSize: 12, fontWeight: '600', paddingHorizontal: 8, paddingVertical: 2, borderRadius: 8 },

  dropdownOverlay: { position: 'absolute', top: -500, right: -500, bottom: -500, left: -500, zIndex: 90 },
  dropdown: { position: 'absolute', borderRadius: 14, borderWidth: 1, minWidth: 140, zIndex: 100, shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.4, shadowRadius: 12 },
  dropdownItem: { paddingHorizontal: 16, paddingVertical: 14 },
  dropdownText: { fontSize: 15, fontWeight: '600' },
});
