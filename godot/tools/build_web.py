#!/usr/bin/env python3
"""Export the standalone Godot Web preview using the Chromium 89 template."""
import sys
from export_native import main

if __name__ == "__main__":
    main(["web"] + sys.argv[1:])
