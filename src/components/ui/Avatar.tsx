'use client'

import { useState, useRef } from 'react'
import { createClient } from '@/lib/supabase'

interface AvatarProps {
  url?: string | null
  name?: string | null
  size?: number
  editable?: boolean
  userId?: string
  onUpdate?: (url: string) => void
  /** Rainbow ring around the photo (profiles, owner cards). */
  ring?: boolean
}

export default function Avatar({ url, name, size = 44, editable = false, userId, onUpdate, ring = false }: AvatarProps) {
  const [preview, setPreview] = useState<string | null>(url ?? null)
  const [uploading, setUploading] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  const supabase = createClient()

  const initial = name?.trim()?.[0]?.toUpperCase() ?? null

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !userId) return
    setUploading(true)

    const ext = file.name.split('.').pop()
    const filePath = `${userId}/avatar.${ext}`

    const { error } = await supabase.storage
      .from('portfolios')
      .upload(filePath, file, { upsert: true })

    if (!error) {
      const { data: { publicUrl } } = supabase.storage
        .from('portfolios')
        .getPublicUrl(filePath)

      // Add cache-bust so browser doesn't show old avatar
      const urlWithBust = `${publicUrl}?t=${Date.now()}`

      await supabase.from('profiles')
        .update({ avatar_url: publicUrl })
        .eq('id', userId)

      setPreview(urlWithBust)
      onUpdate?.(publicUrl)
    }
    setUploading(false)
  }

  const ringWidth = Math.max(2, Math.round(size / 26))

  return (
    <div style={{
      position: 'relative', flexShrink: 0, borderRadius: '50%',
      alignSelf: 'flex-start', width: 'fit-content', height: 'fit-content', lineHeight: 0,
      ...(ring ? {
        padding: ringWidth,
        background: 'conic-gradient(#f04b4b,#f7931e,#f9d423,#5bc236,#3fa9f5,#8e5cf7,#e040a0,#f04b4b)',
      } : {}),
    }}>
      <div
        onClick={() => editable && inputRef.current?.click()}
        style={{
          width: size, height: size, borderRadius: '50%',
          background: preview ? 'var(--surface-2)' : 'var(--accent-hover)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: size * 0.4, fontWeight: 800, color: '#fff',
          fontFamily: 'var(--font-display)',
          overflow: 'hidden', flexShrink: 0,
          cursor: editable ? 'pointer' : 'default',
          border: editable ? '2px dashed var(--accent)' : ring ? `${ringWidth}px solid var(--bg)` : 'none',
          boxSizing: 'border-box',
          transition: 'opacity 0.15s'
        }}
      >
        {preview ? (
          <img
            src={preview}
            alt={name ?? ''}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
            onError={() => setPreview(null)}
          />
        ) : initial ? (
          <span>{initial}</span>
        ) : (
          <span style={{ fontSize: size * 0.3 }}>?</span>
        )}
      </div>

      {editable && (
        <>
          <div style={{
            position: 'absolute', inset: 0, borderRadius: '50%',
            background: 'rgba(0,0,0,0.4)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            opacity: uploading ? 1 : 0,
            transition: 'opacity 0.15s',
            pointerEvents: 'none'
          }}>
            <span style={{ fontSize: 12, color: '#fff' }}>
              {uploading ? '...' : '✎'}
            </span>
          </div>
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            style={{ display: 'none' }}
            onChange={handleUpload}
          />
        </>
      )}
    </div>
  )
}