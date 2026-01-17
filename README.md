# 📶 PCampus Login

> **One-tap WiFi login for Pulchowk Campus** — No more typing credentials every time!

[![Live Demo](https://img.shields.io/badge/demo-live-brightgreen?style=for-the-badge)](https://pcampus-login.vercel.app)
[![GitHub Actions](https://img.shields.io/badge/build-GitHub%20Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)](https://github.com/rohityadav-sas/pcampus-login/actions)
[![Next.js](https://img.shields.io/badge/frontend-Next.js-000000?style=for-the-badge&logo=next.js)](https://nextjs.org)
[![Android](https://img.shields.io/badge/platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)

---

## 🎯 The Problem

Every time you connect to **Pulchowk Campus WiFi**, you have to:

1. 🌐 Open the captive portal (`10.100.1.1:8090`)
2. ⌨️ Type your username
3. 🔑 Type your password
4. 🖱️ Click login

**Repeat this multiple times a day. Every. Single. Day.**

---

## ✨ The Solution

This project generates a **personalized Android APK** with your credentials baked in. Just:

1. 📱 **Tap the app icon**
2. ✅ **Done.** You're logged in.

No browser. No typing. No waiting.

---

## 🚀 How It Works

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│   You enter     │ ───► │  GitHub Actions  │ ───► │  Download your  │
│   credentials   │      │  builds your APK │      │  custom APK     │
└─────────────────┘      └──────────────────┘      └─────────────────┘
```

1. Visit the [web app](https://pcampus-login.vercel.app)
2. Enter your Pulchowk WiFi credentials
3. Click **Build APK**
4. Wait ~60 seconds while GitHub Actions builds your personalized APK
5. Download and install
6. Tap anytime to login instantly!

> ⚠️ **Privacy**: Your credentials are injected at build time and only exist in YOUR APK. They are not stored anywhere.

---

## 🛠️ Tech Stack

| Component        | Technology                           |
| ---------------- | ------------------------------------ |
| **Frontend**     | Next.js 14, TypeScript, Tailwind CSS |
| **Build System** | GitHub Actions                       |
| **Android App**  | Native Java                          |
| **Hosting**      | Vercel                               |

---

## 📁 Project Structure

```
├── .github/workflows/
│   ├── build-apk.yml      # Builds personalized APK
│   └── cleanup-release.yml # Auto-deletes releases after 60s
├── app/                    # Android source code
│   └── src/main/java/wifi/login/
│       └── MainActivity.java
├── frontend/               # Next.js web app
│   └── src/app/
│       ├── api/            # API routes for GitHub Actions
│       └── page.tsx        # Main UI
└── README.md
```

---

## 🏃 Running Locally

### Prerequisites

- Node.js 18+
- GitHub Personal Access Token with `repo` and `workflow` permissions

### Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/rohityadav-sas/pcampus-login.git
   cd pcampus-login
   ```

2. **Install frontend dependencies**

   ```bash
   cd frontend
   npm install
   ```

3. **Create `.env.local`**

   ```env
   GITHUB_TOKEN=ghp_your_token_here
   GITHUB_OWNER=rohityadav-sas
   GITHUB_REPO=pcampus-login
   WORKFLOW_FILE=build-apk.yml
   ```

4. **Run the development server**

   ```bash
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000)

---

## 🔐 Security Notes

- **Credentials are build-time injected** — not stored in any database
- **Each APK is unique** — contains only YOUR credentials
- **Releases auto-delete** — download links expire in 60 seconds
- **SSL verification bypassed** — required for the campus portal's self-signed certificate

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

- 🐛 Report bugs
- 💡 Suggest features
- 🔧 Submit pull requests

---

## 📄 License

MIT License — feel free to use this for your own campus!

---

<p align="center">
  <b>Built with ❤️ for Pulchowk Campus students</b>
</p>
