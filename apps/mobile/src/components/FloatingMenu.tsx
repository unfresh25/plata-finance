import React, { useState, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Dimensions, Pressable, Platform, Animated } from 'react-native';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { useRouter } from 'expo-router';
import {
  ArrowUpDownIcon,
  Calendar01Icon,
  Wallet01Icon,
  MoneySend01Icon,
  Target01Icon,
  ShoppingCart01Icon,
  Chart01Icon
} from '@hugeicons/core-free-icons';

const { width, height } = Dimensions.get('window');

const actions = [
  { id: 'budget', label: 'Presupuesto', icon: Chart01Icon, color: '#2563EB', route: '/add-budget' },
  { id: 'list', label: 'Lista de compras', icon: ShoppingCart01Icon, color: '#2563EB', route: '/add-shopping-list' },
  { id: 'goal', label: 'Meta de ahorro', icon: Target01Icon, color: '#2563EB', route: '/add-savings-goal' },
  { id: 'debt', label: 'Deuda', icon: MoneySend01Icon, color: '#2563EB', route: '/add-debt' },
  { id: 'account', label: 'Cuenta', icon: Wallet01Icon, color: '#2563EB', route: '/add-account' },
  { id: 'event', label: 'Evento', icon: Calendar01Icon, color: '#2563EB', route: '/add-recurring' },
  { id: 'transaction', label: 'Transacción', icon: ArrowUpDownIcon, color: '#2563EB', route: '/add-transaction' },
];

export default function FloatingMenu() {
  const [isOpen, setIsOpen] = useState(false);
  const router = useRouter();

  // 0 = closed, 1 = open
  const animation = useRef(new Animated.Value(0)).current;

  const toggleMenu = () => {
    const nextState = !isOpen;
    setIsOpen(nextState);

    Animated.spring(animation, {
      toValue: nextState ? 1 : 0,
      useNativeDriver: true,
      friction: 6,
      tension: 60,
    }).start();
  };

  const handlePress = (route: string) => {
    toggleMenu();
    // Slight delay to allow animation to start closing before navigating
    setTimeout(() => {
      router.push(route as any);
    }, 200);
  };

  const backdropOpacity = animation.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 1],
    extrapolate: 'clamp'
  });

  const fabRotate = animation.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '135deg'],
    extrapolate: 'clamp'
  });

  const fabScale = animation.interpolate({
    inputRange: [0, 0.5, 1],
    outputRange: [1, 0.8, 1],
    extrapolate: 'clamp'
  });

  return (
    <>
      {/* Backdrop */}
      {isOpen && (
        <Animated.View style={[styles.backdrop, { opacity: backdropOpacity }]}>
          <Pressable style={StyleSheet.absoluteFill} onPress={toggleMenu} />
        </Animated.View>
      )}

      {/* Menu Container restricted to bottom right */}
      <View style={styles.menuContainer} pointerEvents="box-none">

        {/* Action Items */}
        {actions.map((action, index) => {
          // Bottom-up position: 1 to 7
          const position = actions.length - index;

          const translateY = animation.interpolate({
            inputRange: [0, 1],
            outputRange: [0, -position * 70],
            extrapolate: 'clamp'
          });

          const opacity = animation.interpolate({
            inputRange: [0, 0.7, 1],
            outputRange: [0, 0.5, 1],
            extrapolate: 'clamp'
          });

          return (
            <Animated.View
              key={action.id}
              style={[
                styles.actionRow,
                { opacity, transform: [{ translateY }] }
              ]}
              pointerEvents={isOpen ? 'auto' : 'none'}
            >
              <Text
                style={styles.actionLabel}
                numberOfLines={1}
                ellipsizeMode="tail"
              >
                {action.label}
              </Text>
              <TouchableOpacity
                style={[styles.actionButton, { backgroundColor: action.color }]}
                onPress={() => handlePress(action.route)}
                activeOpacity={0.7}
              >
                <HugeiconsIcon icon={action.icon} size={24} color="#FFF" />
              </TouchableOpacity>
            </Animated.View>
          );
        })}

        {/* Floating Action Button */}
        <TouchableOpacity
          style={styles.fabWrapper}
          onPress={toggleMenu}
          activeOpacity={0.8}
        >
          {/* Main FAB circle */}
          <View style={[styles.fab, isOpen ? styles.fabOpen : styles.fabClosed]}>
            <Animated.View style={{ transform: [{ rotate: fabRotate }, { scale: fabScale }] }}>
              <Text style={[styles.fabIcon, { color: '#FFF' }]}>+</Text>
            </Animated.View>
          </View>
        </TouchableOpacity>

      </View>
    </>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(9, 9, 11, 0.85)', // Dark blur effect natively
    zIndex: 100,
  },
  menuContainer: {
    position: 'absolute',
    bottom: Platform.OS === 'ios' ? 100 : 80,
    right: 20,
    alignItems: 'flex-end',
    zIndex: 101,
  },
  actionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    position: 'absolute',
    right: 4, // Align centers visually with the FAB
    bottom: 4,
    width: 300, // Explicit ample width to prevent text from wrapping within narrow parent
  },
  actionLabel: {
    color: '#FAFAFA',
    fontSize: 16,
    fontWeight: '600',
    marginRight: 16,
    textShadowColor: 'rgba(0,0,0,0.6)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 4,
  },
  actionButton: {
    width: 52,
    height: 52,
    borderRadius: 26,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 5,
    elevation: 6,
  },
  fabWrapper: {
    width: 60,
    height: 60,
    justifyContent: 'center',
    alignItems: 'center',
  },
  fab: {
    width: 60,
    height: 60,
    borderRadius: 30,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 5,
    elevation: 8,
    borderWidth: 1,
  },
  fabClosed: {
    backgroundColor: '#2563EB',
    borderColor: '#3B82F6',
  },
  fabOpen: {
    backgroundColor: 'rgba(16,26,60,0.75)',
    borderColor: 'rgba(99,158,255,0.2)',
  },
  fabIcon: {
    fontSize: 32,
    fontWeight: '400',
    lineHeight: 34,
  }
});
