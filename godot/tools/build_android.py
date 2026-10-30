#!/usr/bin/env python3
"""Export the standalone Godot Android preview; no C++ extension is required."""
import sys
from export_native import main

if __name__ == "__main__":
    main(["android"] + sys.argv[1:])
