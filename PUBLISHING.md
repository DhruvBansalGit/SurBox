# SurBox publishing status

## Vercel: live

- Public download/information page: https://surbox.vercel.app
- Apple Silicon app: https://surbox.vercel.app/downloads/SurBox-macOS-arm64.zip
- Windows x64 app: https://surbox.vercel.app/downloads/SurBox-Windows-x64.zip
- Android universal APK: https://surbox.vercel.app/downloads/SurBox-Android.apk
- Source archive: https://surbox.vercel.app/downloads/SurBox-source.zip
- SHA-256 checksums: https://surbox.vercel.app/downloads/SHA256SUMS.txt
- Project: `surbox`, existing scope `dhruv-820e`.

The owner explicitly confirmed that SurBox is personal and non-commercial, allowing use of the existing Vercel Hobby account. No subscription, billing, DNS, custom-domain, cloud API or backend changes were made. Only a new isolated static project was created. Other existing Vercel projects were not changed.

**Vercel hosts the website and downloadable files, not the native instruments.** Separate native apps run on macOS, Windows and Android. The website cannot read a MacBook lid sensor; Windows/Android do not implement physical lid input. The original unsupported-M1-Air caveat and each platform's installation/signing limitations remain prominent before downloading.

The static page uses one small local-only JavaScript file to suggest the visitor's likely platform; it never hides the other downloads, auto-downloads or claims CPU detection. All links work without JavaScript. No analytics, external fonts, forms, microphone/camera access or server functions. Runtime dependencies: none. Security headers include a restrictive Content Security Policy. GitHub login is not required for any download.

## GitHub: live

Published repository: https://github.com/DhruvBansalGit/SurBox (branch `main`).

The source, Swift package, Xcode project, licensed samples, compact test evidence and static website have been uploaded. The first source commit was `4fed6c7`; GitHub's remote ref was verified against the local commit after the push. Generated app/source ZIPs remain outside Git history and are available from the Vercel download page.

The initial unrelated Git session lacked write access. The owner subsequently authorized a temporary credential, which was verified as **DhruvBansalGit** with push permission before use. It was supplied to Git through anonymous pipes and a transient credential helper, not saved in project files, Git configuration/history, environment files, Vercel settings or remote URLs. No force push or changes to another repository were performed.

Future pushes require a valid authorized session: use an OS credential helper or GitHub CLI authentication, never a token embedded in a URL or source. Fetch and reconcile remote changes before pushing; do not overwrite them. Credentials supplied temporarily for this upload were not installed as a persistent owner login.

Automatic GitHub-to-Vercel deployment is not connected. The current site was deployed with Vercel CLI using the existing authorized session. Connecting Git integration later requires Vercel GitHub App access and a Git repository root setting compatible with the `site` folder.

The separate Windows GitHub Actions workflow builds with MSVC and exercises real Windows UI/DSP processes. It does not deploy Vercel or hold signing secrets. The downloadable Windows ZIP is the runner-produced artifact. Android's private release key is stored locally outside the repository/source archive; see [platform setup](cross-platform/README.md) for public fingerprint and secure backup guidance. See [PLATFORM_TESTING.md](PLATFORM_TESTING.md) for platform evidence and remaining hardware gates.

## Files and repeatable deployment

- [Static page](site/index.html)
- [Styles](site/styles.css)
- [Vercel configuration](site/vercel.json)
- [Safe download-staging script](scripts/stage-site.py)
- [Browser verification](scripts/verify-site.mjs)

From the SurBox folder:

```sh
sh scripts/build-app.sh
python3 scripts/stage-site.py
npx vercel link --project surbox --scope dhruv-820e --cwd site
npx vercel deploy --prod --scope dhruv-820e --cwd site
```

Do not deploy the workspace root. Upload only the prepared `site` folder. The app and source ZIPs are generated downloads, excluded from Git. The source archive includes source, build scripts, licensed audio, Xcode project, compact test evidence and this website; it excludes build caches, credentials, environment files, Vercel metadata and the raw source-page HTML snapshot.

The Vercel link command initially generated an unneeded local OIDC environment file. That newly generated file was removed without reading it. `.env*` is excluded from Git, the source archive and Vercel upload. Existing account credentials were not copied into this project.

## Platform-download update

The site now exposes all three native platform packages and a combined source archive. The expanded browser suite has 20 checks, including Windows/Android/macOS/iOS user-agent recommendations, retaining every download, JavaScript-disabled links, mobile widths and checksum listings. APK MIME/download headers are explicit. The published Windows ZIP is verified against the successful runner artifact; Android APK signatures and absence of Internet permission are checked. Current results remain in the same hosted/download evidence paths below.

The Android build and Windows runner artifact must be present before `stage-site.py` will publish their links. Build instructions and test coverage are in [cross-platform/README.md](cross-platform/README.md) and [PLATFORM_TESTING.md](PLATFORM_TESTING.md). The staging script now includes all platform source/workflow files while excluding private signing material and generated build caches.

## Original macOS-only publishing verification

- 14 local browser checks passed.
- 14 hosted browser checks passed on the public production alias, without a Vercel login.
- Reviewed desktop and mobile screenshots; no horizontal overflow at 1440, 768, 390 or 320 pixels.
- Native-vs-browser and unsupported physical-lid disclosures are present.
- Installation and controls disclosures expand correctly; keyboard skip navigation works.
- Every local navigation/document/download link returned HTTP 200.
- Both public ZIP downloads were retrieved, their SHA-256 checksums verified, and ZIP integrity checked.
- Downloaded source includes physical-lid modules and excludes credential/environment/raw-session files.
- No browser console, JavaScript or CSP errors after adding the missing favicon identified in the first local test.

[Hosted browser results](artifacts/publishing/hosted/results.txt) and [download verification](artifacts/publishing/download-check/results.txt) are local evidence, not committed dependencies. App behavior and hardware limitations are documented separately in [TESTING.md](TESTING.md) and [LID_TRACKING.md](LID_TRACKING.md). Publishing did not change the instrument implementation.
