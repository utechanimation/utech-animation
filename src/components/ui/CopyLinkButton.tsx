'use client'

import { useState } from 'react'
import { Check, Link2 } from 'lucide-react'

/** Copies the current page's address (or opens the phone's share sheet). */
export default function CopyLinkButton({ label = 'Copy link', title }: { label?: string; title?: string }) {
  const [copied, setCopied] = useState(false)

  const copy = async () => {
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

  return (
    <button type="button" onClick={copy} className="btn btn-primary flex-1 md:flex-none">
      <span key={copied ? 'y' : 'n'} className={copied ? 'pop' : ''}>
        {copied ? <Check size={18} aria-hidden /> : <Link2 size={18} aria-hidden />}
      </span>
      {copied ? 'Copied!' : label}
      <span className="sr-only" aria-live="polite">{copied ? 'Link copied' : ''}</span>
    </button>
  )
}
