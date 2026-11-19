import { createServerSupabaseClient } from '@/lib/supabase-server'
import AnimatedCard, { MasonryGrid } from '@/components/ui/AnimatedCard'
import { SearchBox, FilterBar } from '@/components/ui/SearchAndFilter'
import Link from 'next/link'
import Avatar from '@/components/ui/Avatar'
import { Drip, Stars } from '@/components/brand/Decor'
import EmptyState from '@/components/brand/EmptyState'

const HERO_WORD = 'Creativity.'
// One rainbow colour per letter, from the Brand Guidelines' "Creativity".
// (A clipped gradient can't paint letters that animate on their own.)
const LETTER_COLOURS = ['#f04b4b', '#f7931e', '#f9d423', '#5bc236', '#3fa9f5', '#8e5cf7', '#e040a0']

export default async function Home({
  searchParams
}: {
  searchParams: Promise<{ tag?: string; q?: string; year?: string; mode?: string }>
}) {
  const supabase = await createServerSupabaseClient()
  const params = await searchParams
  const activeTag = params.tag ?? null
  const query = params.q ?? null
  const activeYear = params.year ? parseInt(params.year) : null
  const mode = params.mode === 'profiles' ? 'profiles' : 'portfolios'

  const { data: tags } = await supabase.from('tags').select('*').order('name')

  const { data: yearData } = await supabase
    .from('portfolios').select('upload_year')
    .eq('visibility', 'public').eq('status', 'active')
    .order('upload_year', { ascending: false })
  const years = [...new Set(yearData?.map(p => p.upload_year).filter(Boolean))] as number[]

  // Profile search
  let profiles: any[] = []
  if (mode === 'profiles' && query) {
    const { data } = await supabase
      .from('profiles')
      .select('id, full_name, username, avatar_url, bio, year_of_study')
      .ilike('full_name', `%${query}%`)
      .limit(20)
    profiles = data ?? []
  }

  // Portfolio search
  let portfolioQuery = supabase
    .from('portfolios')
    .select(`
      id, title, slug, cover_image_url, created_at, upload_year,
      profiles (full_name, username, avatar_url),
      portfolio_tags (tags (name))
    `)
    .eq('visibility', 'public')
    .eq('status', 'active')
    .order('created_at', { ascending: false })

  if (query && mode === 'portfolios') portfolioQuery = portfolioQuery.ilike('title', `%${query}%`)
  if (activeYear) portfolioQuery = portfolioQuery.eq('upload_year', activeYear)

  const { data: portfolios } = await portfolioQuery

  const filtered = activeTag
    ? portfolios?.filter((p: any) =>
        p.portfolio_tags?.some((pt: any) => pt.tags.name === activeTag)
      )
    : portfolios

  const filters = { tag: activeTag, q: query, year: activeYear, mode } as const
  const count = filtered?.length ?? 0

  return (
    <>
      {/* Hero: nebula, drifting stars, "Creativity." hops in letter by letter */}
      <section className="nebula" aria-labelledby="hero-title">
        <Stars />
        <div className="mx-auto flex max-w-[1200px] flex-col gap-4 px-4 pb-6 pt-8 md:px-6 md:pb-12 md:pt-16">
          <p className="eyebrow">University of Technology, Jamaica</p>
          <h1 id="hero-title" className="leading-[.95]">
            <span className="block font-sans text-2xl font-light tracking-[.28em] md:text-3xl">EXPLORE OUR</span>
            <span className="block font-display text-[58px] font-extrabold md:text-[96px]" aria-label={HERO_WORD}>
              {HERO_WORD.split('').map((ch, i) => (
                <span
                  key={i}
                  aria-hidden
                  className="hop"
                  style={{ animationDelay: `${0.15 + i * 0.05}s`, color: LETTER_COLOURS[i % LETTER_COLOURS.length] }}
                >
                  {ch}
                </span>
              ))}
            </span>
          </h1>
          <p className="max-w-md text-[15px] leading-relaxed text-soft md:text-lg">
            Character design, 3D, illustration and motion from UTech&apos;s animation students.
          </p>
          <div className="mt-2">
            <SearchBox {...filters} />
          </div>
        </div>
      </section>
      <Drip />

      <div className="mx-auto max-w-[1200px] px-4 pb-16 pt-3 md:px-6">
        {mode === 'portfolios' && (
          <FilterBar {...filters} tags={tags ?? []} years={years} />
        )}

        {/* Student search results */}
        {mode === 'profiles' && (
          <div className="mt-6">
            {query ? (
              <>
                <p className="mb-4 text-sm text-muted" aria-live="polite">
                  {profiles.length} student{profiles.length !== 1 ? 's' : ''} matching &ldquo;{query}&rdquo;
                </p>
                {profiles.length > 0 ? (
                  <div className="grid grid-cols-[repeat(auto-fill,minmax(min(260px,100%),1fr))] gap-3">
                    {profiles.map(profile => (
                      <Link
                        key={profile.id}
                        href={`/profile/${profile.username}`}
                        className="card flex items-center gap-3.5 p-4 transition-colors hover:border-accent"
                      >
                        <Avatar url={profile.avatar_url} name={profile.full_name} size={48} ring />
                        <div className="min-w-0">
                          <p className="truncate text-[15px] font-bold">{profile.full_name}</p>
                          <p className="truncate text-[13px] text-muted">@{profile.username}</p>
                          {profile.year_of_study && <p className="text-xs font-semibold text-lilac">{profile.year_of_study}</p>}
                        </div>
                      </Link>
                    ))}
                  </div>
                ) : (
                  <EmptyState title="No students found">Nobody matches &ldquo;{query}&rdquo;. Try part of a first or last name.</EmptyState>
                )}
              </>
            ) : (
              <p className="py-10 text-center text-sm text-muted">Type a name to find a student.</p>
            )}
          </div>
        )}

        {/* Portfolio results */}
        {mode === 'portfolios' && (
          <>
            <p className="mb-4 mt-4 text-sm text-muted" aria-live="polite">
              {count} portfolio{count !== 1 ? 's' : ''}
              {activeTag ? ` in ${activeTag}` : ''}
              {activeYear ? ` from ${activeYear}` : ''}
              {query ? ` matching \u201c${query}\u201d` : ''}
            </p>
            {filtered && filtered.length > 0 ? (
              <MasonryGrid>
                {filtered.map((portfolio: any, i: number) => (
                  <AnimatedCard key={portfolio.id} portfolio={portfolio} index={i} />
                ))}
              </MasonryGrid>
            ) : (
              <EmptyState
                title={activeTag || query || activeYear ? 'Nothing here yet' : 'No portfolios yet'}
                action={<Link href="/upload" className="btn btn-primary">Post your work</Link>}
              >
                {activeTag ? `No portfolios tagged “${activeTag}” yet.` : 'Be the first to share your work.'}
              </EmptyState>
            )}
          </>
        )}
      </div>
    </>
  )
}
