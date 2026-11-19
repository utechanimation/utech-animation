'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { ImagePlus, X } from 'lucide-react'
import { createClient } from '@/lib/supabase'
import { BouncingBall } from '@/components/brand/Decor'

const TAGS = ['Character Design', 'Illustration', '3D Modelling', 'Video Editing', 'Graphic Design']
const MAX_TAGS = 3
const STEPS = ['Details', 'Tags', 'Media', 'Review'] as const

export default function Upload() {
  const [userId, setUserId] = useState<string | null>(null)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [selectedTags, setSelectedTags] = useState<string[]>([])
  const [coverFile, setCoverFile] = useState<File | null>(null)
  const [coverPreview, setCoverPreview] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [step, setStep] = useState(0)
  const router = useRouter()
  const [supabase] = useState(() => createClient())

  // Redirect if not logged in
  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) router.push('/login')
      else setUserId(data.user.id)
    })
  }, [])

  const toggleTag = (tag: string) => {
    setSelectedTags(prev =>
      prev.includes(tag)
        ? prev.filter(t => t !== tag)
        : prev.length >= MAX_TAGS ? prev : [...prev, tag]
    )
  }

  const [mediaFiles, setMediaFiles] = useState<File[]>([])
  const [mediaPreviews, setMediaPreviews] = useState<string[]>([])

  const handleMediaChange = (e: React.ChangeEvent<HTMLInputElement>) => {
  const files = Array.from(e.target.files ?? [])
  if (!files.length) return
  setMediaFiles(prev => [...prev, ...files])
  files.forEach(file => {
      setMediaPreviews(prev => [...prev, URL.createObjectURL(file)])
  })
  }

    const removeMedia = (index: number) => {
    setMediaFiles(prev => prev.filter((_, i) => i !== index))
    setMediaPreviews(prev => prev.filter((_, i) => i !== index))
    }

  const handleCoverChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setCoverFile(file)
    setCoverPreview(URL.createObjectURL(file))
  }

  const slugify = (text: string) =>
    text.toLowerCase().trim()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-') +
    '-' + Date.now().toString(36)

  const handleSubmit = async () => {
    if (!title.trim()) { setError('Title is required'); return }
    if (!coverFile) { setError('Cover image is required'); return }
    if (selectedTags.length === 0) { setError('Select at least one tag'); return }
    if (selectedTags.length > MAX_TAGS) { setError(`Pick at most ${MAX_TAGS} tags`); return }
    if (!userId) return

    setLoading(true)
    setError('')

    try {
      // 1. Upload cover image to Supabase Storage
      const ext = coverFile.name.split('.').pop()
      const filePath = `${userId}/${Date.now()}.${ext}`
      const { error: uploadError } = await supabase.storage
        .from('portfolios')
        .upload(filePath, coverFile)

      if (uploadError) throw uploadError

      // 2. Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('portfolios')
        .getPublicUrl(filePath)

      // 3. Create portfolio record
      const slug = slugify(title)
      const { data: portfolio, error: portfolioError } = await supabase
        .from('portfolios')
        .insert({
          user_id: userId,
          title: title.trim(),
          description: description.trim(),
          cover_image_url: publicUrl,
          slug,
          is_public: true
        })
        .select()
        .single()

      if (portfolioError) throw portfolioError

      // 4. Get tag IDs and link them
      const { data: tagData } = await supabase
        .from('tags')
        .select('id, name')
        .in('name', selectedTags)

      if (tagData && tagData.length > 0) {
        await supabase.from('portfolio_tags').insert(
          tagData.map(tag => ({ portfolio_id: portfolio.id, tag_id: tag.id }))
        )
      }

      // 5. Upload media items
      if (mediaFiles.length > 0) {
        const itemUploads = await Promise.all(
          mediaFiles.map(async (file, index) => {
            const ext = file.name.split('.').pop()
            const filePath = `${userId}/items/${Date.now()}-${index}.${ext}`
            await supabase.storage.from('portfolios').upload(filePath, file)
            const { data: { publicUrl } } = supabase.storage
              .from('portfolios').getPublicUrl(filePath)
            const type = file.type.startsWith('video') ? 'video' : 'image'
            return { portfolio_id: portfolio.id, type, url: publicUrl, display_order: index }
          })
        )
        await supabase.from('portfolio_items').insert(itemUploads)
      }

      // 6. Done — go to the public portfolio page
      router.push(`/portfolio/${slug}`)

    } catch (err: any) {
      setError(err.message || 'Something went wrong')
      setLoading(false)
    }
  }

  // Check the current step before moving on, so mistakes show up early.
  const stepError = (): string => {
    if (step === 0 && !title.trim()) return 'Give your portfolio a title.'
    if (step === 1 && selectedTags.length === 0) return 'Pick at least one tag.'
    if (step === 2 && !coverFile) return 'Add a cover image.'
    return ''
  }
  const next = () => {
    const problem = stepError()
    setError(problem)
    if (!problem) setStep(s => Math.min(s + 1, STEPS.length - 1))
  }
  const back = () => { setError(''); setStep(s => Math.max(s - 1, 0)) }

  if (loading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <BouncingBall label="Uploading your work" />
      </div>
    )
  }

  return (
    <div className="mx-auto flex max-w-[680px] flex-col px-4 pb-10 pt-5 md:px-6 md:pt-10">
      <div className="mb-4 flex items-center gap-3">
        <Link href="/dashboard" aria-label="Cancel and go back to My work" className="flex h-11 w-11 items-center justify-center rounded-[14px] bg-surface-2 hover:bg-[#262626]">
          <X size={18} aria-hidden />
        </Link>
        <h1 className="text-[28px] md:text-4xl">New portfolio</h1>
      </div>

      {/* Steps look like frames on a strip of film */}
      <ol aria-label="Steps" className="mb-6 flex gap-1.5 rounded-xl bg-black p-2">
        {STEPS.map((label, i) => {
          const state = i < step ? 'done' : i === step ? 'current' : 'todo'
          return (
            <li
              key={label}
              aria-current={state === 'current' ? 'step' : undefined}
              className={`flex h-12 flex-1 flex-col items-center justify-center rounded-md text-[10px] font-bold transition-transform ${
                state === 'current'
                  ? '-rotate-2 scale-105 bg-accent-hover text-white shadow-[0_6px_18px_rgba(147,51,234,.5)]'
                  : state === 'done' ? 'bg-plum text-mist' : 'bg-surface-2 text-muted'
              }`}
            >
              <span className="font-display text-base leading-none">{i + 1}</span>
              {label}
            </li>
          )
        })}
      </ol>

      <div className="flex flex-col gap-5">
        {step === 0 && (
          <>
            <div className="flex flex-col gap-1.5">
              <label htmlFor="title" className="label">Title</label>
              <input
                id="title" className="field" value={title} maxLength={120}
                placeholder="e.g. Year 2 character design"
                onChange={e => setTitle(e.target.value)}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label htmlFor="description" className="label">Description <span className="font-normal text-muted">(optional)</span></label>
              <textarea
                id="description" className="field min-h-[140px] resize-y" value={description} maxLength={3000}
                placeholder="Your process, tools, what inspired it…"
                onChange={e => setDescription(e.target.value)}
              />
            </div>
          </>
        )}

        {step === 1 && (
          <fieldset className="flex flex-col gap-3">
            <legend className="label mb-3">
              Pick 1 to {MAX_TAGS} tags <span className="font-normal text-muted">({selectedTags.length}/{MAX_TAGS})</span>
            </legend>
            <div className="sticker-row flex flex-wrap gap-2.5">
              {TAGS.map(tag => {
                const active = selectedTags.includes(tag)
                const full = !active && selectedTags.length >= MAX_TAGS
                return (
                  <button key={tag} type="button" aria-pressed={active} disabled={full} onClick={() => toggleTag(tag)} className="sticker disabled:opacity-40">
                    {tag}
                  </button>
                )
              })}
            </div>
          </fieldset>
        )}

        {step === 2 && (
          <>
            <div className="flex flex-col gap-1.5">
              <span className="label" id="cover-label">Cover image</span>
              {coverPreview ? (
                <div className="relative">
                  <img src={coverPreview} alt="Cover preview" className="h-56 w-full rounded-[18px] object-cover md:h-72" />
                  <button
                    type="button"
                    onClick={() => { setCoverFile(null); setCoverPreview(null) }}
                    className="btn btn-sm absolute right-2.5 top-2.5 bg-[rgba(10,10,10,.75)] text-white"
                  >
                    Change
                  </button>
                </div>
              ) : (
                <label className="flex h-48 cursor-pointer flex-col items-center justify-center gap-2 rounded-[20px] border-2 border-dashed border-[rgba(233,213,255,.35)] bg-surface text-center transition-colors hover:border-accent focus-within:border-accent">
                  <span className="flex h-12 w-12 -rotate-6 items-center justify-center rounded-2xl bg-accent-hover text-white"><ImagePlus size={24} aria-hidden /></span>
                  <span className="text-[15px] font-extrabold">Add a cover image</span>
                  <span className="text-xs text-muted">JPG, PNG or WebP</span>
                  <input type="file" accept="image/*" className="sr-only" aria-labelledby="cover-label" onChange={handleCoverChange} />
                </label>
              )}
            </div>

            <div className="flex flex-col gap-2.5">
              <span className="label" id="media-label">More images or clips <span className="font-normal text-muted">(optional)</span></span>
              {mediaPreviews.length > 0 && (
                <div className="grid grid-cols-3 gap-2.5">
                  {mediaPreviews.map((src, i) => (
                    <div key={i} className="relative overflow-hidden rounded-xl">
                      {mediaFiles[i]?.type.startsWith('video') ? (
                        <video src={src} muted className="h-24 w-full object-cover" />
                      ) : (
                        <img src={src} alt="" className="h-24 w-full object-cover" />
                      )}
                      <button
                        type="button"
                        onClick={() => removeMedia(i)}
                        aria-label={`Remove item ${i + 1}`}
                        className="absolute right-1 top-1 flex h-8 w-8 items-center justify-center rounded-full bg-[rgba(10,10,10,.75)] text-white"
                      >
                        <X size={14} aria-hidden />
                      </button>
                    </div>
                  ))}
                </div>
              )}
              <label className="btn btn-ghost cursor-pointer border-dashed focus-within:border-accent">
                <ImagePlus size={18} aria-hidden /> Add images or clips
                <input type="file" accept="image/*,video/*" multiple className="sr-only" aria-labelledby="media-label" onChange={handleMediaChange} />
              </label>
            </div>
          </>
        )}

        {step === 3 && (
          <div className="card overflow-hidden">
            {coverPreview && <img src={coverPreview} alt="" className="h-48 w-full object-cover" />}
            <div className="flex flex-col gap-3 p-4">
              <p className="font-display text-2xl font-extrabold leading-tight">{title}</p>
              <div className="sticker-row flex flex-wrap gap-2">
                {selectedTags.map(t => <span key={t} className="sticker sticker-sm is-active">{t}</span>)}
              </div>
              {description && <p className="whitespace-pre-line text-sm text-soft">{description}</p>}
              <p className="text-[13px] text-muted">
                {mediaFiles.length} extra item{mediaFiles.length !== 1 ? 's' : ''} · goes live on your profile as soon as you publish
              </p>
            </div>
          </div>
        )}

        {error && <p role="alert" className="text-[13px] font-semibold text-[var(--danger-text)]">{error}</p>}

        <div className="mt-2 flex gap-2.5">
          {step > 0 && (
            <button type="button" onClick={back} className="btn btn-ghost h-[52px]">Back</button>
          )}
          {step < STEPS.length - 1 ? (
            <button type="button" onClick={next} className="btn btn-primary h-[52px] flex-1">
              Continue to {STEPS[step + 1].toLowerCase()}
            </button>
          ) : (
            <button type="button" onClick={handleSubmit} disabled={loading} className="btn btn-primary h-[52px] flex-1">
              Publish portfolio
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
