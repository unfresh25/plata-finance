import React from 'react';
import { TextInput, TextInputProps, Platform } from 'react-native';

interface AmountInputProps extends Omit<TextInputProps, 'value' | 'onChangeText'> {
  value: string;
  onChangeText: (rawAmount: string) => void;
}

export default function AmountInput({ value, onChangeText, style, ...props }: AmountInputProps) {
  const formatValue = (val: string) => {
    if (!val) return '';
    const parts = val.split('.');
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return parts.join('.');
  };

  const handleChange = (text: string) => {
    // Keep only numbers and a single decimal point
    let cleaned = text.replace(/[^0-9.]/g, '');
    const parts = cleaned.split('.');
    
    // Allow max one decimal point
    if (parts.length > 2) {
      cleaned = parts[0] + '.' + parts.slice(1).join('');
    }
    
    onChangeText(cleaned);
  };

  return (
    <TextInput
      style={style}
      value={formatValue(value)}
      onChangeText={handleChange}
      keyboardType="decimal-pad"
      // @ts-ignore
      adjustsFontSizeToFit={true}
      numberOfLines={1}
      {...props}
    />
  );
}
