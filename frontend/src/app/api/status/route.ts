export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const buildId = searchParams.get('build_id')
  const runId = searchParams.get('run_id') // Keep for backward compat

  const owner = process.env.GITHUB_OWNER
  const repo = process.env.GITHUB_REPO
  const workflow = process.env.WORKFLOW_FILE
  const token = process.env.GITHUB_TOKEN

  // If run_id is provided, get that specific run (backward compat)
  if (runId) {
    const r = await fetch(
      `https://api.github.com/repos/${owner}/${repo}/actions/runs/${runId}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/vnd.github+json',
        },
        cache: 'no-store',
      },
    )

    if (!r.ok) {
      return new Response(await r.text(), { status: r.status })
    }

    const run = await r.json()
    return Response.json({
      status: run.status,
      conclusion: run.conclusion,
      url: run.html_url,
      id: run.id,
      runId: run.id,
    })
  }

  // If build_id is provided, find the run that has this build_id
  // We check recent runs and look for matching tag in outputs
  if (buildId) {
    const expectedTag = `apk-${buildId}`

    // First check if the release exists (meaning build is complete)
    const relRes = await fetch(
      `https://api.github.com/repos/${owner}/${repo}/releases/tags/${expectedTag}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/vnd.github+json',
        },
        cache: 'no-store',
      },
    )

    if (relRes.ok) {
      // Release exists, build must be complete
      return Response.json({
        status: 'completed',
        conclusion: 'success',
        buildId,
      })
    }

    // Release doesn't exist yet - check recent workflow runs to find our run
    const runsRes = await fetch(
      `https://api.github.com/repos/${owner}/${repo}/actions/workflows/${workflow}/runs?per_page=10`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/vnd.github+json',
        },
        cache: 'no-store',
      },
    )

    if (runsRes.ok) {
      const data = await runsRes.json()
      const runs = data.workflow_runs || []

      // Check if any in-progress or queued runs exist
      // We can't easily match build_id to run without checking job logs,
      // so we return the most recent non-completed run status as a proxy
      const activeRun = runs.find(
        (r: any) => r.status === 'queued' || r.status === 'in_progress',
      )

      if (activeRun) {
        return Response.json({
          status: activeRun.status,
          conclusion: activeRun.conclusion,
          url: activeRun.html_url,
          runId: activeRun.id,
          buildId,
        })
      }

      // No active runs - check if the most recent completed run failed
      const recentRun = runs[0]
      if (recentRun && recentRun.status === 'completed') {
        // If completed but no release, it might have failed
        return Response.json({
          status: recentRun.status,
          conclusion: recentRun.conclusion,
          url: recentRun.html_url,
          runId: recentRun.id,
          buildId,
        })
      }
    }

    // Default: still queued/waiting
    return Response.json({
      status: 'queued',
      conclusion: null,
      buildId,
    })
  }

  // Fallback: get the latest run (for backward compatibility)
  const r = await fetch(
    `https://api.github.com/repos/${owner}/${repo}/actions/workflows/${workflow}/runs?per_page=1`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
      },
      cache: 'no-store',
    },
  )

  if (!r.ok) {
    return new Response(await r.text(), { status: r.status })
  }

  const data = await r.json()
  const run = data.workflow_runs?.[0]
  if (!run) return Response.json({ status: 'none' })

  return Response.json({
    status: run.status,
    conclusion: run.conclusion,
    url: run.html_url,
    id: run.id,
    runId: run.id,
  })
}
