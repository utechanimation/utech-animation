import { createServerSupabaseClient } from '@/lib/supabase-server'
import { notFound } from 'next/navigation'
import AnimatedCard, { MasonryGrid } from '@/components/ui/AnimatedCard'
import Avatar from '@/components/ui/Avatar'
import CopyLinkButton from '@/components/ui/CopyLinkButton'
import { Drip, Stars } from '@/components/brand/Decor'
import EmptyState from '@/components/brand/EmptyState'

export default async function ProfilePage({ params }: { params: Promise<{ username: string }> }) {
  const supabase = await createServerSupabaseClient()
  const { username } = await params

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('username', username)
    .single()

  if (!profile) notFound()

  const { data: portfolios } = await supabase
    .from('portfolios')
    .select(`
      id, title, slug, cover_image_url, created_at,
      profiles (full_name, username),
      portfolio_tags (tags (name))
    `)
    .eq('user_id', profile.id)
    .eq('visibility', 'public')
    .eq('status', 'active')
    .order('created_at', { ascending: false })

  const { count: totalLikes } = await supabase
    .from('likes')
    .select('*, portfolios!inner(user_id)', { count: 'exact', head: true })
    .eq('portfolios.user_id', profile.id)

  const stats = [
    { value: portfolios?.length ?? 0, label: portfolios?.length === 1 ? 'portfolio' : 'portfolios' },
    { value: totalLikes ?? 0, label: totalLikes === 1 ? 'like' : 'likes' },
  ]

  return (
    <>
      {/* Space banner with a paint drip */}
      <div className="nebula h-36 md:h-52" aria-hidden>
        <Stars />
      </div>
      <Drip />

      <div className="mx-auto max-w-[1200px] px-4 pb-16 md:px-6">
        <header className="relative -mt-20 flex flex-col gap-4 md:-mt-24 md:flex-row md:items-end md:gap-7">
          <Avatar url={profile.avatar_url} name={profile.full_name} size={112} ring />
          <div className="flex-1">
            <h1 className="text-[34px] md:text-5xl">{profile.full_name}</h1>
            <p className="mt-1 text-[13px] text-muted md:text-sm">
              @{profile.username}
              {profile.year_of_study && ` · ${profile.year_of_study}`}
              {" · UTech's Animation"}
            </p>
          </div>
        </header>

        {profile.bio && (
          <p className="mt-4 max-w-xl whitespace-pre-line text-[15px] leading-relaxed text-soft">{profile.bio}</p>
        )}

        <div className="mt-5 flex flex-wrap items-stretch gap-2.5">
          <CopyLinkButton label="Copy profile link" title={`${profile.full_name} — UTech's Animation`} />
          <dl className="card flex items-center gap-5 px-4 py-2">
            {stats.map(stat => (
              <div key={stat.label} className="flex flex-col-reverse items-center">
                <dt className="text-[11px] text-muted">{stat.label}</dt>
                <dd className="font-display text-xl font-extrabold leading-none">{stat.value}</dd>
              </div>
            ))}
          </dl>
        </div>

        <h2 className="mb-4 mt-10 text-2xl">Work</h2>
        {portfolios && portfolios.length > 0 ? (
          <MasonryGrid>
            {portfolios.map((portfolio: any, i: number) => (
              <AnimatedCard key={portfolio.id} portfolio={portfolio} index={i} />
            ))}
          </MasonryGrid>
        ) : (
          <EmptyState title="No public work yet">Check back soon.</EmptyState>
        )}
      </div>
    </>
  )
}
