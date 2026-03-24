import { Stack, useRouter, useSegments } from 'expo-router';
import { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AuthProvider, useAuth } from '../src/context/AuthContext';
import { ThemeProvider } from '../src/context/ThemeContext';
import { View, ActivityIndicator } from 'react-native';

function RootNavigation() {
  const { initialized, user } = useAuth();
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    if (!initialized) return;

    const inAuthGroup = segments[0] === '(auth)';

    if (!user && !inAuthGroup) {
      router.replace('/(auth)/login');
    } else if (user && inAuthGroup) {
      router.replace('/(tabs)');
    }
  }, [user, initialized, segments]);

  if (!initialized) {
    return (
      <View style={{ flex: 1, backgroundColor: '#09090B', alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator size="large" color="#2563EB" />
      </View>
    );
  }

  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: '#09090B' }, animation: 'fade' }}>
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

export default function RootLayout() {
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
