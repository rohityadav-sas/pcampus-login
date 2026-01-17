"use client";

import { useState } from "react";

type StatusState = "idle" | "queued" | "in_progress" | "success" | "failure";

function getStatusState(status: string, conclusion?: string | null): StatusState {
  if (!status || status === "none") return "idle";
  if (status === "queued") return "queued";
  if (status === "in_progress") return "in_progress";
  if (status === "completed") {
    return conclusion === "success" ? "success" : "failure";
  }
  return "idle";
}

export default function Home() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("none");
  const [conclusion, setConclusion] = useState<string | null>(null);
  const [runUrl, setRunUrl] = useState("");
  const [apkUrl, setApkUrl] = useState("");
  const [apkName, setApkName] = useState("");
  const [error, setError] = useState("");

  const canBuild = username.trim() !== "" && password.trim() !== "" && !busy;

  async function build() {
    if (!canBuild) return;
    
    setBusy(true);
    setStatus("queued");
    setConclusion(null);
    setRunUrl("");
    setApkUrl("");
    setApkName("");
    setError("");

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

      const t = setInterval(async () => {
        try {
          const s = await fetch("/api/status", { cache: "no-store" }).then((x) =>
            x.json()
          );
          if (s.url) setRunUrl(s.url);
          setStatus(s.status || "none");
          setConclusion(s.conclusion);

          if (s.status === "completed") {
            clearInterval(t);
            setBusy(false);

            if (s.conclusion === "success") {
              const a = await fetch("/api/latest-apk", { cache: "no-store" }).then(
                (x) => x.json()
              );
              if (a.ok) {
                setApkUrl(a.url);
                setApkName(a.name);
              } else {
                setError("Build success, but APK not found in latest release yet.");
              }
            }
          }
        } catch (err) {
          console.error("Polling error:", err);
        }
      }, 4000);
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
      icon: (
        <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="10" />
        </svg>
      ),
    },
    queued: {
      label: "Queued",
      textClass: "text-[hsl(38,92%,50%)]",
      borderClass: "border-[hsl(38,92%,50%)]/50",
      icon: (
        <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="10" />
          <polyline points="12 6 12 12 16 14" />
        </svg>
      ),
    },
    in_progress: {
      label: "Building...",
      textClass: "text-[hsl(173,80%,50%)]",
      borderClass: "border-[hsl(173,80%,50%)]/50 glow-primary",
      icon: (
        <svg className="h-5 w-5 animate-spin" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <path d="M21 12a9 9 0 11-6.219-8.56" />
        </svg>
      ),
    },
    success: {
      label: "Build successful",
      textClass: "text-[hsl(142,76%,45%)]",
      borderClass: "border-[hsl(142,76%,45%)]/50 glow-success",
      icon: (
        <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <path d="M22 11.08V12a10 10 0 11-5.93-9.14" />
          <polyline points="22 4 12 14.01 9 11.01" />
        </svg>
      ),
    },
    failure: {
      label: "Build failed",
      textClass: "text-[hsl(0,72%,51%)]",
      borderClass: "border-[hsl(0,72%,51%)]/50",
      icon: (
        <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="10" />
          <line x1="15" y1="9" x2="9" y2="15" />
          <line x1="9" y1="9" x2="15" y2="15" />
        </svg>
      ),
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
          <div className="text-center mb-4 animate-fade-in">
            <h2 className="text-4xl md:text-5xl font-extrabold mb-4">
              Build Your <span className="text-gradient">Login APK</span>
            </h2>
          </div>

          {/* Credentials Form */}
          <div className="max-w-md mx-auto mb-6 animate-fade-in animate-delay-100">
            <div className="glass rounded-xl p-5 space-y-3">
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
            </div>
          </div>

          {/* Build Button */}
          <div className="flex justify-center mb-6 animate-fade-in animate-delay-200">
            <div className="relative">
              {/* Pulsing ring effect when ready */}
              {canBuild && (
                <div className="absolute inset-0 rounded-xl bg-[hsl(173,80%,50%)]/20 animate-pulse-ring" />
              )}
              
              <button
                onClick={build}
                disabled={!canBuild}
                className={`relative z-10 min-w-[200px] px-8 py-4 rounded-xl font-semibold text-lg flex items-center justify-center gap-3 transition-all duration-300 ${
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

          {/* 60 Second Warning */}
          <div className="flex justify-center mb-4 animate-fade-in animate-delay-200">
            <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-[hsl(38,92%,50%)]/10 border border-[hsl(38,92%,50%)]/30">
              <svg className="h-3.5 w-3.5 text-[hsl(38,92%,50%)]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </svg>
              <span className="text-xs text-[hsl(38,92%,50%)]">
                Download link expires in 60 seconds after build
              </span>
            </div>
          </div>

          {/* Status and Download Grid */}
          <div className="max-w-2xl mx-auto space-y-4">
            {/* Error Message */}
            {error && (
              <div className="glass rounded-xl p-4 border-[hsl(0,72%,51%)]/50 flex items-start gap-3 animate-scale-in">
                <svg className="h-5 w-5 text-[hsl(0,72%,51%)] shrink-0 mt-0.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="12" y2="12" />
                  <line x1="12" y1="16" x2="12.01" y2="16" />
                </svg>
                <p className="text-sm text-[hsl(0,72%,51%)]">{error}</p>
              </div>
            )}

            {/* Status Card */}
            <div className="animate-fade-in animate-delay-300">
              <div className={`glass rounded-xl p-4 transition-all duration-300 ${currentStatus.borderClass}`}>
                <div className="flex items-center gap-3">
                  <div className={`flex h-10 w-10 items-center justify-center rounded-full bg-[hsl(222,30%,14%)] ${currentStatus.textClass}`}>
                    {currentStatus.icon}
                  </div>
                  
                  <div className="flex-1">
                    <h3 className="font-semibold">Build Status</h3>
                    <p className={`text-sm ${currentStatus.textClass}`}>{currentStatus.label}</p>
                  </div>
                </div>

                {runUrl && (
                  <a
                    href={runUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="mt-4 inline-flex items-center gap-2 text-sm text-[hsl(173,80%,50%)] hover:text-[hsl(173,80%,60%)] transition-colors font-mono"
                  >
                    View build logs →
                  </a>
                )}
              </div>
            </div>

            {/* Download Card */}
            {apkUrl && (
              <div className="glass rounded-xl p-6 border-[hsl(142,76%,45%)]/30 glow-success animate-scale-in">
                <div className="flex items-start gap-4">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-[hsl(142,76%,45%)]/20 text-[hsl(142,76%,45%)]">
                    <svg className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                      <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
                    </svg>
                  </div>
                  
                  <div className="flex-1">
                    <h3 className="text-lg font-semibold">APK Ready</h3>
                    <p className="text-sm text-[hsl(215,20%,55%)] font-mono mt-1 break-all">
                      {apkName}
                    </p>
                  </div>
                </div>

                {/* Urgent download warning */}
                <div className="mt-4 flex items-center gap-2 px-3 py-2 rounded-lg bg-[hsl(38,92%,50%)]/10 border border-[hsl(38,92%,50%)]/30">
                  <svg className="h-4 w-4 text-[hsl(38,92%,50%)] shrink-0" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                    <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                    <line x1="12" y1="9" x2="12" y2="13" />
                    <line x1="12" y1="17" x2="12.01" y2="17" />
                  </svg>
                  <span className="text-xs text-[hsl(38,92%,50%)]">
                    Download immediately! This link will expire in 60 seconds.
                  </span>
                </div>

                <a
                  href={apkUrl}
                  download
                  className="w-full mt-4 px-6 py-3 rounded-lg font-semibold flex items-center justify-center gap-2 bg-[hsl(142,76%,45%)] text-white hover:bg-[hsl(142,76%,50%)] transition-colors"
                >
                  <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                    <polyline points="7 10 12 15 17 10" />
                    <line x1="12" y1="15" x2="12" y2="3" />
                  </svg>
                  Download APK Now
                </a>

                <div className="mt-4 flex items-center gap-2 text-xs text-[hsl(215,20%,55%)]">
                  <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                    <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
                    <line x1="12" y1="18" x2="12.01" y2="18" />
                  </svg>
                  <span>Transfer to your Android device to install</span>
                </div>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
