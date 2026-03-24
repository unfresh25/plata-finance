import { Tabs, useRouter } from 'expo-router';
import { Platform, View, TouchableOpacity, StyleSheet, Text } from 'react-native';
import { useTheme } from '../../src/context/ThemeContext';
import { HugeiconsIcon } from '@hugeicons/react-native';
import {
  Home01Icon,
  ArrowUpDownIcon,
  Calendar01Icon,
  Wallet01Icon,
  ChartLineData01Icon,
} from '@hugeicons/core-free-icons';

const ACTIVE_COLOR = '#2563EB';
const INACTIVE_COLOR = '#71717A';

import FloatingMenu from '../../src/components/FloatingMenu';
import TabHeader from '../../src/components/TabHeader';

export default function TabsLayout() {
  const router = useRouter();
  const { theme } = useTheme();

  return (
    <View style={{ flex: 1, backgroundColor: theme.background }}>
      <Tabs
        screenOptions={{
          header: () => <TabHeader />,
          headerShown: true,
          tabBarStyle: {
            backgroundColor: theme.card,
            borderTopColor: theme.border,
            height: Platform.OS === 'ios' ? 88 : 64,
            paddingBottom: Platform.OS === 'ios' ? 24 : 16,
            paddingTop: 8,
          },
          tabBarActiveTintColor: ACTIVE_COLOR,
          tabBarInactiveTintColor: INACTIVE_COLOR,
          tabBarLabelStyle: {
            fontFamily: 'IBM Plex Sans',
            fontSize: 10,
            fontWeight: '500',
          },
        }}
      >
        <Tabs.Screen
          name="index"
          options={{
            title: 'Inicio',
            tabBarIcon: ({ color, size }) => <HugeiconsIcon icon={Home01Icon} color={color} size={size} />,
          }}
        />
        <Tabs.Screen
          name="transactions"
          options={{
            title: 'Movimientos',
            tabBarIcon: ({ color, size }) => <HugeiconsIcon icon={ArrowUpDownIcon} color={color} size={size} />,
          }}
        />
        <Tabs.Screen
          name="calendar"
          options={{
            title: 'Calendario',
            tabBarIcon: ({ color, size }) => <HugeiconsIcon icon={Calendar01Icon} color={color} size={size} />,
          }}
        />
        <Tabs.Screen
          name="finances"
          options={{
            title: 'Finanzas',
            tabBarIcon: ({ color, size }) => <HugeiconsIcon icon={Wallet01Icon} color={color} size={size} />,
          }}
        />
        <Tabs.Screen
          name="reports"
          options={{
            title: 'Reportes',
            tabBarIcon: ({ color, size }) => <HugeiconsIcon icon={ChartLineData01Icon} color={color} size={size} />,
          }}
        />
      </Tabs>

      <FloatingMenu />
    </View>
  );
}
