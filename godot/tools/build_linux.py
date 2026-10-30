#!/usr/bin/env python3
"""Export the standalone Godot Linux preview (x86_64 ELF with embedded PCK)."""
import sys
from export_native import main

if __name__ == "__main__":
    main(["linux"] + sys.argv[1:])
