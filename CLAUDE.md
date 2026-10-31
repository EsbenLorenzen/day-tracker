# CLAUDE.md

- The developer has **no Mac**: there's no Xcode, simulator or `xcodebuild` locally. iOS builds only happen on GitHub Actions macOS runners. Don't suggest local Xcode steps.
- Never hand-edit or commit `.xcodeproj`. Change `project.yml` (XcodeGen) instead.
- Python (`.venv`, `analysis/`) is for analysing exported data only, not part of the app.
- Never commit exported personal data (`analysis/data/`, `*.csv`).
- Record significant choices in `docs/DECISIONS.md`; track progress in `docs/ROADMAP.md` checkboxes.
