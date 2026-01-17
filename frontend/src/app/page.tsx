"use client";

import { useState } from "react";

type StatusState = "idle" | "queued" | "in_progress" | "success" | "failure";

type Step = {
  name: string;
  status: string;      // queued | in_progress | completed
  conclusion: string | null; // success | failure | skipped | null
};

function getStatusState(status: string, conclusion?: string | null): StatusState {
  if (!status || status === "none") return "idle";
  if (status === "queued") return "queued";
  if (status === "in_progress") return "in_progress";
  if (status === "completed") {
    return conclusion === "success" ? "success" : "failure";
  }
  return "idle";
}

function getStepIcon(step: Step): string {
  if (step.status === "completed") {
    if (step.conclusion === "success") return "✅";
    if (step.conclusion === "failure") return "❌";
    if (step.conclusion === "skipped") return "⏭️";
    return "✅";
  }
  if (step.status === "in_progress") return "⏳";
  return "⬜";
}

export default function Home() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("none");
  const [conclusion, setConclusion] = useState<string | null>(null);
  const [runUrl, setRunUrl] = useState("");
  const [buildId, setBuildId] = useState<string | null>(null);
  const [apkUrl, setApkUrl] = useState("");
  const [apkName, setApkName] = useState("");
  const [error, setError] = useState("");
  const [steps, setSteps] = useState<Step[]>([]);

  const canBuild = username.trim() !== "" && password.trim() !== "" && !busy;

  async function fetchSteps(id: number) {
    try {
      const res = await fetch(`/api/steps?run_id=${id}`, { cache: "no-store" });
      if (res.ok) {
        const data = await res.json();
        setSteps(data.steps || []);
      }
    } catch (err) {
      console.error("Failed to fetch steps:", err);
    }
  }

  async function build() {
    if (!canBuild) return;
    
    setBusy(true);
    setStatus("queued");
    setConclusion(null);
    setRunUrl("");
    setBuildId(null);
    setApkUrl("");
    setApkName("");
    setError("");
    setSteps([]);

    try {
      const r = await fetch("/api/build", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username: username.trim(), password: password.trim() }),
      });
      if (!r.ok) {
        const text = await r.text();
        setError(text);
        setStatus("none");
        setBusy(false);
        return;
      }

      // Get the build_id from the build response
      const buildResult = await r.json();
      const myBuildId = buildResult.buildId;
      
      if (myBuildId) {
        setBuildId(myBuildId);
      }

      const t = setInterval(async () => {
        try {
          // Pass build_id to status endpoint to get our build's status
          const statusUrl = myBuildId 
            ? `/api/status?build_id=${myBuildId}` 
            : "/api/status";
          
          const s = await fetch(statusUrl, { cache: "no-store" }).then((x) =>
            x.json()
          );
          if (s.url) setRunUrl(s.url);
          if (s.runId) {
            fetchSteps(s.runId);
          }
          setStatus(s.status || "none");
          setConclusion(s.conclusion);

          if (s.status === "completed") {
            clearInterval(t);
            setBusy(false);

            if (s.conclusion === "success") {
              // Pass build_id to latest-apk endpoint to get our specific APK
              const apkUrl = myBuildId 
                ? `/api/latest-apk?build_id=${myBuildId}` 
                : "/api/latest-apk";
              
              const a = await fetch(apkUrl, { cache: "no-store" }).then(
                (x) => x.json()
              );
              if (a.ok) {
                setApkUrl(a.url);
                setApkName(a.name);
              } else {
                setError("Build success, but APK not found in release yet.");
              }
            }
          }
        } catch (err) {
          console.error("Polling error:", err);
        }
      }, 3000);
    } catch {
      setError("Failed to start build. Check your API configuration.");
      setStatus("none");
      setBusy(false);
    }
  }

  const state = getStatusState(status, conclusion);

  const statusConfig = {
    idle: {
      label: "Ready to build",
      textClass: "text-[hsl(215,20%,55%)]",
      borderClass: "",
    },
    queued: {
      label: "Queued",
      textClass: "text-[hsl(38,92%,50%)]",
      borderClass: "border-[hsl(38,92%,50%)]/50",
    },
    in_progress: {
      label: "Building...",
      textClass: "text-[hsl(173,80%,50%)]",
      borderClass: "border-[hsl(173,80%,50%)]/50 glow-primary",
    },
    success: {
      label: "Build successful",
      textClass: "text-[hsl(142,76%,45%)]",
      borderClass: "border-[hsl(142,76%,45%)]/50 glow-success",
    },
    failure: {
      label: "Build failed",
      textClass: "text-[hsl(0,72%,51%)]",
      borderClass: "border-[hsl(0,72%,51%)]/50",
    },
  };

  const currentStatus = statusConfig[state];

  return (
    <div className="min-h-screen flex flex-col">
      {/* Header */}
      <header className="border-b border-[hsl(222,30%,18%)]/50 glass">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg overflow-hidden">
                <img src="/logo.svg" alt="Logo" className="h-10 w-10 object-contain" />
              </div>
              <div>
                <h1 className="font-bold text-lg">Pulchowk WiFi Login</h1>
                <p className="text-xs text-[hsl(215,20%,55%)]">Custom APK Builder</p>
              </div>
            </div>
            
            <div className="flex items-center gap-2 text-[hsl(215,20%,55%)]">
              <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
              </svg>
            </div>
          </div>
        </div>
      </header>
      
      {/* Background grid pattern */}
      <div className="fixed inset-0 grid-pattern opacity-40 pointer-events-none" />
      
      <main className="flex-1 relative">
        <div className="container mx-auto px-6 py-6">
          {/* Hero Section */}
          <div className="text-center mb-6 animate-fade-in">
            <h2 className="text-3xl md:text-4xl font-extrabold mb-2">
              Build Your <span className="text-gradient">Login APK</span>
            </h2>
            <p className="text-sm text-[hsl(215,20%,55%)] max-w-lg mx-auto">
              Enter your Pulchowk Campus WiFi credentials to generate a personalized login app.
            </p>
          </div>

          {/* Two-column layout: Form left, Progress right on desktop */}
          <div className="flex flex-col lg:flex-row gap-6 max-w-5xl mx-auto">
            
            {/* Left Column: Form */}
            <div className="flex-1 lg:max-w-md">
              {/* Credentials Form */}
              <div className="glass rounded-xl p-5 space-y-3 animate-fade-in animate-delay-100">
                <div>
                  <label htmlFor="username" className="block text-sm font-medium mb-2 text-[hsl(210,40%,98%)]">
                    Username
                  </label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg className="h-5 w-5 text-[hsl(215,20%,55%)]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                        <circle cx="12" cy="7" r="4" />
                      </svg>
                    </div>
                    <input
                      type="text"
                      id="username"
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                      placeholder="e.g., 079bct070"
                      disabled={busy}
                      className="w-full pl-10 pr-4 py-3 rounded-lg bg-[hsl(222,30%,14%)] border border-[hsl(222,30%,18%)] text-[hsl(210,40%,98%)] placeholder-[hsl(215,20%,45%)] focus:outline-none focus:border-[hsl(173,80%,50%)] focus:ring-1 focus:ring-[hsl(173,80%,50%)] transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                    />
                  </div>
                </div>

                <div>
                  <label htmlFor="password" className="block text-sm font-medium mb-2 text-[hsl(210,40%,98%)]">
                    Password
                  </label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg className="h-5 w-5 text-[hsl(215,20%,55%)]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                      </svg>
                    </div>
                    <input
                      type="password"
                      id="password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Your WiFi password"
                      disabled={busy}
                      className="w-full pl-10 pr-4 py-3 rounded-lg bg-[hsl(222,30%,14%)] border border-[hsl(222,30%,18%)] text-[hsl(210,40%,98%)] placeholder-[hsl(215,20%,45%)] focus:outline-none focus:border-[hsl(173,80%,50%)] focus:ring-1 focus:ring-[hsl(173,80%,50%)] transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                    />
                  </div>
                </div>

                <p className="text-xs text-[hsl(215,20%,55%)] text-center pt-2">
                  Your credentials are only used for APK generation and are not stored.
                </p>

                {/* Build Button */}
                <div className="pt-2">
                  <button
                    onClick={build}
                    disabled={!canBuild}
                    className={`w-full px-6 py-3 rounded-lg font-semibold flex items-center justify-center gap-2 transition-all duration-300 ${
                      !canBuild
                        ? "bg-[hsl(222,30%,14%)] text-[hsl(215,20%,55%)] cursor-not-allowed"
                        : "bg-[hsl(173,80%,50%)] text-[hsl(222,47%,6%)] hover:bg-[hsl(173,80%,55%)] shadow-lg shadow-[hsl(173,80%,50%)]/30"
                    }`}
                  >
                    {busy ? (
                      <>
                        <svg className="h-5 w-5 animate-spin" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                          <path d="M21 12a9 9 0 11-6.219-8.56" />
                        </svg>
                        Building...
                      </>
                    ) : (
                      <>
                        <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                          <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
                        </svg>
                        Build APK
                      </>
                    )}
                  </button>
                </div>
              </div>

              {/* Error Message */}
              {error && (
                <div className="mt-4 glass rounded-xl p-4 border-[hsl(0,72%,51%)]/50 flex items-start gap-3 animate-scale-in">
                  <svg className="h-5 w-5 text-[hsl(0,72%,51%)] shrink-0 mt-0.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="8" x2="12" y2="12" />
                    <line x1="12" y1="16" x2="12.01" y2="16" />
                  </svg>
                  <p className="text-sm text-[hsl(0,72%,51%)]">{error}</p>
                </div>
              )}

              {/* Download Card */}
              {apkUrl && (
                <div className="mt-4 glass rounded-xl p-5 border-[hsl(142,76%,45%)]/30 glow-success animate-scale-in">
                  <div className="flex items-center gap-3 mb-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[hsl(142,76%,45%)]/20 text-[hsl(142,76%,45%)]">
                      <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                        <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
                      </svg>
                    </div>
                    <div>
                      <h3 className="font-semibold text-[hsl(142,76%,45%)]">APK Ready!</h3>
                      <p className="text-xs text-[hsl(215,20%,55%)] font-mono">{apkName}</p>
                    </div>
                  </div>

                  <a
                    href={apkUrl}
                    download
                    className="w-full px-4 py-2.5 rounded-lg font-semibold flex items-center justify-center gap-2 bg-[hsl(142,76%,45%)] text-white hover:bg-[hsl(142,76%,50%)] transition-colors"
                  >
                    <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                      <polyline points="7 10 12 15 17 10" />
                      <line x1="12" y1="15" x2="12" y2="3" />
                    </svg>
                    Download APK
                  </a>

                  <p className="mt-2 text-xs text-[hsl(38,92%,50%)] text-center">
                    ⚠️ Link expires in ~60 seconds
                  </p>
                </div>
              )}
            </div>

            {/* Right Column: Progress Panel */}
            <div className="flex-1 lg:max-w-md animate-fade-in animate-delay-200">
              <div className={`glass rounded-xl p-5 transition-all duration-300 ${currentStatus.borderClass}`}>
                {/* Status Header */}
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className={`flex h-8 w-8 items-center justify-center rounded-full bg-[hsl(222,30%,14%)] ${currentStatus.textClass}`}>
                      {state === "in_progress" ? (
                        <svg className="h-4 w-4 animate-spin" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                          <path d="M21 12a9 9 0 11-6.219-8.56" />
                        </svg>
                      ) : state === "success" ? (
                        <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                          <path d="M22 11.08V12a10 10 0 11-5.93-9.14" />
                          <polyline points="22 4 12 14.01 9 11.01" />
                        </svg>
                      ) : state === "failure" ? (
                        <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                          <circle cx="12" cy="12" r="10" />
                          <line x1="15" y1="9" x2="9" y2="15" />
                          <line x1="9" y1="9" x2="15" y2="15" />
                        </svg>
                      ) : (
                        <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                          <circle cx="12" cy="12" r="10" />
                        </svg>
                      )}
                    </div>
                    <div>
                      <h3 className="font-semibold text-sm">Build Progress</h3>
                      <p className={`text-xs ${currentStatus.textClass}`}>{currentStatus.label}</p>
                    </div>
                  </div>
                  
                  {runUrl && (
                    <a
                      href={runUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="text-xs text-[hsl(173,80%,50%)] hover:text-[hsl(173,80%,60%)] transition-colors"
                    >
                      View logs →
                    </a>
                  )}
                </div>

                {/* Progress Steps */}
                <div className="border-t border-[hsl(222,30%,18%)] pt-4">
                  {steps.length > 0 ? (
                    <div className="space-y-2">
                      {steps.map((step, index) => (
                        <div key={index} className="flex items-center gap-3 text-sm">
                          <span className="text-base">{getStepIcon(step)}</span>
                          <span className={
                            step.status === "completed" && step.conclusion === "success" 
                              ? "text-[hsl(215,20%,55%)]"
                              : step.status === "in_progress"
                              ? "text-[hsl(173,80%,50%)]"
                              : step.status === "completed" && step.conclusion === "failure"
                              ? "text-[hsl(0,72%,51%)]"
                              : "text-[hsl(215,20%,45%)]"
                          }>
                            {step.name}
                          </span>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="text-center py-6 text-[hsl(215,20%,45%)]">
                      <svg className="h-8 w-8 mx-auto mb-2 opacity-50" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
                        <path d="M9 17.25v1.007a3 3 0 0 1-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0 1 15 18.257V17.25m6-12V15a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 15V5.25m18 0A2.25 2.25 0 0 0 18.75 3H5.25A2.25 2.25 0 0 0 3 5.25m18 0V12a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 12V5.25" />
                      </svg>
                      <p className="text-sm">Enter credentials and click Build APK</p>
                      <p className="text-xs mt-1">Build steps will appear here</p>
                    </div>
                  )}
                </div>

                {/* 60 Second Warning */}
                {(state === "in_progress" || state === "queued") && (
                  <div className="mt-4 flex items-center gap-2 px-3 py-2 rounded-lg bg-[hsl(38,92%,50%)]/10 border border-[hsl(38,92%,50%)]/30">
                    <svg className="h-3.5 w-3.5 text-[hsl(38,92%,50%)]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                      <circle cx="12" cy="12" r="10" />
                      <polyline points="12 6 12 12 16 14" />
                    </svg>
                    <span className="text-xs text-[hsl(38,92%,50%)]">
                      Download link expires 60s after build completes
                    </span>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
