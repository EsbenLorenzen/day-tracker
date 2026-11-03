"""Load and summarise DayTracker exports (D09, D17).

    import daytracker as dt
    ex = dt.load()          # newest export in analysis/data/
    dt.daily(ex)            # one row per day, one column per tracker

Exports come from the app: Settings → Data → Export all data. Put the .zip
(or its unzipped folder) in analysis/data/, which git ignores.
"""
from __future__ import annotations

import io
import zipfile
from dataclasses import dataclass
from pathlib import Path

import pandas as pd

DATA_DIR = Path(__file__).resolve().parent / "data"
CSV_FILES = ("entries.csv", "trackers.csv", "checkins.csv")
SUMMED_KINDS = {"counter", "number"}


@dataclass
class Export:
    entries: pd.DataFrame
    trackers: pd.DataFrame
    checkins: pd.DataFrame
    source: Path


def latest_export(data_dir: Path = DATA_DIR) -> Path:
    """The most recently modified export (.zip or unzipped folder) in `data_dir`."""
    candidates = [
        p for p in Path(data_dir).glob("*")
        if p.suffix.lower() == ".zip" or (p.is_dir() and (p / "entries.csv").exists())
    ]
    if not candidates:
        raise FileNotFoundError(
            f"No DayTracker export in {data_dir}. In the app: Settings → Data → Export all data, "
            "then put the .zip in that folder."
        )
    return max(candidates, key=lambda p: p.stat().st_mtime)


def load(path: str | Path | None = None) -> Export:
    """Load an export .zip or folder; defaults to the newest one in analysis/data/."""
    path = Path(path) if path is not None else latest_export()
    texts = _read_files(path)
    if texts.get("entries.csv") is None:
        raise ValueError(f"{path} has no entries.csv – is it a DayTracker export?")

    trackers = _trackers(_csv(texts.get("trackers.csv")))
    entries = _entries(_csv(texts["entries.csv"]), trackers)
    checkins = _checkins(_csv(texts.get("checkins.csv")))
    return Export(entries=entries, trackers=trackers, checkins=checkins, source=path)


def daily(ex: Export) -> pd.DataFrame:
    """One row per day (04:00 boundary), one column per tracker.

    Counters are summed (missing days = 0), medicines count doses taken (missing = 0),
    ratings are the day's average (missing = NaN).
    """
    e = ex.entries
    if e.empty:
        return pd.DataFrame()
    columns, zero_filled = [], []
    for (name, kind), g in e.groupby(["tracker", "kind"], sort=False):
        if kind in SUMMED_KINDS:
            series = g.groupby("day")["value"].sum()
            zero_filled.append(name)
        elif kind == "dose":
            series = g[g["value"] >= 1].groupby("day").size().astype(float)
            zero_filled.append(name)
        elif kind == "scale":
            series = g.groupby("day")["value"].mean()
        else:
            series = g.groupby("day").size().astype(float)
        columns.append(series.rename(name))

    out = pd.concat(columns, axis=1)
    out = out.reindex(pd.date_range(out.index.min(), out.index.max(), freq="D"))
    out[zero_filled] = out[zero_filled].fillna(0)
    out.index.name = "day"
    return out[_tracker_order(ex, out.columns)]


def by_hour(ex: Export, trackers: list[str] | None = None) -> pd.DataFrame:
    """Average rating per hour of the day (local time), one column per rating tracker."""
    e = ex.entries[ex.entries["kind"] == "scale"]
    if trackers is not None:
        e = e[e["tracker"].isin(trackers)]
    if e.empty:
        return pd.DataFrame()
    table = e.assign(hour_of_day=e["occurred_local"].dt.hour).pivot_table(
        index="hour_of_day", columns="tracker", values="value", aggfunc="mean")
    return table[_tracker_order(ex, table.columns)]


def by_weekday(ex: Export) -> pd.DataFrame:
    """Daily values averaged per weekday (Monday first)."""
    d = daily(ex)
    if d.empty:
        return d
    order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    return d.groupby(d.index.day_name()).mean().reindex(order).dropna(how="all")


def last_coffee_vs_evening(
    ex: Export, coffee: str = "Coffee", rating: str = "Energy", evening_from: float = 18
) -> pd.DataFrame:
    """Per day: number of coffees, time of the last one, and the evening's average rating.

    Times are hours since the start of the calendar day, so 01:30 after midnight is 25.5.
    """
    e = ex.entries
    hours = (e["occurred_local"] - e["day"]).dt.total_seconds() / 3600
    c = e[e["tracker"] == coffee].assign(hours=hours)
    r = e[(e["tracker"] == rating) & (hours >= evening_from)]
    out = pd.DataFrame({
        "coffees": c.groupby("day")["value"].sum(),
        "last_coffee_hour": c.groupby("day")["hours"].max(),
        f"evening_{rating.lower()}": r.groupby("day")["value"].mean(),
    })
    out = out.reindex(sorted(e["day"].unique()))  # every day in the export, even without coffee
    out["coffees"] = out["coffees"].fillna(0)
    out.index.name = "day"
    return out


