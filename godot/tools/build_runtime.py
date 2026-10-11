#!/usr/bin/env python3
"""Validate standalone content. Gameplay is native GDScript and needs no build."""
from export_native import ROOT, verify_assets
from resource_contract import check_resources

if __name__ == "__main__":
    verify_assets()
    names = {path.relative_to(ROOT).as_posix() for path in (ROOT / "assets").rglob("*") if path.is_file()}
    check_resources(names, lambda name: (ROOT / name).read_bytes())
