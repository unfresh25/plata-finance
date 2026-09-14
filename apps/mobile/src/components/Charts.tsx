import React from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import { PieChart, LineChart, BarChart } from 'react-native-gifted-charts';
import DynamicIcon from './DynamicIcon';
import { useTheme } from '../context/ThemeContext';

const SCREEN_WIDTH = Dimensions.get('window').width;

// Monochromatic white-opacity steps for dark mode
const PALETTE_DARK = [
  'rgba(250,250,250,0.95)',
  'rgba(250,250,250,0.70)',
  'rgba(250,250,250,0.50)',
  'rgba(250,250,250,0.35)',
  'rgba(250,250,250,0.24)',
  'rgba(250,250,250,0.16)',
  'rgba(250,250,250,0.10)',
  'rgba(250,250,250,0.06)',
];

// Monochromatic dark-opacity steps for light mode
const PALETTE_LIGHT = [
  'rgba(24,24,27,0.95)',
  'rgba(24,24,27,0.70)',
  'rgba(24,24,27,0.50)',
  'rgba(24,24,27,0.35)',
  'rgba(24,24,27,0.24)',
  'rgba(24,24,27,0.16)',
  'rgba(24,24,27,0.10)',
  'rgba(24,24,27,0.06)',
];

export function getColor(index: number, isDark: boolean = true) {
  const pal = isDark ? PALETTE_DARK : PALETTE_LIGHT;
  return pal[index % pal.length];
}

// ──────────────────────────────────────────────────────────
// ComparisonBars – Income vs Expense grouped bar chart
// ──────────────────────────────────────────────────────────

interface ComparePoint {
  label: string;
  income: number;
  expense: number;
}

