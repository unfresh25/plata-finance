// Inicialización tolerante de Sentry.
// - No rompe si @sentry/react-native no está instalado.
// - No hace nada si no hay DSN configurado (EXPO_PUBLIC_SENTRY_DSN).
// Exporta `wrap` para envolver el componente raíz y `captureException`.

type AnyComponent = <T>(c: T) => T;

let sentry: {
  wrap: AnyComponent;
  captureException: (e: unknown) => void;
} = {
  wrap: (c) => c,
  captureException: () => {},
};

const dsn = process.env.EXPO_PUBLIC_SENTRY_DSN;

if (dsn) {
  try {
    // Require diferido: si la dependencia falta, caemos al no-op de arriba.
    const Sentry = require('@sentry/react-native');
    Sentry.init({
      dsn,
      // Muestreo conservador; ajústalo cuando definas presupuesto de trazas.
      tracesSampleRate: 0.2,
      // No enviar en desarrollo por defecto.
      enabled: !__DEV__,
    });
    sentry = {
      wrap: Sentry.wrap,
      captureException: Sentry.captureException,
    };
  } catch {
    // @sentry/react-native no disponible: se mantiene el no-op.
  }
}

export const wrapWithSentry = sentry.wrap;
export const captureException = sentry.captureException;
