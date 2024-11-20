# SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
#
# SPDX-License-Identifier: MIT

"""Create a buildroot package lock file based on the given package inputs."""

import argparse
import dataclasses
import glob
import json
import pathlib
import re
import sys
import typing as T


@dataclasses.dataclass(frozen=True)
class DownloadInfo:
    algo: str
    checksum: str


def is_http_download(uri: str) -> bool:
    # Note that this should handle both http and https with or without '|urlencode'.
    return uri.split("+", maxsplit=1)[0].startswith("http")


def create_download_info(
    checksums_index: T.Dict[str, DownloadInfo], package_info: T.Dict
) -> T.Dict:
    result = {}

    for package in package_info.values():
        for download in package.get("downloads", []):
            source = download["source"]
            uris = [
                uri.split("+", maxsplit=1)[-1] + "/" + source
                for uri in download["uris"]
                if is_http_download(uri)
            ]
            if source not in checksums_index:
                name = package["name"] + "-" + package["version"]
                print(f"Missing source {name} in checksums")
                print("URLs:", "\n".join(uris))
                raise Exception(f"Missing checksum for source {name}")
            download_info = checksums_index[source]
            result[source] = dict(
                uris=uris, algo=download_info.algo, checksum=download_info.checksum
            )

    return result


def index_download_checksums() -> T.Dict[str, DownloadInfo]:
    result = {}
    hash_pattern = re.compile(r"(\w+)\s+([a-zA-Z0-9]+)\s+(\S+)\s*")

    for hashfile in glob.iglob("**/*.hash", recursive=True):
        with open(hashfile, mode="r") as hashlines:
            for hashline in hashlines:
                match = re.fullmatch(hash_pattern, hashline)
                if match:
                    result[match.group(3)] = DownloadInfo(
                        algo=match.group(1), checksum=match.group(2)
                    )

    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input",
        "-i",
        type=pathlib.Path,
        required=True,
        help="Path to the input package info JSON file.",
    )
    parser.add_argument(
        "--output", "-o", type=pathlib.Path, help="Path to write the output lock file."
    )
    args = parser.parse_args()

    package_info = json.loads(args.input.read_text())
    checksums_index = index_download_checksums()
    downloads_info = create_download_info(checksums_index, package_info)
    output = json.dumps(downloads_info, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(output)
    else:
        print(output)


if __name__ == "__main__":
    main()
