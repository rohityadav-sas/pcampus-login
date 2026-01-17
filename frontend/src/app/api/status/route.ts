export async function GET() {
    const owner = process.env.GITHUB_OWNER;
    const repo = process.env.GITHUB_REPO;
    const workflow = process.env.WORKFLOW_FILE;
    const token = process.env.GITHUB_TOKEN;

    const r = await fetch(
        `https://api.github.com/repos/${owner}/${repo}/actions/workflows/${workflow}/runs?per_page=1`,
        {
            headers: {
                Authorization: `Bearer ${token}`,
                Accept: "application/vnd.github+json",
            },
            cache: "no-store",
        }
    );

    if (!r.ok) {
        return new Response(await r.text(), { status: r.status });
    }

    const data = await r.json();
    const run = data.workflow_runs?.[0];
    if (!run) return Response.json({ status: "none" });

    return Response.json({
        status: run.status,         // queued | in_progress | completed
        conclusion: run.conclusion, // success | failure | null
        url: run.html_url,
        id: run.id,
    });
}
