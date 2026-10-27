# SurBox publishing status

## Vercel: live

- Public download/information page: https://surbox.vercel.app
- Apple Silicon app: https://surbox.vercel.app/downloads/SurBox-macOS-arm64.zip
- Source archive: https://surbox.vercel.app/downloads/SurBox-source.zip
- SHA-256 checksums: https://surbox.vercel.app/downloads/SHA256SUMS.txt
- Project: `surbox`, existing scope `dhruv-820e`.

The owner explicitly confirmed that SurBox is personal and non-commercial, allowing use of the existing Vercel Hobby account. No subscription, billing, DNS, custom-domain, cloud API or backend changes were made. Only a new isolated static project was created. Other existing Vercel projects were not changed.

**Vercel hosts the website and downloadable files, not the native instrument.** The Swift/SceneKit/AVAudioEngine app runs locally on macOS. The website cannot read a MacBook lid sensor. The original unsupported-M1-Air caveat remains prominent, and the app's local/ad-hoc signing and lack of notarization are disclosed before downloading.

The static page has no JavaScript, analytics, external fonts, forms, microphone/camera access or server functions. Runtime dependencies: none. Security headers include a restrictive Content Security Policy. GitHub is not required to download either ZIP.

## GitHub: prepared locally, upload blocked by permissions

Requested repository: https://github.com/DhruvBansalGit/SurBox

The repository was public and empty when inspected. The available GitHub credential authenticates as **Alexwatson-de** and has **no push permission** on this repository. No pending invitation for that repository was available. No GitHub release or successful source push is claimed.

To unblock the upload, the repository owner can invite **Alexwatson-de** under Settings > Collaborators, or authenticate locally with the owner account. Do not paste a token in chat or put it in a file, remote URL, Vercel variable, command argument or Git history. The staged source is isolated in the SurBox folder, and the remote is the exact owner-supplied repository. No force-push or changes to another repository are needed.

After access is granted, accept any target-repository invitation and run a normal authenticated `git push -u origin main` from the SurBox folder. On this host the approved credential is held by the macOS keychain; use a credential helper rather than embedding it in the URL. If the remote gains commits meanwhile, fetch and reconcile them first; do not overwrite them.

Automatic GitHub-to-Vercel deployment is not connected. The current site was deployed with Vercel CLI using the existing authorized session. Connecting Git integration later requires Vercel GitHub App access and a Git repository root setting compatible with the `site` folder.

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

## Verification

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
