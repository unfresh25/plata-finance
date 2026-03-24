import React from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import { PieChart, LineChart } from 'react-native-gifted-charts';
import DynamicIcon from './DynamicIcon';

const SCREEN_WIDTH = Dimensions.get('window').width;

// ──────────────────────────────────────────────────────────
// FintechDonut – Thin ring style
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

export function FintechDonut({ data, totalLabel = 'Total', totalValue = '$0', size = 240 }: FintechDonutProps) {
  const chartData = data.map(d => ({ value: d.value || 0.1, color: d.color }));

  return (
    <View style={donutStyles.container}>
      <View style={donutStyles.chartWrapper}>
        <PieChart
          donut
          innerRadius={size * 0.48}
          radius={size / 2}
          data={chartData}
          innerCircleColor="#000000" // Force the hole color same as background
          centerLabelComponent={() => (
            <View style={{ justifyContent: 'center', alignItems: 'center' }}>
              <Text style={donutStyles.totalLabel}>{totalLabel}</Text>
              <Text style={donutStyles.totalValue}>{totalValue}</Text>
            </View>
          )}
          backgroundColor="transparent"
        />
      </View>
      <View style={donutStyles.legendGrid}>
        {data.map((slice, i) => (
          <View key={i} style={[donutStyles.legendPill, { backgroundColor: slice.color + '15' }]}>
            {slice.icon && <DynamicIcon name={slice.icon} size={14} color={slice.color} />}
            <View style={{ gap: 2 }}>
                <Text style={[donutStyles.legendLabel, { color: slice.color }]} numberOfLines={1}>{slice.label}</Text>
                <Text style={[donutStyles.legendAmount, { color: slice.color }]}>{slice.displayValue || slice.value}</Text>
            </View>
          </View>
        ))}
      </View>
    </View>
  );
}

// ──────────────────────────────────────────────────────────
// BudgetArch – Semi-circle Gauge style (Image 3)
// ──────────────────────────────────────────────────────────

interface BudgetArchProps {
  spent: number;
  limit: number;
  currency?: string;
  title?: string;
}

export function BudgetArch({ spent, limit, currency = '$', title = 'Gasto Total' }: BudgetArchProps) {
  const pct = limit > 0 ? (spent / limit) : 0;
  const clampedPct = Math.min(pct, 1);
  
  // Create segments for the arch effect
  // We'll use 20 segments to simulate the "dashed" look in the image
  const totalSegments = 20;
  const segments = Array.from({ length: totalSegments }, (_, i) => {
    const isActive = (i / totalSegments) < clampedPct;
    return {
      value: 1,
      color: isActive ? getGradientColor(i / totalSegments) : 'rgba(255,255,255,0.05)'
    };
  });

  function getGradientColor(p: number) {
    if (p < 0.3) return '#60A5FA'; // Blueish
    if (p < 0.6) return '#34D399'; // Greenish
    if (p < 0.8) return '#FBBF24'; // Yellowish
    return '#F87171'; // Reddish
  }

  return (
    <View style={archStyles.container}>
      <View style={archStyles.chartWrapper}>
        <PieChart
          semiCircle
          radius={120}
          innerRadius={100}
          data={segments}
          backgroundColor="transparent"
          centerLabelComponent={() => (
            <View style={{ justifyContent: 'center', alignItems: 'center', marginTop: 40 }}>
              <Text style={archStyles.title}>{title}</Text>
              <Text style={archStyles.value}>{currency}{spent.toLocaleString()}</Text>
            </View>
          )}
        />
      </View>
      <View style={archStyles.footer}>
         <View style={archStyles.limitBadge}>
            <Text style={archStyles.limitText}>Límite: {currency}{limit.toLocaleString()}</Text>
         </View>
         <Text style={archStyles.pctText}>{(clampedPct * 100).toFixed(0)}% consumido</Text>
      </View>
    </View>
  );
}

const archStyles = StyleSheet.create({
  container: { alignItems: 'center', paddingVertical: 10 },
  chartWrapper: { height: 160, justifyContent: 'flex-start' },
  title: { fontSize: 13, color: '#A1A1AA', fontWeight: '500' },
  value: { fontSize: 32, fontWeight: '800', color: '#FAFAFA', marginTop: 4 },
  footer: { alignItems: 'center', marginTop: -10 },
  limitBadge: { backgroundColor: 'rgba(255,255,255,0.05)', paddingHorizontal: 12, paddingVertical: 4, borderRadius: 12, marginBottom: 4 },
  limitText: { color: '#71717A', fontSize: 12, fontWeight: '600' },
  pctText: { color: '#A1A1AA', fontSize: 13, fontWeight: '500' },
});

const PALETTE = [
  '#2563EB', '#22C55E', '#F59E0B', '#EF4444', '#A855F7',
  '#EC4899', '#14B8A6', '#F97316', '#06B6D4', '#84CC16',
];

export function getColor(index: number) { return PALETTE[index % PALETTE.length]; }

