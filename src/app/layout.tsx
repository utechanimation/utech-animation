import type { Metadata, Viewport } from 'next'
import localFont from 'next/font/local'
import Link from 'next/link'
import './globals.css'
import Navbar from '@/components/layout/Navbar'
import MotionProvider from '@/components/layout/MotionProvider'
import Owl from '@/components/brand/Owl'

// Font files live in src/app/fonts (see the README there). next/font serves
// them from our own domain, so visitors' browsers never contact Google.
const baloo = localFont({
  src: [
    { path: './fonts/baloo-2-latin-700-normal.woff2', weight: '700', style: 'normal' },
    { path: './fonts/baloo-2-latin-800-normal.woff2', weight: '800', style: 'normal' },
  ],
  variable: '--font-baloo',
  display: 'swap',
})
const inter = localFont({
  src: './fonts/inter-latin-wght-normal.woff2',
  weight: '100 900',
  variable: '--font-inter',
  display: 'swap',
})

export const metadata: Metadata = {
  title: "UTech's Animation — Student Portfolios",
  description: 'Browse animation portfolios from University of Technology, Jamaica students.',
}

export const viewport: Viewport = {
  themeColor: '#0a0a0a',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${baloo.variable} ${inter.variable}`}>
      <body>
        <a href="#main" className="sr-only-focusable btn btn-primary fixed left-3 top-3 z-[70]">
          Skip to content
        </a>
        <MotionProvider>
          <Navbar />
          {/* pt = top bar height; pb leaves room for the phone tab bar */}
          <main id="main" className="pb-24 pt-16 md:pb-0">
            {children}
          </main>
        </MotionProvider>
        <footer className="border-t border-line px-6 pb-28 pt-8 md:pb-8">
          <div className="mx-auto flex max-w-[1200px] flex-wrap items-center justify-center gap-x-6 gap-y-3 text-[13px] text-muted">
            <span className="flex items-center gap-2">
              <Owl size={28} variant="mono" /><span>© {new Date().getFullYear()} UTech&apos;s Animation</span>
            </span>
            <Link href="/terms" className="underline underline-offset-4 hover:text-ink">
              Terms &amp; Conditions
            </Link>
          </div>
        </footer>
      </body>
    </html>
  )
}
