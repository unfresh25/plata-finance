import React, { useState } from 'react';
import { View, StyleSheet, Platform, Modal, TouchableOpacity, Text } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { useTheme } from '../context/ThemeContext';

interface DaySelectorProps {
  selectedDay: string;
  onSelectDay: (day: string) => void;
  color?: string;
}

export default function DaySelector({ selectedDay, onSelectDay, color = '#2563EB' }: DaySelectorProps) {
  const { theme, isDark } = useTheme();
  const days = Array.from({ length: 31 }, (_, i) => String(i + 1));
  const [showModal, setShowModal] = useState(false);

  // Platform Android already supports "dialog" mode which pops it up nicely.
  // For iOS, we need to manually fake the Action Sheet / Modal experience of DatePicker.
  
  if (Platform.OS === 'ios') {
    return (
      <View>
        <TouchableOpacity 
          style={styles.triggerBtn} 
          onPress={() => setShowModal(true)}
          activeOpacity={0.7}
        >
          <Text style={[styles.triggerText, { color }]}>{selectedDay}</Text>
        </TouchableOpacity>

        <Modal
          visible={showModal}
          transparent
          animationType="slide"
          onRequestClose={() => setShowModal(false)}
        >
          <View style={styles.modalOverlay}>
            <TouchableOpacity style={{ flex: 1 }} onPress={() => setShowModal(false)} />
            <View style={[styles.modalContent, { backgroundColor: theme.card }]}>
              <View style={[styles.modalHeader, { borderBottomColor: theme.border }]}>
                <TouchableOpacity onPress={() => setShowModal(false)}>
                  <Text style={{ color: '#2563EB', fontSize: 16, fontWeight: '600' }}>Listo</Text>
                </TouchableOpacity>
              </View>
              <Picker
                selectedValue={selectedDay}
                onValueChange={(itemValue) => onSelectDay(itemValue)}
                itemStyle={{ color: theme.text, fontSize: 22 }}
                style={{ height: 216 }}
              >
                {days.map((d) => (
                  <Picker.Item key={d} label={d.padStart(2, '0')} value={d} />
                ))}
              </Picker>
            </View>
          </View>
        </Modal>
      </View>
    );
  }

  // On Android, we just use the naked picker, "dialog" mode will handle the tap-to-open UI.
  return (
    <View style={styles.androidPickerContainer}>
      <Picker
        selectedValue={selectedDay}
        mode="dialog"
        onValueChange={(itemValue) => onSelectDay(itemValue)}
        style={{ color: theme.text }}
        dropdownIconColor={theme.text}
      >
        {days.map((d) => (
          <Picker.Item key={d} label={d} value={d} />
        ))}
      </Picker>
    </View>
  );
}

const styles = StyleSheet.create({
  triggerBtn: {
    backgroundColor: 'rgba(255,255,255,0.05)',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    marginTop: 8,
  },
  triggerText: {
    fontSize: 18,
    fontWeight: '600',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    paddingBottom: 40,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.2,
    shadowRadius: 10,
    elevation: 10,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.05)',
  },
  androidPickerContainer: {
    marginTop: 8,
    alignSelf: 'flex-start',
    minWidth: 120,
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    overflow: 'hidden',
  }
});
