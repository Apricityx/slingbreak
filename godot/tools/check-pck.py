#!/usr/bin/env python3
"""Validate an unencrypted standalone Godot 4.7 PCK without extracting it."""
import argparse
from pathlib import Path
import struct
from resource_contract import check_resources


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pck", type=Path)
    args = parser.parse_args()
    with args.pck.open("rb") as pack:
        header = pack.read(40)
        magic, version, major, minor, patch, flags, base, directory = struct.unpack("<4s5I2Q", header)
        if magic != b"GDPC" or version != 4 or flags != 2 or (major, minor, patch) != (4, 7, 2):
            raise SystemExit("Unsupported PCK header (expected an unencrypted Godot 4.7.2 pack)")
        pack.seek(directory)
        count = struct.unpack("<I", pack.read(4))[0]
        entries = {}
        for _ in range(count):
            length = struct.unpack("<I", pack.read(4))[0]
            name = pack.read(length).rstrip(b"\0").decode("utf8")
            offset, size, digest, file_flags = struct.unpack("<QQ16sI", pack.read(36))
            if file_flags or name in entries or base + offset + size > directory:
                raise SystemExit("Invalid PCK entry: " + name)
            entries[name.removeprefix("res://")] = (base + offset, size)

        def read(name):
            offset, size = entries[name]
            pack.seek(offset)
            return pack.read(size)

        check_resources(set(entries), read)
    print("Standalone Web PCK resource gate passed")


if __name__ == "__main__":
    main()
