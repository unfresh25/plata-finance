import React from 'react';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { DashboardSquare01Icon } from '@hugeicons/core-free-icons';
import { IconDictionary } from '../lib/IconDictionary';

interface DynamicIconProps {
  name: string | null | undefined;
  size?: number;
  color?: string;
}

export default function DynamicIcon({ name, size = 20, color = '#FAFAFA' }: DynamicIconProps) {
  if (!name) {
    return <HugeiconsIcon icon={DashboardSquare01Icon} size={size} color={color} />;
  }
  
  const IconComponent = IconDictionary[name];
  
  if (IconComponent) {
    return <HugeiconsIcon icon={IconComponent} size={size} color={color} />;
  }

  // Fallback si por alguna razón no se encuentra
  return <HugeiconsIcon icon={DashboardSquare01Icon} size={size} color={color} />;
}
