import React, { createContext, useContext, useState, useEffect } from 'react';
import { useColorScheme } from 'react-native';
import * as SecureStore from 'expo-secure-store';

export type ThemeMode = 'light' | 'dark' | 'system';

interface ThemeColors {
  background: string;
  card: string;
  text: string;
  textMuted: string;
  border: string;
  primary: string;
  danger: string;
  success: string;
  pillBg: string; // for floating menus/search inputs backgrounds
}

export const darkTheme: ThemeColors = {
  background: '#000000', // Pure black replacing the blue gradient
  card: '#121212',       // Dark grey for cards instead of blueish
  text: '#FAFAFA',
  textMuted: '#A1A1AA',
  border: '#27272A',
  primary: '#2563EB',
  danger: '#EF4444',
  success: '#22C55E',
  pillBg: '#18181B',
};

export const lightTheme: ThemeColors = {
  background: '#F4F4F5', // Light grey base
  card: '#FFFFFF',       // Pure white cards
  text: '#18181B',
  textMuted: '#71717A',
  border: '#E4E4E7',
  primary: '#2563EB',
  danger: '#EF4444',
  success: '#22C55E',
  pillBg: '#FFFFFF',
};

interface ThemeContextType {
  theme: ThemeColors;
  isDark: boolean;
  mode: ThemeMode;
  setMode: (mode: ThemeMode) => void;
}

const ThemeContext = createContext<ThemeContextType>({
  theme: darkTheme,
  isDark: true,
  mode: 'system',
  setMode: () => {},
});

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const systemColorScheme = useColorScheme();
  const [mode, setModeState] = useState<ThemeMode>('system');
  const [isMounted, setIsMounted] = useState(false);

  useEffect(() => {
    const loadMode = async () => {
      try {
        const savedMode = await SecureStore.getItemAsync('app-theme-mode');
        if (savedMode === 'light' || savedMode === 'dark' || savedMode === 'system') {
          setModeState(savedMode);
        }
      } catch (e) {
        console.warn('Failed to load theme mode');
      } finally {
        setIsMounted(true);
      }
    };
    loadMode();
  }, []);

  const setMode = async (newMode: ThemeMode) => {
    setModeState(newMode);
    try {
      await SecureStore.setItemAsync('app-theme-mode', newMode);
    } catch (e) {
      console.warn('Failed to save theme mode');
    }
  };

  const isDark = mode === 'system' ? systemColorScheme === 'dark' : mode === 'dark';
  const theme = isDark ? darkTheme : lightTheme;

  if (!isMounted) return null; // Prevent hydration mismatch on start

  return (
    <ThemeContext.Provider value={{ theme, isDark, mode, setMode }}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => useContext(ThemeContext);
