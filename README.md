# DayTracker

A personal native iOS app (Swift/SwiftUI) for tracking daily things (medication, water, coffee, mood and energy) with scheduled check-in notifications. All data is exported for analysis in Python.

**Status:** planning. Nothing is built yet. Start with [Phase 0 in the roadmap](docs/ROADMAP.md).

## Constraints
- Developed on **Windows with no Mac**. Builds run on GitHub Actions macOS runners ([D02](docs/DECISIONS.md#d02--build-on-cloud-macos-github-actions)).
- Installed on the iPhone by **sideloading** with a free Apple ID for now; TestFlight later ([D04](docs/DECISIONS.md#d04--distribution-free-apple-id-sideloading-now-paid-program-later)).
- Data stays **on the device**; no backend ([D06](docs/DECISIONS.md#d06--local-only-storage-with-swiftdata-no-backend)).

## Docs
- [Roadmap](docs/ROADMAP.md): phases, open questions, risks
- [Decisions](docs/DECISIONS.md): what was chosen and why
- [Architecture](docs/ARCHITECTURE.md): layout, data model, notifications, export format

## Dev loop
1. Edit Swift code on Windows (VS Code + Swift extension for syntax highlighting).
2. Push → GitHub Actions ([ios.yml](.github/workflows/ios.yml)) builds and uploads `DayTracker-unsigned.ipa`.
3. Download the artifact → Sideloadly → iPhone. Step by step: [docs/SIDELOADING.md](docs/SIDELOADING.md).

## Analysis setup
```powershell
.\.venv\Scripts\Activate.ps1
pip install -r analysis\requirements.txt
jupyter lab
```
Put exported files in `analysis/data/` (gitignored, so personal data never gets committed).
