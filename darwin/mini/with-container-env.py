"""Import only the selected container environment without interpreting shell syntax."""
import os
import sys


def read_environment(raw, prefix):
    return {key: value for entry in raw.split(b"\0") if b"=" in entry
            for key, value in [entry.split(b"=", 1)] if key.startswith(prefix)}


if __name__ == "__main__":
    prefix = sys.argv[1]
    if prefix not in ("BORG_", "TELEGRAM_") or len(sys.argv) < 3:
        raise SystemExit("Usage: with-container-env.py BORG_|TELEGRAM_ command [args...]")
    with open("/proc/1/environ", "rb") as source:
        values = read_environment(source.read(), os.fsencode(prefix))
    env = dict(os.environb)
    env.update(values)
    os.execvpe(sys.argv[2], sys.argv[2:], env)
