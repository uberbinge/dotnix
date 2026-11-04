"""Fail closed unless both mounted volumes match explicitly enrolled UUIDs."""
import plistlib
import subprocess
import sys


def validate(source, destination, source_uuid, destination_uuid, inspect):
    if not source_uuid or not destination_uuid:
        raise ValueError("Enroll both services.mediaServer.localBackup volume UUIDs before mirroring")
    if source_uuid.casefold() == destination_uuid.casefold():
        raise ValueError("Source and destination UUIDs must differ")
    for path, expected in ((source, source_uuid), (destination, destination_uuid)):
        info = inspect(path)
        if info.get("MountPoint") != path or str(info.get("VolumeUUID", "")).casefold() != expected.casefold():
            raise ValueError(f"Refusing mirror: mounted volume identity mismatch at {path}")


def inspect_disk(path):
    return plistlib.loads(subprocess.check_output(["/usr/sbin/diskutil", "info", "-plist", path], timeout=5))


if __name__ == "__main__":
    try:
        if len(sys.argv) != 5:
            raise ValueError("Expected source/destination mountpoints and their enrolled UUIDs")
        validate(*sys.argv[1:], inspect_disk)
    except (ValueError, subprocess.SubprocessError, OSError) as error:
        raise SystemExit(str(error))