def adherence(ex: Export) -> pd.DataFrame:
    """Per medicine: reminder slots taken/skipped/unanswered, plus as-needed doses.

    Expected slots assume today's reminder times applied to every day in the export.
    """
    e = ex.entries
    doses = e[e["kind"] == "dose"]
    if doses.empty:
        return pd.DataFrame()
    days = e["day"].nunique()
    reminders = dict(zip(ex.trackers["tracker_id"], ex.trackers["reminder_times"]))
    rows = []
    for (tracker_id, name), g in doses.groupby(["tracker_id", "tracker"], sort=False):
        scheduled = g[g["scheduled_for"] != ""]
        taken = int((scheduled["value"] >= 1).sum())
        skipped = int((scheduled["value"] < 1).sum())
        expected = len(reminders.get(tracker_id, [])) * days
        rows.append({
            "medicine": name,
            "expected_slots": expected,
            "taken": taken,
            "skipped": skipped,
            "unanswered": max(expected - taken - skipped, 0),
            "as_needed": int(((g["scheduled_for"] == "") & (g["value"] >= 1)).sum()),
            "taken_rate": taken / expected if expected else float("nan"),
        })
    return pd.DataFrame(rows).set_index("medicine")


def checkin_summary(ex: Export) -> pd.DataFrame:
    """Per check-in: count of each status and the share answered at least partly."""
    c = ex.checkins
    if c.empty:
        return pd.DataFrame()
    table = pd.crosstab(c["schedule_name"], c["status"])
    for status in ("answered", "partial", "skipped", "missed", "pending"):
        if status not in table:
            table[status] = 0
    table = table[["answered", "partial", "skipped", "missed", "pending"]]
    table["response_rate"] = (table["answered"] + table["partial"]) / table.sum(axis=1)
    return table


def plot_by_hour(ex: Export, trackers: list[str] | None = None):
    """Line chart of `by_hour`."""
    import matplotlib.pyplot as plt

    table = by_hour(ex, trackers)
    ax = table.plot(marker="o", figsize=(9, 4))
    ax.set(xlabel="Hour of day", ylabel="Average rating", title="Ratings by time of day", ylim=(1, 10))
    ax.grid(alpha=0.3)
    plt.tight_layout()
    return ax


# --- parsing -----------------------------------------------------------------------------------

def _read_files(path: Path) -> dict[str, str | None]:
    names = (*CSV_FILES, "backup.json")
    if path.is_dir():
        return {n: (path / n).read_text(encoding="utf-8") if (path / n).exists() else None for n in names}
    with zipfile.ZipFile(path) as zf:
        members = {Path(m).name: m for m in zf.namelist() if not m.endswith("/")}
        return {n: zf.read(members[n]).decode("utf-8") if n in members else None for n in names}


def _csv(text: str | None) -> pd.DataFrame:
    if not text:
        return pd.DataFrame()
    return pd.read_csv(io.StringIO(text), dtype=str, keep_default_na=False)


def _local(series: pd.Series) -> pd.Series:
    """Wall-clock time from an ISO timestamp with offset ("2026-11-02T09:00:00+01:00" → 09:00)."""
    return pd.to_datetime(series.str.slice(0, 19), errors="coerce")


def _trackers(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return pd.DataFrame(columns=["tracker_id", "name", "kind", "sort_order", "archived", "reminder_times"])
    df = df.copy()
    df["sort_order"] = pd.to_numeric(df["sort_order"])
    df["archived"] = df["archived"] == "true"
    df["reminder_times"] = df["reminder_times"].map(lambda s: [t for t in s.split(";") if t])
    return df.sort_values("sort_order").reset_index(drop=True)


def _entries(df: pd.DataFrame, trackers: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["value"] = pd.to_numeric(df["value"]).astype(float)
    df["occurred_local"] = _local(df["occurred_at"])
    df["occurred_utc"] = pd.to_datetime(df["occurred_at"], utc=True, format="ISO8601")
    df["scheduled_local"] = _local(df["scheduled_for"])
    df["day"] = pd.to_datetime(df["day"])
    df["hour"] = df["occurred_local"].dt.hour + df["occurred_local"].dt.minute / 60
    # Current names, so renamed trackers aren't split in two.
    names = dict(zip(trackers.get("tracker_id", []), trackers.get("name", [])))
    df["tracker"] = df["tracker_id"].map(names).fillna(df["tracker_name"])
    return df


def _checkins(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return pd.DataFrame(columns=["schedule_name", "status", "day"])
    df = df.copy()
    df["scheduled_local"] = _local(df["scheduled_for"])
    df["day"] = pd.to_datetime(df["day"])
    for column in ("question_count", "answered_count"):
        df[column] = pd.to_numeric(df[column])
    return df


def _tracker_order(ex: Export, columns) -> list[str]:
    order = [n for n in ex.trackers.get("name", []) if n in set(columns)]
    return order + [c for c in columns if c not in order]
