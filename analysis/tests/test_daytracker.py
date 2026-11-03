"""Tests against the export-format fixtures that the Swift exporter is also tested against (D17)."""
import sys
import zipfile
from pathlib import Path

import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "analysis"))

import daytracker as dt  # noqa: E402

FIXTURES = ROOT / "Packages/DayTrackerCore/Tests/DayTrackerCoreTests/Fixtures"
NOV2, NOV3 = pd.Timestamp("2026-11-02"), pd.Timestamp("2026-11-03")


@pytest.fixture
def export(tmp_path):
    archive = tmp_path / "DayTracker-test.zip"
    with zipfile.ZipFile(archive, "w") as zf:
        for name in dt.CSV_FILES:
            zf.write(FIXTURES / name, name)
    return dt.load(archive)


def test_load_folder_and_zip_agree(export):
    folder = dt.load(FIXTURES)
    pd.testing.assert_frame_equal(folder.entries, export.entries)


def test_entries_parsed(export):
    e = export.entries
    assert len(e) == 8
    assert e["value"].dtype.kind == "f"
    first = e.iloc[0]
    assert first["occurred_local"] == pd.Timestamp("2026-11-02 08:05")
    assert first["occurred_utc"] == pd.Timestamp("2026-11-02 07:05", tz="UTC")
    assert e.loc[e["entry_id"].str.endswith("107"), "note"].item() == "Slept well, finally"


def test_daily(export):
    d = dt.daily(export)
    assert list(d.columns) == ["Water", "Coffee", "Vitamin D", "Energy"]
    assert d.loc[NOV2].to_dict() == {"Water": 2, "Coffee": 2, "Vitamin D": 1, "Energy": 6}
    # 01:30 coffee counts for Nov 2 (04:00 day boundary); counters/doses fill 0, ratings stay as-is
    assert d.loc[NOV3].to_dict() == {"Water": 0, "Coffee": 0, "Vitamin D": 0, "Energy": 7}


def test_last_coffee_vs_evening(export):
    c = dt.last_coffee_vs_evening(export)
    assert c.loc[NOV2, "coffees"] == 2
    assert c.loc[NOV2, "last_coffee_hour"] == 25.5
    assert c.loc[NOV2, "evening_energy"] == 6
    assert pd.isna(c.loc[NOV3, "evening_energy"])  # 09:00 rating isn't "evening"


def test_adherence(export):
    a = dt.adherence(export).loc["Vitamin D"]
    assert (a["expected_slots"], a["taken"], a["skipped"], a["unanswered"], a["as_needed"]) == (2, 1, 1, 0, 0)
    assert a["taken_rate"] == 0.5


def test_checkin_summary(export):
    s = dt.checkin_summary(export)
    assert s.loc["Evening", "answered"] == 1
    assert s.loc["Morning", "missed"] == 1
    assert s.loc["Evening", "response_rate"] == 1.0
    assert s.loc["Morning", "response_rate"] == 0.0


def test_by_hour(export):
    h = dt.by_hour(export)
    assert h.loc[21, "Energy"] == 6
    assert h.loc[9, "Energy"] == 7


def test_renamed_tracker_uses_current_name(export):
    export.trackers.loc[export.trackers["name"] == "Vitamin D", "name"] = "D3"
    reloaded = dt._entries(dt._csv((FIXTURES / "entries.csv").read_text()), export.trackers)
    assert set(reloaded.loc[reloaded["kind"] == "dose", "tracker"]) == {"D3"}


def test_missing_export_folder(tmp_path):
    with pytest.raises(FileNotFoundError):
        dt.latest_export(tmp_path)
