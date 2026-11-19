'use client'

import { useRouter } from 'next/navigation'
import { LogOut } from 'lucide-react'
import { createClient } from '@/lib/supabase'

/** Sign-out for phones, where the top bar has no room for it. */
export default function SignOutButton({ className = '' }: { className?: string }) {
  const router = useRouter()
  const signOut = async () => {
    await createClient().auth.signOut()
    router.push('/')
    router.refresh()
  }
  return (
    <button type="button" onClick={signOut} className={`btn btn-ghost ${className}`}>
      <LogOut size={18} aria-hidden /> Sign out
    </button>
  )
}
