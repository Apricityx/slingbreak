"""Run Godot build commands while rejecting script errors on successful exits."""
import re
import subprocess

ERROR = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:.*(?:leaked|resources still))")


def run_engine(command):
    errors = []
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, errors="replace") as process:
        for line in process.stdout:
            print(line, end="", flush=True)
            if ERROR.match(line):
                errors.append(line.strip())
        result = process.wait()
    if result:
        raise subprocess.CalledProcessError(result, command)
    if errors:
        raise RuntimeError("Godot emitted errors despite exit code 0: " + "; ".join(errors[:8]))