export function ComparisonBars({ data }: { data: ComparePoint[] }) {
  const { theme, isDark } = useTheme();
  const maxY = data.reduce((m, d) => Math.max(m, Math.abs(d.income), Math.abs(d.expense)), 1);
  const barWidth = 12;
  const groupGap = 16;
  const innerGap = 3;
  const spacing = Math.floor((SCREEN_WIDTH - 48 - (data.length * (barWidth * 2 + innerGap))) / Math.max(data.length - 1, 1));

  const barData = data.flatMap((d, i) => [
    {
      value: Math.abs(d.income),
      frontColor: isDark ? 'rgba(250,250,250,0.75)' : 'rgba(24,24,27,0.75)',
      label: d.label,
      labelWidth: barWidth * 2 + innerGap,
      labelTextStyle: { color: theme.textMuted, fontSize: 9, textAlign: 'center' as const, width: barWidth * 2 + innerGap },
      spacing: innerGap,
      topLabelComponent: undefined,
    },
    {
      value: Math.abs(d.expense),
      frontColor: 'rgba(239,68,68,0.75)',
      spacing: i < data.length - 1 ? groupGap : innerGap,
    },
  ]);

  return (
    <View>
      <View style={{ marginLeft: -10 }}>
        <BarChart
          data={barData}
          barWidth={barWidth}
          noOfSections={3}
          maxValue={maxY * 1.15}
          yAxisColor="transparent"
          xAxisColor="transparent"
          yAxisTextStyle={{ color: theme.textMuted, fontSize: 8 }}
          xAxisLabelTextStyle={{ color: theme.textMuted, fontSize: 9 }}
          rulesColor={isDark ? "rgba(255,255,255,0.04)" : "rgba(0,0,0,0.04)"}
          height={140}
          initialSpacing={12}
          barBorderRadius={2}
          disablePress
          hideRules={false}
        />
      </View>
      {/* Legend */}
      <View style={{ flexDirection: 'row', gap: 20, marginTop: 12, paddingLeft: 4 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <View style={{ width: 10, height: 3, borderRadius: 1.5, backgroundColor: isDark ? 'rgba(250,250,250,0.75)' : 'rgba(24,24,27,0.75)' }} />
          <Text style={{ color: theme.textMuted, fontSize: 10, fontWeight: '600', letterSpacing: 0.5 }}>INGRESOS</Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <View style={{ width: 10, height: 3, borderRadius: 1.5, backgroundColor: 'rgba(239,68,68,0.75)' }} />
          <Text style={{ color: theme.textMuted, fontSize: 10, fontWeight: '600', letterSpacing: 0.5 }}>GASTOS</Text>
        </View>
      </View>
    </View>
  );
}

// ──────────────────────────────────────────────────────────
// FintechDonut – Thin ring, percentage in center
// ──────────────────────────────────────────────────────────

interface DonutSlice {
  label: string;
  value: number;
  displayValue?: string;
  color: string;
  icon?: string;
}

interface FintechDonutProps {
  data: DonutSlice[];
  totalLabel?: string;
  totalValue?: string;
  size?: number;
}

export function FintechDonut({ data, totalLabel = 'Total', totalValue = '$0', size = 160 }: FintechDonutProps) {
  const { theme } = useTheme();
  const chartData = data.map(d => ({ value: Math.max(d.value, 0.1), color: d.color }));
  const total = data.reduce((s, d) => s + d.value, 0);
  const topPct = total > 0 && data.length > 0 ? Math.round((data[0].value / total) * 100) : 0;

  return (
    <View style={donutStyles.container}>
      <PieChart
        donut
        innerRadius={size * 0.36}
        radius={size / 2}
        data={chartData}
        innerCircleColor={theme.background}
        centerLabelComponent={() => (
          <View style={{ justifyContent: 'center', alignItems: 'center' }}>
            <Text style={[donutStyles.pctValue, { color: theme.text }]}>{topPct}%</Text>
            <Text style={[donutStyles.pctLabel, { color: theme.textMuted }]} numberOfLines={1}>{data[0]?.label ?? ''}</Text>
          </View>
        )}
        backgroundColor="transparent"
      />
    </View>
  );
}

const donutStyles = StyleSheet.create({
  container: { alignItems: 'center', justifyContent: 'center' },
  pctValue: { fontSize: 24, fontWeight: '800', color: '#FAFAFA', letterSpacing: -0.5 },
  pctLabel: { fontSize: 10, color: '#A1A1AA', fontWeight: '500', marginTop: 2, maxWidth: 70, textAlign: 'center' },
});

// ──────────────────────────────────────────────────────────
// SidePieChart – kept for compatibility
// ──────────────────────────────────────────────────────────

interface SidePieProps {
  income: number;
  expense: number;
  size?: number;
}

export function SidePieChart({ income, expense, size = 130 }: SidePieProps) {
  const total = income + expense;
  const incomePct = total > 0 ? Math.round((income / total) * 100) : 50;
  const expensePct = 100 - incomePct;
  const chartData = [
    { value: Math.max(income, 0.1), color: '#22C55E' },
    { value: Math.max(expense, 0.1), color: '#EF4444' },
    { value: 1, color: '#1c1c1e' },
  ];
  return (
    <View style={{ alignItems: 'center', gap: 10 }}>
      <PieChart radius={size / 2} data={chartData} backgroundColor="transparent" focusOnPress={false} />
      <View style={{ gap: 6 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: '#22C55E' }} />
          <Text style={{ fontSize: 11, color: '#A1A1AA', fontWeight: '500' }}>Ingresos {incomePct}%</Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: '#EF4444' }} />
          <Text style={{ fontSize: 11, color: '#A1A1AA', fontWeight: '500' }}>Gastos {expensePct}%</Text>
        </View>
      </View>
    </View>
  );
}

// ──────────────────────────────────────────────────────────
// TrendLine – Smooth area chart, always starts from 0
// ──────────────────────────────────────────────────────────

interface TrendPoint {
  value: number;
  label: string;
}

interface TrendLineProps {
  data: TrendPoint[];
  color?: string;
}

