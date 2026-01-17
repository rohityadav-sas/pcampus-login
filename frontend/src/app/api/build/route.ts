export async function POST() {
    const owner = process.env.GITHUB_OWNER;
    const repo = process.env.GITHUB_REPO;
    const workflow = process.env.WORKFLOW_FILE;
    const token = process.env.GITHUB_TOKEN;

    const r = await fetch(
        `https://api.github.com/repos/${owner}/${repo}/actions/workflows/${workflow}/dispatches`,
        {
            method: "POST",
            headers: {
                Authorization: `Bearer ${token}`,
                Accept: "application/vnd.github+json",
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ ref: "main" }),
        }
    );

    if (!r.ok) {
        return new Response(await r.text(), { status: r.status });
    }
    return Response.json({ ok: true });
}
