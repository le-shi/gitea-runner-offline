#!/usr/bin/env python3
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "versions.env"
VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
FILES = [
    ROOT / "Dockerfile",
    ROOT / "README.md",
    ROOT / "examples" / "docker-compose.yaml",
]


def read_current_version() -> str:
    values = {}
    for line in VERSION_FILE.read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key] = value
    if values.get("RUNNER_VERSION") != values.get("IMAGE_VERSION"):
        raise SystemExit("RUNNER_VERSION and IMAGE_VERSION must match")
    return values["RUNNER_VERSION"]


def main() -> None:
    if len(sys.argv) != 2 or not VERSION_PATTERN.fullmatch(sys.argv[1]):
        raise SystemExit(f"Usage: {pathlib.Path(sys.argv[0]).name} <major.minor.patch>")

    old_version = read_current_version()
    new_version = sys.argv[1]
    if old_version == new_version:
        print(f"Runner version is already {new_version}")
        return

    for path in FILES:
        content = path.read_text(encoding="utf-8")
        updated = content.replace(old_version, new_version)
        if updated == content:
            raise SystemExit(f"Expected version {old_version} was not found in {path.relative_to(ROOT)}")
        path.write_text(updated, encoding="utf-8", newline="\n")

    version_content = VERSION_FILE.read_text(encoding="utf-8").replace(old_version, new_version)
    VERSION_FILE.write_text(version_content, encoding="utf-8", newline="\n")
    print(f"Updated Runner and image version: {old_version} -> {new_version}")


if __name__ == "__main__":
    main()
