import type { Metadata } from 'next';
import { IBM_Plex_Sans } from 'next/font/google';
import './globals.css';

const ibmPlex = IBM_Plex_Sans({
  subsets: ['latin'],
  weight: ['300', '400', '500', '600', '700'],
  variable: '--font-ibm-plex',
  display: 'swap',
});

export const metadata: Metadata = {
  title: { default: "Jojo's Finance", template: "%s | Jojo's Finance" },
  description: 'Manejo de finanzas personales para parejas — sincronizado en tiempo real.',
  keywords: ['finanzas', 'presupuesto', 'pareja', 'gastos', 'ahorros'],
  viewport: 'width=device-width, initial-scale=1',
  themeColor: '#09090B',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" className="dark">
      <body className={`${ibmPlex.variable} font-sans antialiased bg-bg-base text-text-primary`}>
        {children}
      </body>
    </html>
  );
}
