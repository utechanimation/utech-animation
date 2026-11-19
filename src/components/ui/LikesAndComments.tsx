'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { Check, Heart, Link2, MessageCircle, X } from 'lucide-react'
import { createClient } from '@/lib/supabase'
import Avatar from './Avatar'

type Comment = {
  id: string
  user_id: string
  content: string
  created_at: string
  profiles?: { full_name?: string | null; username?: string | null; avatar_url?: string | null } | null
}

const CONFETTI = [
  { x: '-30px', y: '-26px', c: '#f9d423' },
  { x: '32px', y: '-22px', c: '#3fa9f5' },
  { x: '-36px', y: '12px', c: '#5bc236' },
  { x: '34px', y: '16px', c: '#f04b4b' },
  { x: '0px', y: '-38px', c: '#e9d5ff' },
  { x: '4px', y: '34px', c: '#8e5cf7' },
]

/**
 * Comments section plus the pinned action bar (like, comments, copy link).
 * On phones the bar sits where the tab bar normally is, within thumb reach.
 */
export default function LikesAndComments({
  portfolioId,
  title,
  initialLikes = 0,
  initialComments = 0,
}: {
  portfolioId: string
  title?: string
  initialLikes?: number
  initialComments?: number
}) {
  const [user, setUser] = useState<{ id: string } | null>(null)
  const [liked, setLiked] = useState(false)
  const [likeCount, setLikeCount] = useState(initialLikes)
  const [comments, setComments] = useState<Comment[] | null>(null)
  const [newComment, setNewComment] = useState('')
  const [posting, setPosting] = useState(false)
  const [burst, setBurst] = useState(0)
  const [copied, setCopied] = useState(false)
  const [supabase] = useState(() => createClient())

  useEffect(() => {
    const load = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      setUser(user)

      const { count } = await supabase
        .from('likes')
        .select('*', { count: 'exact', head: true })
        .eq('portfolio_id', portfolioId)
      setLikeCount(count ?? 0)

      if (user) {
        const { data } = await supabase
          .from('likes')
          .select('id')
          .eq('portfolio_id', portfolioId)
          .eq('user_id', user.id)
          .single()
        setLiked(!!data)
      }

      const { data: commentData } = await supabase
        .from('comments')
        .select('*, profiles(full_name, username, avatar_url)')
        .eq('portfolio_id', portfolioId)
        .order('created_at', { ascending: true })
      setComments(commentData ?? [])
    }
    load()
  }, [portfolioId, supabase])

  const toggleLike = async () => {
    if (!user) return
    if (liked) {
      await supabase.from('likes').delete()
        .eq('portfolio_id', portfolioId).eq('user_id', user.id)
      setLiked(false)
      setLikeCount(c => c - 1)
    } else {
      await supabase.from('likes').insert({ portfolio_id: portfolioId, user_id: user.id })
      setLiked(true)
      setLikeCount(c => c + 1)
      setBurst(b => b + 1)
    }
  }

  const copyLink = async () => {
    const url = window.location.href
    try {
      if (navigator.share && window.matchMedia('(pointer: coarse)').matches) {
        await navigator.share({ title: title ?? "UTech's Animation", url })
        return
      }
      await navigator.clipboard.writeText(url)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // Share sheet closed or clipboard blocked: nothing to do.
    }
  }

  const postComment = async () => {
    if (!newComment.trim() || !user) return
    setPosting(true)
    const { data } = await supabase
      .from('comments')
      .insert({ portfolio_id: portfolioId, user_id: user.id, content: newComment.trim() })
      .select('*, profiles(full_name, username, avatar_url)')
      .single()
    if (data) setComments(prev => [...(prev ?? []), data])
    setNewComment('')
    setPosting(false)
  }

  const deleteComment = async (id: string) => {
    await supabase.from('comments').delete().eq('id', id)
    setComments(prev => (prev ?? []).filter(c => c.id !== id))
  }

  const commentTotal = comments?.length ?? initialComments
  const likeLabel = `${likeCount} ${likeCount === 1 ? 'like' : 'likes'}`

  return (
    <>
      <section id="comments" aria-labelledby="comments-heading" className="mt-10 scroll-mt-24 border-t border-line pt-8">
        <h2 id="comments-heading" className="mb-5 text-2xl">
          Comments <span className="text-muted">({commentTotal})</span>
        </h2>

        <div className="mb-6 flex flex-col gap-3">
          {comments && comments.length === 0 && (
            <p className="text-sm text-muted">No comments yet. {user ? 'Be the first!' : ''}</p>
          )}
          {comments?.map(comment => (
            <div key={comment.id} className="card flex justify-between gap-3 px-4 py-3.5">
              <div className="min-w-0 flex-1">
                <div className="mb-1.5 flex items-center gap-2.5">
                  <Avatar url={comment.profiles?.avatar_url} name={comment.profiles?.full_name} size={30} />
                  <span className="truncate text-sm font-bold">{comment.profiles?.full_name}</span>
                  <span className="shrink-0 text-xs text-muted">
                    {new Date(comment.created_at).toLocaleDateString('en-JM', { month: 'short', day: 'numeric' })}
                  </span>
                </div>
                <p className="break-words text-[15px] leading-relaxed text-soft">{comment.content}</p>
              </div>
              {user?.id === comment.user_id && (
                <button
                  onClick={() => deleteComment(comment.id)}
                  aria-label="Delete your comment"
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-muted hover:bg-surface-2 hover:text-ink"
                >
                  <X size={16} aria-hidden />
                </button>
              )}
            </div>
          ))}
        </div>

        {user ? (
          <form
            className="flex gap-2"
            onSubmit={e => { e.preventDefault(); postComment() }}
          >
            <label htmlFor="new-comment" className="sr-only">Write a comment</label>
            <input
              id="new-comment"
              value={newComment}
              maxLength={1000}
              onChange={e => setNewComment(e.target.value)}
              placeholder="Write a comment…"
              className="field flex-1"
            />
            <button type="submit" disabled={posting || !newComment.trim()} className="btn btn-primary">
              Post
            </button>
          </form>
        ) : (
          <p className="rounded-2xl border-[1.5px] border-dashed border-line px-5 py-4 text-center text-sm text-muted">
            <Link href="/login" className="font-bold text-lilac">Sign in</Link> to like or comment.
          </p>
        )}
      </section>

      {/* Pinned action bar */}
      <div
        className="fixed inset-x-3 bottom-3 z-50 flex h-[68px] items-center gap-2 rounded-[22px] border border-[rgba(233,213,255,.16)] bg-[rgba(20,20,20,.94)] px-2.5 shadow-[0_16px_40px_rgba(0,0,0,.6)] backdrop-blur-md md:inset-x-auto md:left-1/2 md:w-[440px] md:-translate-x-1/2"
        style={{ marginBottom: 'env(safe-area-inset-bottom)' }}
      >
        {user ? (
          <button
            onClick={toggleLike}
            aria-pressed={liked}
            aria-label={liked ? `Unlike (${likeLabel})` : `Like (${likeLabel})`}
            className={`relative flex h-12 items-center gap-2 rounded-2xl px-3.5 text-sm font-extrabold transition-colors ${
              liked ? 'bg-[rgba(168,85,247,.22)] text-lilac' : 'text-soft hover:bg-surface-2'
            }`}
          >
            <span key={burst} className={`relative ${burst ? 'pop' : ''}`}>
              <Heart size={22} fill={liked ? 'currentColor' : 'none'} aria-hidden />
              {burst > 0 && CONFETTI.map((p, i) => (
                <span
                  key={i}
                  aria-hidden
                  className="confetti"
                  style={{ background: p.c, ['--x' as string]: p.x, ['--y' as string]: p.y }}
                />
              ))}
            </span>
            {likeCount}
          </button>
        ) : (
          <Link href="/login" aria-label={`Sign in to like (${likeLabel})`} className="flex h-12 items-center gap-2 rounded-2xl px-3.5 text-sm font-extrabold text-soft hover:bg-surface-2">
            <Heart size={22} aria-hidden />
            {likeCount}
          </Link>
        )}

        <a href="#comments" aria-label={`Comments (${commentTotal})`} className="flex h-12 items-center gap-2 rounded-2xl px-3.5 text-sm font-bold text-soft hover:bg-surface-2">
          <MessageCircle size={22} aria-hidden />
          {commentTotal}
        </a>

        <button onClick={copyLink} className="btn btn-primary ml-auto h-12 rounded-2xl">
          <span key={copied ? 'y' : 'n'} className={copied ? 'pop' : ''}>
            {copied ? <Check size={18} aria-hidden /> : <Link2 size={18} aria-hidden />}
          </span>
          {copied ? 'Copied!' : 'Copy link'}
        </button>
        <span className="sr-only" aria-live="polite">{copied ? 'Link copied' : ''}</span>
      </div>
    </>
  )
}