export function TrendLine({ data, color = '#22C55E' }: TrendLineProps) {
  const { isDark } = useTheme();
  // Always use absolute value; ensure non-negative
  const chartData = data.map(d => ({ value: Math.max(Math.abs(d.value || 0), 0), label: d.label }));
  if (chartData.length === 0) return null;
  const maxVal = chartData.reduce((m, d) => Math.max(m, d.value), 0);

  return (
    <View style={{ marginLeft: -8, marginTop: 8 }}>
      <LineChart
        areaChart
        data={chartData}
        hideDataPoints
        spacing={Math.max((SCREEN_WIDTH - 100) / Math.max(chartData.length - 1, 1), 30)}
        color={color}
        thickness={2.5}
        startFillColor={color}
        endFillColor={color}
        startOpacity={0.2}
        endOpacity={0.0}
        initialSpacing={16}
        noOfSections={3}
        // force Y axis to start at 0 — yAxisOffset not available in this version
        // ensure maxValue is always >= 0 so no negative scale appears
        maxValue={maxVal > 0 ? maxVal * 1.2 : 100}
        yAxisOffset={0}
        yAxisColor="transparent"
        yAxisTextStyle={{ color: '#3F3F46', fontSize: 9 }}
        xAxisColor="transparent"
        xAxisLabelTextStyle={{ color: '#52525B', fontSize: 10, textAlign: 'center' }}
        rulesColor={isDark ? "rgba(255,255,255,0.04)" : "rgba(0,0,0,0.04)"}
        height={140}
      />
    </View>
  );
}

// ──────────────────────────────────────────────────────────
// BudgetArch – Clean progress display (replaces clipped semi-circle)
// ──────────────────────────────────────────────────────────

interface BudgetArchProps {
  spent: number;
  limit: number;
  currency?: string;
  title?: string;
}

export function BudgetArch({ spent, limit, currency = '$', title = 'Gasto Total' }: BudgetArchProps) {
  const { theme } = useTheme();
  const pct = limit > 0 ? Math.min((spent / limit), 1) : 0;
  const barColor = pct >= 0.9 ? theme.danger : pct >= 0.7 ? theme.textMuted : theme.text;

  return (
    <View style={archStyles.container}>
      {/* Title + numbers row */}
      <View style={archStyles.row}>
        <View>
          <Text style={archStyles.title}>{title}</Text>
          <Text style={[archStyles.value, { color: theme.text }]}>{currency}{spent.toLocaleString()}</Text>
        </View>
        <View style={{ alignItems: 'flex-end' }}>
          <Text style={archStyles.limitLabel}>Límite</Text>
          <Text style={archStyles.limitValue}>{currency}{limit.toLocaleString()}</Text>
        </View>
      </View>

      {/* Wide progress bar */}
      <View style={[archStyles.track, { backgroundColor: theme.pillBg }]}>
        <View style={[archStyles.fill, { width: `${pct * 100}%`, backgroundColor: barColor }]} />
      </View>

      {/* Percentage */}
      <Text style={[archStyles.pctText, { color: barColor }]}>
        {(pct * 100).toFixed(0)}% consumido
      </Text>
    </View>
  );
}

const archStyles = StyleSheet.create({
  container: { paddingVertical: 8 },
  row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 16 },
  title: { fontSize: 10, color: '#71717A', fontWeight: '700', letterSpacing: 1.2, textTransform: 'uppercase', marginBottom: 4 },
  value: { fontSize: 28, fontWeight: '800', letterSpacing: -1 },
  limitLabel: { fontSize: 10, color: '#71717A', fontWeight: '600', letterSpacing: 0.5, marginBottom: 4 },
  limitValue: { fontSize: 16, fontWeight: '600', color: '#A1A1AA' },
  track: { height: 4, borderRadius: 2, overflow: 'hidden', marginBottom: 8 },
  fill: { height: 4, borderRadius: 2 },
  pctText: { fontSize: 11, fontWeight: '600' },
});

