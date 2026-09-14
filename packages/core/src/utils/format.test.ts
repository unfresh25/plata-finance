import { describe, expect, test } from 'bun:test';
import {
  formatCurrency,
  formatCompactCurrency,
  percentage,
  budgetStatus,
  monthRange,
} from './format';

describe('percentage', () => {
  test('divide normalmente', () => {
    expect(percentage(25, 100)).toBe(25);
    expect(percentage(1, 3)).toBe(33);
  });

  test('protege la división por cero', () => {
    expect(percentage(50, 0)).toBe(0);
  });

  test('se satura en 100 (no supera el límite)', () => {
    expect(percentage(150, 100)).toBe(100);
  });

  test('redondea al entero más cercano', () => {
    expect(percentage(2, 3)).toBe(67); // 66.66 → 67
  });
});

describe('budgetStatus', () => {
  test('safe por debajo del 80%', () => {
    expect(budgetStatus(50, 100)).toBe('safe');
    expect(budgetStatus(79, 100)).toBe('safe');
  });

  test('warning entre 80% y 99%', () => {
    expect(budgetStatus(80, 100)).toBe('warning');
    expect(budgetStatus(99, 100)).toBe('warning');
  });

  test('danger al 100% o más', () => {
    expect(budgetStatus(100, 100)).toBe('danger');
    expect(budgetStatus(200, 100)).toBe('danger');
  });

  test('límite cero → safe (0%)', () => {
    expect(budgetStatus(0, 0)).toBe('safe');
  });
});

describe('formatCurrency', () => {
  test('formatea sin decimales cuando es entero', () => {
    // El separador exacto varía por locale; validamos que no rompe y no añade centavos.
    const out = formatCurrency(1000, 'USD', 'en');
    expect(out).toContain('1,000');
    expect(out).not.toContain('.00');
  });

  test('conserva hasta 2 decimales', () => {
    const out = formatCurrency(1000.5, 'USD', 'en');
    expect(out).toContain('1,000.5');
  });

  test('maneja negativos', () => {
    const out = formatCurrency(-50, 'USD', 'en');
    expect(out).toContain('50');
    expect(out).toContain('-');
  });
});

describe('formatCompactCurrency', () => {
  test('millones', () => {
    expect(formatCompactCurrency(2_500_000)).toBe('2.5M');
  });
  test('miles', () => {
    expect(formatCompactCurrency(1_500)).toBe('1.5K');
  });
  test('menos de mil sin sufijo', () => {
    expect(formatCompactCurrency(999)).toBe('999');
  });
});

describe('monthRange', () => {
  test('devuelve primer y último día del mes en formato ISO corto', () => {
    const { start, end } = monthRange(new Date(2026, 1, 15)); // febrero 2026
    expect(start).toBe('2026-02-01');
    expect(end).toBe('2026-02-28'); // 2026 no es bisiesto
  });

  test('maneja diciembre correctamente', () => {
    const { start, end } = monthRange(new Date(2026, 11, 10));
    expect(start).toBe('2026-12-01');
    expect(end).toBe('2026-12-31');
  });
});
