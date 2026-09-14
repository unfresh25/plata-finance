import { useState, useEffect } from 'react';
import {
  Modal,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  KeyboardTypeOptions,
} from 'react-native';
import { useTheme } from '../context/ThemeContext';

export type PromptConfig = {
  title: string;
  message?: string;
  placeholder?: string;
  defaultValue?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  autoCapitalize?: 'none' | 'characters' | 'words' | 'sentences';
  keyboardType?: KeyboardTypeOptions;
  /** Si true, permite confirmar con el input vacío (usa el defaultValue como fallback aguas arriba). */
  allowEmpty?: boolean;
};

type Props = {
  visible: boolean;
  config: PromptConfig;
  onCancel: () => void;
  onConfirm: (value: string) => void;
};

/**
 * Reemplazo cross-platform de Alert.prompt (que NO existe en Android).
 * Un modal con un TextInput controlado. Usar junto con usePrompt().
 */
export function PromptModal({ visible, config, onCancel, onConfirm }: Props) {
  const { theme } = useTheme();
  const [value, setValue] = useState(config.defaultValue ?? '');

  useEffect(() => {
    if (visible) setValue(config.defaultValue ?? '');
  }, [visible, config.defaultValue]);

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onCancel}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.backdrop}
      >
        <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
          <Text style={[styles.title, { color: theme.text }]}>{config.title}</Text>
          {config.message ? (
            <Text style={[styles.message, { color: theme.textMuted }]}>{config.message}</Text>
          ) : null}
          <TextInput
            value={value}
            onChangeText={setValue}
            placeholder={config.placeholder}
            placeholderTextColor={theme.textMuted}
            autoFocus
            autoCapitalize={config.autoCapitalize ?? 'sentences'}
            keyboardType={config.keyboardType}
            style={[styles.input, { color: theme.text, borderColor: theme.border, backgroundColor: theme.background }]}
            onSubmitEditing={() => (config.allowEmpty || value.trim()) && onConfirm(value.trim())}
            returnKeyType="done"
          />
          <View style={styles.actions}>
            <TouchableOpacity onPress={onCancel} style={styles.btn}>
              <Text style={[styles.btnText, { color: theme.textMuted }]}>
                {config.cancelLabel ?? 'Cancelar'}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => (config.allowEmpty || value.trim()) && onConfirm(value.trim())}
              disabled={!config.allowEmpty && !value.trim()}
              style={[styles.btn, { opacity: config.allowEmpty || value.trim() ? 1 : 0.4 }]}
            >
              <Text style={[styles.btnText, { color: theme.primary, fontWeight: '700' }]}>
                {config.confirmLabel ?? 'Aceptar'}
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  card: {
    width: '100%',
    maxWidth: 420,
    borderRadius: 16,
    borderWidth: 1,
    padding: 20,
    gap: 12,
  },
  title: { fontSize: 17, fontWeight: '700' },
  message: { fontSize: 14, lineHeight: 20 },
  input: {
    borderWidth: 1,
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
  },
  actions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 8, marginTop: 4 },
  btn: { paddingVertical: 10, paddingHorizontal: 16 },
  btnText: { fontSize: 15 },
});
