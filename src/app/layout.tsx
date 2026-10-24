import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'عيادة مرساة — د. مارينا نبيه نمر | أخصائي الطب النفسي وعلاج الإدمان',
  description:
    'عيادة مرساة للطب النفسي وعلاج الإدمان والعلاج المعرفي السلوكي (CBT) — د. مارينا نبيه نمر (سوهاج)',
  icons: {
    icon: '/assets/logo.jpg',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ar" dir="rtl">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
