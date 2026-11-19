'use client'

import Link from 'next/link'
import { motion } from 'framer-motion'
import { ImageOff } from 'lucide-react'

type CardPortfolio = {
  id: string
  title: string
  slug: string
  cover_image_url?: string | null
  profiles?: { full_name?: string | null; username?: string | null } | null
  portfolio_tags?: { tags: { name: string } }[] | null
}

/**
 * A portfolio card for the free-flow (masonry) grid. The cover keeps its own
 * shape, so cards end up different heights. Cards float in as they scroll
 * into view and lift slightly on hover.
 */
export default function AnimatedCard({ portfolio, index = 0 }: { portfolio: CardPortfolio; index?: number }) {
  const owner = portfolio.profiles
  const tags = portfolio.portfolio_tags?.map(pt => pt.tags.name) ?? []

  return (
    <motion.article
      initial={{ opacity: 0, y: 28, rotate: 1.5 }}
      whileInView={{ opacity: 1, y: 0, rotate: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.55, delay: (index % 4) * 0.06, ease: [0.2, 0.8, 0.2, 1] }}
      whileHover={{ y: -6, rotate: -0.6, transition: { duration: 0.2 } }}
      className="mb-3 break-inside-avoid md:mb-5"
    >
      <Link href={`/portfolio/${portfolio.slug}`} className="group block">
        <div className="relative overflow-hidden rounded-[18px] bg-surface-2">
          {portfolio.cover_image_url ? (
            <img
              src={portfolio.cover_image_url}
              alt=""
              loading="lazy"
              className="block h-auto w-full transition-transform duration-500 group-hover:scale-[1.04]"
            />
          ) : (
            <div className="flex aspect-[4/5] items-center justify-center text-muted">
              <ImageOff size={28} aria-hidden />
            </div>
          )}
          {tags[0] && (
            <span className="badge absolute bottom-2.5 left-2.5 bg-[rgba(10,10,10,.72)] text-ink backdrop-blur-sm">
              {tags[0]}
            </span>
          )}
        </div>
        <h3 className="mt-2 font-sans text-sm font-bold leading-snug text-ink md:text-[15px]">
          {portfolio.title}
        </h3>
      </Link>
      {owner?.username && (
        <Link href={`/profile/${owner.username}`} className="text-xs text-muted hover:text-lilac md:text-[13px]">
          {owner.full_name ?? `@${owner.username}`}
        </Link>
      )}
    </motion.article>
  )
}

/** CSS-columns masonry: 2 columns on phones, up to 4 on wide screens. */
export function MasonryGrid({ children }: { children: React.ReactNode }) {
  return <div className="columns-2 gap-3 md:columns-3 md:gap-5 xl:columns-4">{children}</div>
}
