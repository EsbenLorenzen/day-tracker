# CLAUDE.md

- The developer has **no Mac**: there's no Xcode, simulator or `xcodebuild` locally. iOS builds only happen on GitHub Actions macOS runners. Don't suggest local Xcode steps.
- Never hand-edit or commit `.xcodeproj`. Change `project.yml` (XcodeGen) instead.
- Python (`.venv`, `analysis/`) is for analysing exported data only, not part of the app.
- Never commit exported personal data (`analysis/data/`, `*.csv`) or notebook outputs. The repo is public. Stage specific paths and check `git diff --cached --stat` before committing; never blind `git add -A` after the user has run the notebook. The `nbstrip` git filter (`tools/strip_notebook_output.py`) strips outputs and needs one-time `git config` per clone (see that file).
- Record significant choices in `docs/DECISIONS.md`; track progress in `docs/ROADMAP.md` checkboxes.
