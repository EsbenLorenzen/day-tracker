"""Git clean filter: removes outputs from Jupyter notebooks before they're committed.

Notebook outputs contain personal data from your exports, and the repo is public (D02).
Your working copy keeps its outputs; only the committed version is stripped.

Setup (once per clone, run in the repo root):
    git config filter.nbstrip.clean ".venv/Scripts/python.exe tools/strip_notebook_output.py"
    git config filter.nbstrip.smudge cat
    git config filter.nbstrip.required true

With --check FILE...: exit 1 if any notebook has outputs (used by CI).
"""
import json
import sys


def strip(notebook: dict) -> dict:
    for cell in notebook.get("cells", []):
        if cell.get("cell_type") == "code":
            cell["outputs"] = []
            cell["execution_count"] = None
        cell.get("metadata", {}).pop("execution", None)
    return notebook


def has_outputs(notebook: dict) -> bool:
    return any(
        cell.get("outputs") or cell.get("execution_count") is not None
        for cell in notebook.get("cells", [])
        if cell.get("cell_type") == "code"
    )


def main() -> int:
    if sys.argv[1:2] == ["--check"]:
        dirty = [path for path in sys.argv[2:] if has_outputs(json.load(open(path, encoding="utf-8")))]
        for path in dirty:
            print(f"{path} contains outputs (personal data). Strip them before committing.")
        return 1 if dirty else 0

    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    notebook = strip(json.load(sys.stdin))
    sys.stdout.write(json.dumps(notebook, indent=1, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
