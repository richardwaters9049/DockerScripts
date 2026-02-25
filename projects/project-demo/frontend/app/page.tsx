'use client'

import { useEffect, useState } from "react"
import { motion, AnimatePresence } from "framer-motion"

export type User = {
  id: number
  name: string
  email: string
}

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000"

async function getUsers(): Promise<User[]> {
  const res = await fetch(`${API_BASE}/users`, { cache: "no-store" })
  if (!res.ok) throw new Error("Failed to fetch users")
  return res.json()
}

function UserCard({ user }: { user: User }) {
  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      whileHover={{ scale: 1.05 }}
      className="bg-white shadow-lg rounded-xl p-6 border border-gray-200"
    >
      <h3 className="text-lg font-semibold text-gray-800">{user.name}</h3>
      <p className="text-gray-500">{user.email}</p>
    </motion.div>
  )
}

export default function Page() {
  const [users, setUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getUsers()
      .then(setUsers)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  return (
    <main className="min-h-screen bg-slate-900 p-10">
      <h1 className="text-4xl font-bold text-white mb-6">
        Users Dashboard
      </h1>

      {loading ? (
        <p className="text-white">Loading users...</p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
          <AnimatePresence>
            {users.map((user) => (
              <UserCard key={user.id} user={user} />
            ))}
          </AnimatePresence>
        </div>
      )}
    </main>
  )
}
