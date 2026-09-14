// Metro config para Expo.
// Envuelve la config con Sentry solo si @sentry/react-native está instalado,
// de modo que la ausencia de la dependencia nunca rompa el bundler.
const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);

let finalConfig = config;
try {
  // getSentryExpoConfig envuelve la config por defecto para subir sourcemaps.
  const { getSentryExpoConfig } = require("@sentry/react-native/metro");
  finalConfig = getSentryExpoConfig(__dirname);
} catch (e) {
  // Sentry no instalado: se usa la config por defecto de Expo sin fallar.
  console.warn(
    "[metro] @sentry/react-native no encontrado; usando config por defecto de Expo."
  );
}

module.exports = finalConfig;
