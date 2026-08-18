#!/usr/bin/env python3
import json
import os
import pathlib
import subprocess
import tomllib

root = pathlib.Path("/opt/gitea-runner-offline")


def command_output(*command: str) -> str:
    return subprocess.check_output(command, text=True).strip()


def data_lines(path: pathlib.Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


actions = []
for line in data_lines(root / "actions.lock"):
    fields = line.split("|")
    actions.append(
        {
            "cache_name": fields[0],
            "repository": fields[1],
            "commit": fields[2],
            "version": fields[3],
            "runtime_cache_key": fields[4] if len(fields) == 5 else None,
        }
    )

docker_cli = []
for line in data_lines(root / "docker-cli.lock"):
    version, amd64_sha256, arm64_sha256 = line.split("|")
    docker_cli.append(
        {
            "version": version,
            "amd64_sha256": amd64_sha256,
            "arm64_sha256": arm64_sha256,
        }
    )

offline_images = []
for line in data_lines(root / "offline-images.lock"):
    name, source, local_tag = line.split("|")
    offline_images.append({"name": name, "source": source, "local_tag": local_tag})

dependency_seeds = {}
for seed_file in sorted((root / "dependency-seeds").glob("*.txt")):
    dependency_seeds[seed_file.name] = data_lines(seed_file)

dotnet = []
for major in ("6", "8", "9", "10"):
    dotnet.append(command_output(f"/opt/dotnet/{major}/dotnet", "--version"))

capabilities = {
    "schema_version": 1,
    "architecture": os.environ.get("TARGETARCH", command_output("uname", "-m")),
    "runner": command_output("/usr/local/bin/gitea-runner", "--version"),
    "job_environment": {
        "image_os": os.environ.get("ImageOS"),
        "runner_tool_cache": os.environ.get("RUNNER_TOOL_CACHE"),
        "act_tool_cache": os.environ.get("ACT_TOOLSDIRECTORY"),
        "runner_temp": os.environ.get("RUNNER_TEMP"),
    },
    "toolchains": tomllib.loads((root / "mise.toml").read_text(encoding="utf-8"))["tools"],
    "dotnet": dotnet,
    "docker": {
        "default": command_output("docker", "--version"),
        "available_cli": docker_cli,
        "buildx": command_output("docker", "buildx", "version"),
        "compose": command_output("docker", "compose", "version"),
    },
    "actions": actions,
    "dependency_seeds": dependency_seeds,
    "offline_images": offline_images,
}

(root / "capabilities.json").write_text(
    json.dumps(capabilities, ensure_ascii=True, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
