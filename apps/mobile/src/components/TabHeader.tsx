import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Platform } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { Home01Icon } from '@hugeicons/core-free-icons';

let CACHED_HEADER: any = null;
let IS_FETCHING_HEADER = false;
let HEADER_LISTENERS: ((data: any) => void)[] = [];

export default function TabHeader() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const { theme } = useTheme();

  const [householdName, setHouseholdName] = useState(CACHED_HEADER?.householdName || '...');
  const [initial, setInitial] = useState(CACHED_HEADER?.initial || 'U');
  const [members, setMembers] = useState<any[]>(CACHED_HEADER?.members || []);

  useEffect(() => {
    if (!user) return;
    
    if (CACHED_HEADER) {
      setHouseholdName(CACHED_HEADER.householdName);
      setInitial(CACHED_HEADER.initial);
      setMembers(CACHED_HEADER.members);
      return;
    }

    const onData = (data: any) => {
      setHouseholdName(data.householdName);
      setInitial(data.initial);
      setMembers(data.members);
    };
    HEADER_LISTENERS.push(onData);

    if (IS_FETCHING_HEADER) return;
    IS_FETCHING_HEADER = true;

    const fetchHeaderData = async () => {
      try {
        const { data: pData } = await supabase.from('profiles').select('name, household_id').eq('id', user.id).single();
        
        let first = 'U';
        let hName = 'Hogar Principal';
        let mems: any[] = [];

        if (pData?.name) {
          first = pData.name.charAt(0).toUpperCase();
        } else {
          const metaName = user.user_metadata?.full_name || user.user_metadata?.name || user.user_metadata?.display_name;
          const rawName = metaName || user.email?.split('@')[0] || 'U';
          first = rawName.trim().charAt(0).toUpperCase();
        }

        if (pData?.household_id) {
          const hhRes = await supabase.from('households').select('name').eq('id', pData.household_id).single();
          if (hhRes.data?.name) hName = hhRes.data.name;

          const memsRes = await supabase.from('profiles').select('id, name').eq('household_id', pData.household_id);
          if (memsRes.data) mems = memsRes.data;
        }

        CACHED_HEADER = { householdName: hName, initial: first, members: mems };
        HEADER_LISTENERS.forEach(fn => fn(CACHED_HEADER));
        HEADER_LISTENERS = []; // clear listeners after push
      } catch (err) {
      } finally {
        IS_FETCHING_HEADER = false;
      }
    };

    fetchHeaderData();

    return () => {
      HEADER_LISTENERS = HEADER_LISTENERS.filter(fn => fn !== onData);
    };
  }, [user]);

  const AVATAR_COLORS = ['#FAFAFA', '#06B6D4', '#EF4444', '#EAB308', '#8B5CF6', '#10B981'];

  return (
    <View style={[styles.container, { paddingTop: insets.top + (Platform.OS === 'android' ? 12 : 0), backgroundColor: theme.background, borderBottomColor: theme.border }]}>
      <View style={styles.content}>
        <View style={styles.left}>
          <HugeiconsIcon icon={Home01Icon} size={32} color={theme.textMuted} />
          <View style={styles.titlesCol}>
            <Text style={[styles.householdText, { color: theme.text }]}>{householdName}</Text>
            {members.length > 0 && (
              <View style={styles.avatarRow}>
                {members.slice(0, 4).map((m, i) => {
                  const initialMember = m.name ? m.name.charAt(0).toUpperCase() : 'U';
                  return (
                    <View key={m.id} style={[styles.microAvatar, { backgroundColor: AVATAR_COLORS[i % AVATAR_COLORS.length], zIndex: 10 - i, marginLeft: i === 0 ? 0 : -8 }]}>
                      <Text style={styles.microAvatarText}>{initialMember}</Text>
                    </View>
                  );
                })}
                {members.length > 4 && (
                  <View style={[styles.microAvatar, { backgroundColor: '#94A3B8', zIndex: 0, marginLeft: -8 }]}>
                    <Text style={[styles.microAvatarText, { fontSize: 10 }]}>+{members.length - 4}</Text>
                  </View>
                )}
              </View>
            )}
          </View>
        </View>
        <TouchableOpacity style={[styles.avatar, { backgroundColor: theme.primary }]} onPress={() => router.push('/settings' as any)}>
          <Text style={styles.avatarText}>{initial}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    borderBottomWidth: 1,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  left: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  titlesCol: {
    justifyContent: 'center',
  },
  householdText: {
    fontSize: 16,
    fontWeight: '600',
  },
  avatarRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
  microAvatar: {
    width: 22,
    height: 22,
    borderRadius: 11,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
    borderColor: '#09090B',
  },
  microAvatarText: {
    color: '#09090B',
    fontSize: 11,
    fontWeight: '800',
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  avatarText: {
    color: '#FFF',
    fontSize: 16,
    fontWeight: '700',
  }
});