const donutStyles = StyleSheet.create({
  container: { alignItems: 'center', width: '100%' },
  chartWrapper: { alignItems: 'center', justifyContent: 'center', marginVertical: 16 },
  totalLabel: { fontSize: 13, color: '#A1A1AA', textTransform: 'uppercase', letterSpacing: 1 },
  totalValue: { fontSize: 28, fontWeight: '800', color: '#FAFAFA', marginTop: 4 },
  legendGrid: { flexDirection: 'row', flexWrap: 'wrap', width: '100%', justifyContent: 'center', gap: 10, marginTop: 12 },
  legendPill: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 10, borderRadius: 24, gap: 10 },
  legendLabel: { fontSize: 14, fontWeight: '600', maxWidth: 120 },
  legendAmount: { fontSize: 13, fontWeight: '700', opacity: 0.9 },
});

// ──────────────────────────────────────────────────────────
// TrendLine
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
  // Use absolute value to ensure expenses (often negative in DB) show correctly as positive trends
  const chartData = data.map(d => ({ value: Math.abs(d.value || 0), label: d.label }));
  if (chartData.length === 0) return null;

  return (
    <View style={{ marginLeft: -10, marginTop: 10 }}>
      <LineChart
        areaChart
        data={chartData}
        hideDataPoints
        spacing={Math.max((SCREEN_WIDTH - 80) / Math.max(chartData.length - 1, 1), 30)}
        color={color}
        thickness={3}
        startFillColor={color}
        endFillColor={color}
        startOpacity={0.3}
        endOpacity={0.0}
        initialSpacing={10}
        noOfSections={4}
        yAxisColor="transparent"
        yAxisTextStyle={{ color: '#71717A', fontSize: 10 }}
        xAxisColor="transparent"
        xAxisLabelTextStyle={{ color: '#71717A', fontSize: 10, textAlign: 'center', marginLeft: -10 }}
        rulesColor="rgba(255,255,255,0.05)"
        height={160}
        curved
      />
    </View>
  );
}

// ──────────────────────────────────────────────────────────
// HeatmapTracker
// ──────────────────────────────────────────────────────────

interface HeatmapProps {
  data: { date: string; count: number }[]; // YYYY-MM-DD
}

export function HeatmapTracker({ data }: HeatmapProps) {
  const cols = 18;
  const rows = 7;
  const today = new Date();
  today.setHours(0,0,0,0);
  const grid = Array.from({ length: cols }, () => Array(rows).fill(0));
  
  data.forEach(d => {
    const dDate = new Date(d.date + 'T12:00:00');
    dDate.setHours(0,0,0,0);
    const diffTime = today.getTime() - dDate.getTime();
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays >= 0 && diffDays < cols * rows) {
      const c = cols - 1 - Math.floor(diffDays / 7);
      const r = (today.getDay() - (diffDays % 7) + 7) % 7;
      if (c >= 0 && c < cols && r >= 0 && r < rows) {
        grid[c][r] += d.count;
      }
    }
  });

  return (
    <View style={heatmapStyles.container}>
      {grid.map((col, cIdx) => (
        <View key={cIdx} style={heatmapStyles.col}>
          {col.map((val, rIdx) => {
             const opacity = val === 0 ? 0.05 : Math.min(val * 0.3 + 0.3, 1);
             return (
               <View key={rIdx} style={[heatmapStyles.cell, { backgroundColor: `rgba(34, 197, 94, ${opacity})` }]} />
             );
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
// BudgetProgress (Kept for compatibility)
// ──────────────────────────────────────────────────────────

interface BudgetProgressProps {
  name: string;
  icon?: string;
  spent: number;
  limit: number;
  color?: string;
}

export function BudgetProgress({ name, icon, spent, limit, color = '#2563EB' }: BudgetProgressProps) {
  const pct = limit > 0 ? Math.min((spent / limit) * 100, 100) : 0;
  const barColor = pct >= 90 ? '#EF4444' : pct >= 70 ? '#F59E0B' : '#22C55E';

  return (
    <View style={budgetStyles.container}>
      <View style={budgetStyles.top}>
        <Text style={budgetStyles.name}>{icon ? `${icon} ` : ''}{name}</Text>
        <Text style={budgetStyles.amounts}>${spent.toFixed(0)} / ${limit.toFixed(0)}</Text>
      </View>
      <View style={budgetStyles.track}>
        <View style={[budgetStyles.fill, { width: `${pct}%`, backgroundColor: barColor }]} />
      </View>
      <Text style={[budgetStyles.pctLabel, { color: barColor }]}>{pct.toFixed(0)}% usado</Text>
    </View>
  );
}

const budgetStyles = StyleSheet.create({
  container: { marginBottom: 20 },
  top: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 },
  name: { fontSize: 15, color: '#FAFAFA', fontWeight: '500', flex: 1 },
  amounts: { fontSize: 14, color: '#A1A1AA', fontWeight: '600' },
  track: { height: 8, backgroundColor: '#27272A', borderRadius: 4, overflow: 'hidden', marginBottom: 4 },
  fill: { height: 8, borderRadius: 4 },
  pctLabel: { fontSize: 11, fontWeight: '600', marginTop: 2 },
});
