import React, { useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Dimensions, Animated, Easing } from 'react-native';
import { useRouter } from 'expo-router';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ArrowRight02Icon } from '@hugeicons/core-free-icons';
import * as SecureStore from 'expo-secure-store';

const { width, height } = Dimensions.get('window');

const AnimatedGradientView = Animated.createAnimatedComponent(View);

export default function OnboardingScreen() {
  const router = useRouter();

  const handleStart = async () => {
    await SecureStore.setItemAsync('has_seen_onboarding', 'true');
    router.replace('/(auth)/login');
  };

  // Intro animations
  const fadeAnim = new Animated.Value(0);
  const slideAnim = new Animated.Value(30);

  useEffect(() => {
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 800,
        useNativeDriver: true,
        easing: Easing.out(Easing.exp),
      }),
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 800,
        useNativeDriver: true,
        easing: Easing.out(Easing.exp),
      })
    ]).start();
  }, []);

  return (
    <View style={styles.container}>
      {/* Graphic Elements Top Area */}
      <View style={styles.graphicArea}>
        {/* Shape 1: Top Left Blob */}
        <Animated.View style={[styles.shape, styles.shape1, { opacity: fadeAnim, transform: [{ translateY: slideAnim }] }, { backgroundColor: '#818CF8' }]} />
        
        {/* Shape 2: Top Right */}
        <Animated.View style={[styles.shape, styles.shape2, { opacity: fadeAnim, transform: [{ translateY: slideAnim }] }, { backgroundColor: '#F43F5E' }]} />

        {/* Shape 3: Middle Left */}
        <Animated.View style={[styles.shape, styles.shape3, { opacity: fadeAnim, transform: [{ translateY: slideAnim }] }, { backgroundColor: '#34D399' }]} />

        {/* Shape 4: Bottom Right Circle */}
        <Animated.View style={[styles.shape, styles.shape4, { opacity: fadeAnim, transform: [{ translateY: slideAnim }] }, { backgroundColor: '#FDE047' }]} />

        {/* Shape 5: Center accent */}
        <Animated.View style={[styles.shape, styles.shape5, { opacity: fadeAnim, transform: [{ translateY: slideAnim }] }, { backgroundColor: '#38BDF8' }]} />

        {/* Shape 6: Bottom Left accent */}
        <Animated.View style={[styles.shape, styles.shape6, { opacity: fadeAnim, transform: [{ translateY: slideAnim }] }, { backgroundColor: '#C084FC' }]} />
      </View>

      {/* Text Content Bottom */}
      <View style={styles.contentArea}>
        <Animated.Text style={[styles.title, { opacity: fadeAnim, transform: [{ translateY: slideAnim }] }]}>
          El control de tu plata en tus manos
        </Animated.Text>
        <Animated.Text style={[styles.subtitle, { opacity: fadeAnim, transform: [{ translateY: slideAnim }] }]}>
          Tu camino hacia el gasto consciente y la tranquilidad empieza aquí.
        </Animated.Text>
      </View>

      {/* Button */}
      <View style={styles.bottomArea}>
        <TouchableOpacity style={styles.button} activeOpacity={0.8} onPress={handleStart}>
          <Text style={styles.buttonText}>Empezar</Text>
          <View style={styles.buttonIcon}>
            <HugeiconsIcon icon={ArrowRight02Icon} size={20} color="#FFF" />
          </View>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#09090B', // Dark Zinc 950
    justifyContent: 'flex-end',
  },
  graphicArea: {
    position: 'absolute',
    top: height * 0.15,
    width: '100%',
    height: width, // Square ratio
    alignItems: 'center',
    justifyContent: 'center',
  },
  shape: {
    position: 'absolute',
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
  },
  gradient: {
    width: '100%',
    height: '100%',
  },
  shape1: {
    width: 120,
    height: 120,
    borderRadius: 40,
    borderTopLeftRadius: 100,
    borderBottomRightRadius: 80,
    top: 20,
    left: 40,
    transform: [{ rotate: '-15deg' }],
  },
  shape2: {
    width: 140,
    height: 140,
    borderRadius: 60,
    borderTopRightRadius: 120,
    top: 40,
    right: 30,
    transform: [{ rotate: '20deg' }],
  },
  shape3: {
    width: 160,
    height: 120,
    borderRadius: 50,
    borderBottomLeftRadius: 100,
    bottom: 0,
    left: 20,
    transform: [{ rotate: '10deg' }],
  },
  shape4: {
    width: 110,
    height: 110,
    borderRadius: 55,
    borderTopLeftRadius: 0,
    bottom: 30,
    right: 40,
    transform: [{ rotate: '-45deg' }],
  },
  shape5: {
    width: 90,
    height: 90,
    borderRadius: 45,
    top: 100,
    left: '45%',
    transform: [{ rotate: '30deg' }],
  },
  shape6: {
    width: 80,
    height: 80,
    borderRadius: 24,
    borderTopRightRadius: 60,
    bottom: 60,
    left: 50,
    transform: [{ rotate: '-20deg' }],
  },
  contentArea: {
    paddingHorizontal: 32,
    marginBottom: 40,
  },
  title: {
    fontSize: 48,
    fontWeight: '700',
    color: '#FFFFFF',
    lineHeight: 52,
    marginBottom: 16,
    letterSpacing: -1,
    fontFamily: 'IBM Plex Sans',
  },
  subtitle: {
    fontSize: 16,
    color: '#A1A1AA', // zinc-400
    lineHeight: 24,
    fontFamily: 'IBM Plex Sans',
    maxWidth: '85%',
  },
  bottomArea: {
    paddingHorizontal: 24,
    paddingBottom: 48, // Safe area bottom padding roughly
  },
  button: {
    backgroundColor: '#FFFFFF',
    borderRadius: 40,
    height: 64,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingLeft: 32,
    paddingRight: 8,
  },
  buttonText: {
    color: '#09090B',
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'IBM Plex Sans',
  },
  buttonIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#09090B',
    alignItems: 'center',
    justifyContent: 'center',
  }
});