// ──────────────────────────────────────────────────────────
// HeatmapTracker (kept for compatibility)
// ──────────────────────────────────────────────────────────

interface HeatmapProps {
  data: { date: string; count: number }[];
}

export function HeatmapTracker({ data }: HeatmapProps) {
  const { isDark } = useTheme();
  const cols = 18;
  const rows = 7;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const grid = Array.from({ length: cols }, () => Array(rows).fill(0));

  data.forEach(d => {
    const dDate = new Date(d.date + 'T12:00:00');
    dDate.setHours(0, 0, 0, 0);
    const diffTime = today.getTime() - dDate.getTime();
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    if (diffDays >= 0 && diffDays < cols * rows) {
      const c = cols - 1 - Math.floor(diffDays / 7);
      const r = (today.getDay() - (diffDays % 7) + 7) % 7;
      if (c >= 0 && c < cols && r >= 0 && r < rows) grid[c][r] += d.count;
    }
  });

  return (
    <View style={heatmapStyles.container}>
      {grid.map((col, cIdx) => (
        <View key={cIdx} style={heatmapStyles.col}>
          {col.map((val, rIdx) => {
            const opacity = val === 0 ? 0.05 : Math.min(val * 0.3 + 0.3, 1);
            const baseColor = isDark ? '250,250,250' : '24,24,27';
            return <View key={rIdx} style={[heatmapStyles.cell, { backgroundColor: `rgba(${baseColor},${opacity})` }]} />;
          })}
        </View>
      ))}
    </View>
  );
}

const heatmapStyles = StyleSheet.create({
  container: { flexDirection: 'row', gap: 4, marginTop: 8, justifyContent: 'center' },
  col: { gap: 4 },
  cell: { width: 12, height: 12, borderRadius: 2 },
});

// ──────────────────────────────────────────────────────────
// BudgetProgress – with DynamicIcon for category icons
// ──────────────────────────────────────────────────────────

interface BudgetProgressProps {
  name: string;
  icon?: string;
  spent: number;
  limit: number;
  color?: string;
}

export function BudgetProgress({ name, icon, spent, limit }: BudgetProgressProps) {
  const { theme } = useTheme();
  const pct = limit > 0 ? Math.min((spent / limit) * 100, 100) : 0;
  const barColor = pct >= 90 ? theme.danger : pct >= 70 ? theme.textMuted : theme.text;

  return (
    <View style={budgetStyles.container}>
      <View style={budgetStyles.top}>
        <View style={budgetStyles.nameRow}>
          {icon ? (
            <DynamicIcon name={icon} size={14} color="#A1A1AA" />
          ) : (
            <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: theme.textMuted }} />
          )}
          <Text style={[budgetStyles.name, { color: theme.text }]} numberOfLines={1}>{name}</Text>
        </View>
        <Text style={budgetStyles.amounts}>{spent.toFixed(0)} / {limit.toFixed(0)}</Text>
      </View>
      <View style={[budgetStyles.track, { backgroundColor: theme.pillBg }]}>
        <View style={[budgetStyles.fill, { width: `${pct}%`, backgroundColor: barColor }]} />
      </View>
      <Text style={[budgetStyles.pctLabel, { color: barColor }]}>{pct.toFixed(0)}% usado</Text>
    </View>
  );
}

const budgetStyles = StyleSheet.create({
  container: { marginBottom: 20 },
  top: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 },
  name: { fontSize: 13, fontWeight: '500', flex: 1 },
  amounts: { fontSize: 12, color: '#71717A', fontWeight: '600' },
  track: { height: 3, borderRadius: 2, overflow: 'hidden', marginBottom: 4 },
  fill: { height: 3, borderRadius: 2 },
  pctLabel: { fontSize: 10, fontWeight: '600' },
});
