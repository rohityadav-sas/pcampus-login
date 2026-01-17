import { NextRequest } from 'next/server'

export async function POST(request: NextRequest) {
  const owner = process.env.GITHUB_OWNER
  const repo = process.env.GITHUB_REPO
  const workflow = process.env.WORKFLOW_FILE
  const token = process.env.GITHUB_TOKEN

  // Parse credentials from request body
  let username = ''
  let password = ''

  try {
    const body = await request.json()
    username = body.username || ''
    password = body.password || ''
  } catch {
    return new Response('Invalid JSON body', { status: 400 })
  }

  if (!username || !password) {
    return new Response('Username and password are required', { status: 400 })
  }

  const r = await fetch(
    `https://api.github.com/repos/${owner}/${repo}/actions/workflows/${workflow}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ref: 'main',
        inputs: {
          username,
          password,
        },
      }),
    },
  )

  if (!r.ok) {
    return new Response(await r.text(), { status: r.status })
  }
  return Response.json({ ok: true })
}
