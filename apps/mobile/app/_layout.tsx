import { Stack, useRouter, useSegments } from 'expo-router';
import { useEffect, useState } from 'react';
import * as SecureStore from 'expo-secure-store';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AuthProvider, useAuth } from '../src/context/AuthContext';
import { ThemeProvider } from '../src/context/ThemeContext';
import { wrapWithSentry } from '../src/lib/sentry';
import { View, ActivityIndicator } from 'react-native';

function RootNavigation() {
  const { initialized, user } = useAuth();
  const segments = useSegments();
  const router = useRouter();
  const [checkedOnboarding, setCheckedOnboarding] = useState(false);
  const [hasSeenOnboarding, setHasSeenOnboarding] = useState(false);

  useEffect(() => {
    SecureStore.getItemAsync('has_seen_onboarding').then(val => {
      setHasSeenOnboarding(val === 'true');
      setCheckedOnboarding(true);
    }).catch(() => {
      setHasSeenOnboarding(false);
      setCheckedOnboarding(true);
    });
  }, []);

  useEffect(() => {
    if (!initialized || !checkedOnboarding) return;

    const inAuthGroup = segments[0] === '(auth)';
    const inOnboarding = segments[0] === 'onboarding';

    if (!user) {
      // Only send to onboarding if they haven't seen it AND they're not already
      // in the auth flow (e.g., after pressing "Empezar" from onboarding)
      if (!hasSeenOnboarding && !inOnboarding && !inAuthGroup) {
        router.replace('/onboarding');
      } else if (!inOnboarding && !inAuthGroup) {
        router.replace('/(auth)/login');
      }
    } else if (user) {
      if (inAuthGroup || inOnboarding) {
        router.replace('/(tabs)');
      }
    }
  }, [user, initialized, segments, checkedOnboarding, hasSeenOnboarding]);

  if (!initialized || !checkedOnboarding) {
    return (
      <View style={{ flex: 1, backgroundColor: '#09090B', alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator size="large" color="#2563EB" />
      </View>
    );
  }

  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: '#09090B' }, animation: 'fade' }}>
      <Stack.Screen name="onboarding" />
      <Stack.Screen name="(auth)" />
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="add-transaction" options={{ presentation: 'modal' }} />
      <Stack.Screen name="add-account" options={{ presentation: 'modal' }} />

      <Stack.Screen name="settings" options={{ presentation: 'modal' }} />
      <Stack.Screen name="categories" options={{ presentation: 'modal' }} />
      <Stack.Screen name="category/[id]" options={{ presentation: 'modal' }} />
      <Stack.Screen name="edit-transaction" options={{ presentation: 'modal' }} />
      <Stack.Screen name="edit-account" options={{ presentation: 'modal' }} />
      <Stack.Screen name="add-recurring" options={{ presentation: 'modal' }} />
      <Stack.Screen name="add-savings-goal" options={{ presentation: 'modal' }} />
      <Stack.Screen name="edit-savings-goal" options={{ presentation: 'modal' }} />
      <Stack.Screen name="goal/[id]" options={{ presentation: 'transparentModal', animation: 'fade', contentStyle: { backgroundColor: 'transparent' } }} />
      <Stack.Screen name="add-debt" options={{ presentation: 'modal' }} />
      <Stack.Screen name="edit-debt" options={{ presentation: 'modal' }} />
      <Stack.Screen name="debt/[id]" options={{ presentation: 'transparentModal', animation: 'fade', contentStyle: { backgroundColor: 'transparent' } }} />
      <Stack.Screen name="add-budget" options={{ presentation: 'modal' }} />
      <Stack.Screen name="add-shopping-list" options={{ presentation: 'modal' }} />
      <Stack.Screen name="shopping-list/[id]" options={{ presentation: 'card' }} />
      <Stack.Screen name="transaction/[id]" options={{ presentation: 'transparentModal', animation: 'fade', contentStyle: { backgroundColor: 'transparent' } }} />
      <Stack.Screen name="account/[id]" options={{ presentation: 'transparentModal', animation: 'fade', contentStyle: { backgroundColor: 'transparent' } }} />
      <Stack.Screen name="recurring/[id]" options={{ presentation: 'transparentModal', animation: 'fade', contentStyle: { backgroundColor: 'transparent' } }} />
    </Stack>
  );
}

function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <ThemeProvider>
        <SafeAreaProvider>
          <AuthProvider>
            <RootNavigation />
          </AuthProvider>
        </SafeAreaProvider>
      </ThemeProvider>
    </GestureHandlerRootView>
  );
}

// Envuelve el root con Sentry si está activo (no-op si no hay DSN / dependencia).
export default wrapWithSentry(RootLayout);
