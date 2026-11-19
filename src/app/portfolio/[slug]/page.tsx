import { createServerSupabaseClient } from '@/lib/supabase-server'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import Lightbox from '@/components/ui/Lightbox'
import LikesAndComments from '@/components/ui/LikesAndComments'
import ReportButton from '@/components/ui/ReportButton'
import Avatar from '@/components/ui/Avatar'
import { Drip, DripReveal } from '@/components/brand/Decor'
import { AlertTriangle, ArrowLeft } from 'lucide-react'

export default async function PortfolioPage({ params }: { params: Promise<{ slug: string }> }) {
  const supabase = await createServerSupabaseClient()
  const { slug } = await params

  const { data: portfolio } = await supabase
    .from('portfolios')
    .select(`
      *,
      profiles (id, full_name, username, bio, avatar_url, year_of_study),
      portfolio_tags (tags (name)),
      portfolio_items (id, type, url, caption, display_order),
      takedowns (id, reason, appeal_status, appeal_message, appeal_denied_at, scheduled_wipe_at),
      warnings (id, reason, duration_days, expires_at, created_at)
    `)
    .eq('slug', slug)
    .neq('visibility', 'private')
    .not('status', 'in', '("taken_down","denied_appeal")')
    .single()

  if (!portfolio) notFound()

  const { count: likeCount } = await supabase
    .from('likes')
    .select('*', { count: 'exact', head: true })
    .eq('portfolio_id', portfolio.id)

  const { count: commentCount } = await supabase
    .from('comments')
    .select('*', { count: 'exact', head: true })
    .eq('portfolio_id', portfolio.id)

  const tags = portfolio.portfolio_tags?.map((pt: any) => pt.tags.name) ?? []
  const owner = portfolio.profiles as any
  const activeWarning = portfolio.warnings?.find((w: any) => new Date(w.expires_at) > new Date())

  const items = (portfolio.portfolio_items ?? []).sort((a: any, b: any) => a.display_order - b.display_order)

  return (
    <article>
      <DripReveal />

      {/* Cover goes edge to edge; a paint drip leads into the content */}
      <div className="relative">
        <div className="absolute inset-x-0 top-0 z-10 mx-auto flex max-w-[1200px] px-4 pt-4 md:px-6">
          <Link href="/" aria-label="Back to Explore" className="flex h-11 w-11 items-center justify-center rounded-[14px] bg-[rgba(10,10,10,.6)] backdrop-blur-sm hover:bg-[rgba(10,10,10,.8)]">
            <ArrowLeft size={20} aria-hidden />
          </Link>
        </div>
        {portfolio.cover_image_url ? (
          <img
            src={portfolio.cover_image_url}
            alt={`Cover image for ${portfolio.title}`}
            className="h-[300px] w-full object-cover md:h-[min(70vh,560px)]"
          />
        ) : (
          <div className="nebula h-40 md:h-56" />
        )}
        <Drip color="var(--accent-hover)" />
      </div>

      <div className="mx-auto max-w-[900px] px-4 pb-16 pt-2 md:px-6 md:pb-28">
        {/* Active warning banner (visible to owner via direct link) */}
        {activeWarning && (
          <div role="status" className="mb-5 flex gap-3 rounded-2xl border px-4 py-3" style={{ background: 'var(--warn-bg)', borderColor: 'var(--warn-border)', color: 'var(--warn-text)' }}>
            <AlertTriangle size={18} className="mt-0.5 shrink-0" aria-hidden />
            <div className="text-[13px]">
              <p className="font-bold">This portfolio has an active warning</p>
              <p>
                Reason: {activeWarning.reason} · Expires{' '}
                {new Date(activeWarning.expires_at).toLocaleDateString('en-JM', { month: 'short', day: 'numeric', year: 'numeric' })}
              </p>
            </div>
          </div>
        )}

        {tags.length > 0 && (
          <div className="sticker-row mb-3 flex flex-wrap gap-2">
            {tags.map((tag: string) => (
              <Link key={tag} href={`/?tag=${encodeURIComponent(tag)}`} className="sticker sticker-sm">{tag}</Link>
            ))}
          </div>
        )}

        <h1 className="text-[36px] md:text-5xl">{portfolio.title}</h1>

        <div className="mt-5 flex flex-col gap-5 md:flex-row md:items-start md:justify-between">
          <Link
            href={`/profile/${owner?.username}`}
            className="card flex items-center gap-3 p-3 pr-4 transition-colors hover:border-accent md:order-2 md:min-w-[260px]"
          >
            <Avatar url={owner?.avatar_url} name={owner?.full_name} size={44} ring />
            <span className="flex min-w-0 flex-1 flex-col">
              <span className="truncate text-sm font-bold">{owner?.full_name}</span>
              <span className="truncate text-xs text-muted">
                @{owner?.username}{owner?.year_of_study ? ` · ${owner.year_of_study}` : ''}
              </span>
            </span>
            <span className="text-xs font-bold text-mist">View profile</span>
          </Link>

          {portfolio.description && (
            <p className="max-w-[620px] whitespace-pre-line text-[15px] leading-relaxed text-soft md:order-1 md:text-[17px]">
              {portfolio.description}
            </p>
          )}
        </div>

        {items.length > 0 && (
          <section className="mt-10" aria-labelledby="work-heading">
            <h2 id="work-heading" className="mb-4 text-2xl">Work</h2>
            <Lightbox items={items} />
          </section>
        )}

        <p className="mt-8 text-[13px] text-muted">
          Published {new Date(portfolio.created_at).toLocaleDateString('en-JM', { year: 'numeric', month: 'long', day: 'numeric' })}
        </p>

        <ReportButton portfolioId={portfolio.id} />
        <LikesAndComments
          portfolioId={portfolio.id}
          title={portfolio.title}
          initialLikes={likeCount ?? 0}
          initialComments={commentCount ?? 0}
        />
      </div>
    </article>
  )
}
