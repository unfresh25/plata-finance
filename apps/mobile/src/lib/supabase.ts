import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';
import Constants from 'expo-constants';

const ChunkedSecureStoreAdapter = {
  getItem: async (key: string) => {
    try {
      const partsStr = await SecureStore.getItemAsync(key + '_parts');
      if (partsStr) {
        const parts = parseInt(partsStr, 10);
        let value = '';
        for (let i = 0; i < parts; i++) {
          const chunk = await SecureStore.getItemAsync(`${key}_${i}`);
          if (chunk) value += chunk;
        }
        return value;
      }
      return await SecureStore.getItemAsync(key);
    } catch { return null; }
  },
  setItem: async (key: string, value: string) => {
    try {
      if (value.length > 2000) {
        const chunks = Math.ceil(value.length / 2000);
        await SecureStore.setItemAsync(key + '_parts', chunks.toString());
        for (let i = 0; i < chunks; i++) {
          await SecureStore.setItemAsync(`${key}_${i}`, value.substring(i * 2000, (i + 1) * 2000));
        }
      } else {
        await SecureStore.deleteItemAsync(key + '_parts');
        await SecureStore.setItemAsync(key, value);
      }
    } catch {}
  },
  removeItem: async (key: string) => {
    try {
      const partsStr = await SecureStore.getItemAsync(key + '_parts');
      if (partsStr) {
        const parts = parseInt(partsStr, 10);
        for (let i = 0; i < parts; i++) {
          await SecureStore.deleteItemAsync(`${key}_${i}`);
        }
        await SecureStore.deleteItemAsync(key + '_parts');
      }
      await SecureStore.deleteItemAsync(key);
    } catch {}
  },
};

const supabaseUrl = Constants.expoConfig?.extra?.SUPABASE_URL || process.env.EXPO_PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = Constants.expoConfig?.extra?.SUPABASE_ANON_KEY || process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || '';

export const supabase = createClient<any>(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: ChunkedSecureStoreAdapter,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
