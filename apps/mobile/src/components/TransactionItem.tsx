import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { formatCurrency } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react-native';
import { ArrowRight01Icon } from '@hugeicons/core-free-icons';
import { useTheme } from '../context/ThemeContext';

export function formatRelativeDate(dateString: string, createdAtString?: string) {
  // Manejo de zona horaria local simulado
  const txDate = new Date(dateString + 'T12:00:00');
  const created = createdAtString ? new Date(createdAtString) : txDate;

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const targetDay = new Date(txDate.getFullYear(), txDate.getMonth(), txDate.getDate());

  const diffTime = today.getTime() - targetDay.getTime();
  const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

  const formatTime = (d: Date) => d.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });

  if (diffDays === 0) {
    return `Hoy ${formatTime(created)}`;
  } else if (diffDays === 1) {
    return `Ayer ${formatTime(created)}`;
  } else if (diffDays > 1 && diffDays < 7) {
    return `Hace ${diffDays} días`;
  } else {
    // "Marzo 23, 2026"
    const month = txDate.toLocaleDateString('es-ES', { month: 'long' });
    const capitalizedMonth = month.charAt(0).toUpperCase() + month.slice(1);
    return `${capitalizedMonth} ${txDate.getDate()}, ${txDate.getFullYear()}`;
  }
}

interface TransactionItemProps {
  tx: any;
  category: any;
  creator: any;
  currency: string;
  onPress: () => void;
  onLongPress: () => void;
  isLast?: boolean;
}

export default function TransactionItem({ tx, category, creator, currency, onPress, onLongPress, isLast }: TransactionItemProps) {
  const { theme } = useTheme();
  const fmt = (n: number) => formatCurrency(n, currency);
  const isIncome = tx.type === 'income';

  const creatorName = creator?.name || 'Usuario';
  const initial = creatorName.charAt(0).toUpperCase();

  return (
    <TouchableOpacity
      style={[styles.container, { borderBottomColor: theme.border }, isLast && { borderBottomWidth: 0 }]}
      onPress={onPress}
      onLongPress={onLongPress}
      delayLongPress={400}
    >
      <View style={styles.creatorRow}>
        <View style={[styles.avatar, { backgroundColor: theme.pillBg }]}><Text style={[styles.avatarText, { color: theme.text }]}>{initial}</Text></View>
        <Text style={[styles.creatorName, { color: theme.textMuted }]}>{creatorName}</Text>
      </View>

      <View style={styles.mainRow}>
        <Text style={[styles.description, { color: theme.text }]}>{tx.description || category?.name || 'Movimiento'}</Text>
        <View style={styles.amountRow}>
          <Text style={[styles.amount, isIncome ? { color: theme.success } : { color: theme.text }]}>
            {isIncome ? '+' : '-'}{fmt(tx.amount)}
          </Text>
          <HugeiconsIcon icon={ArrowRight01Icon} size={16} color={theme.textMuted} />
        </View>
      </View>

      <Text style={[styles.categoryName, { color: theme.textMuted }]}>{category?.name || 'General'}</Text>
      <Text style={[styles.dateText, { color: theme.textMuted }]}>{formatRelativeDate(tx.date, tx.created_at)}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(99,158,255,0.2)',
  },
  creatorRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    gap: 8
  },
  avatar: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: '#3F3F46',
    alignItems: 'center',
    justifyContent: 'center'
  },
  avatarText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#FAFAFA'
  },
  creatorName: {
    fontSize: 13,
    color: '#A1A1AA',
    fontWeight: '500'
  },
  mainRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4
  },
  description: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FAFAFA',
    flex: 1,
    marginRight: 10
  },
  amountRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6
  },
  amount: {
    fontSize: 16,
    fontWeight: '700',
    fontVariant: ['tabular-nums']
  },
  categoryName: {
    fontSize: 14,
    color: '#A1A1AA',
    marginBottom: 2
  },
  dateText: {
    fontSize: 13,
    color: '#71717A'
  }
});
