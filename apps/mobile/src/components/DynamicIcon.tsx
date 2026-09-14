import React from 'react';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { DashboardSquare01Icon } from '@hugeicons/core-free-icons';
import { IconDictionary } from '../lib/IconDictionary';
import { useTheme } from '../context/ThemeContext';

interface DynamicIconProps {
  name: string | null | undefined;
  size?: number;
  color?: string;
}

export default function DynamicIcon({ name, size = 20, color }: DynamicIconProps) {
  const { theme } = useTheme();
  const activeColor = color || theme.text;

  if (!name) {
    return <HugeiconsIcon icon={DashboardSquare01Icon} size={size} color={activeColor} />;
  }
  
  const IconComponent = IconDictionary[name];
  
  if (IconComponent) {
    return <HugeiconsIcon icon={IconComponent} size={size} color={activeColor} />;
  }

  // Fallback si por alguna razón no se encuentra
  return <HugeiconsIcon icon={DashboardSquare01Icon} size={size} color={activeColor} />;
}
