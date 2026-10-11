#!/usr/bin/env python3
"""Check the standalone arm64 Android preview's exported resource contract."""
import argparse
from pathlib import Path
import zipfile
from resource_contract import check_resources


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    args = parser.parse_args()
    with zipfile.ZipFile(args.apk) as apk:
        names = set(apk.namelist())
        if "lib/arm64-v8a/libgodot_android.so" not in names:
            raise SystemExit("Missing native Godot library")
        if any("libsling_runtime" in name or name.startswith(("lib/armeabi", "lib/x86")) for name in names):
            raise SystemExit("Unexpected native extension or architecture")
        resources = {name.removeprefix("assets/") for name in names if name.startswith("assets/")}
        check_resources(resources, lambda name: apk.read("assets/" + name))
    print("Standalone arm64 APK resource gate passed")


if __name__ == "__main__":
    main()
