# SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
# SPDX-FileContributor: Rasmus Söderhielm <rasmus.soderhielm@gmail.com>
#
# SPDX-License-Identifier: MIT

"""Create a buildroot package lock file based on the given package inputs."""

import argparse
import dataclasses
import glob
import json
import pathlib
import re
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
            download_info = checksums_index[source]
            result[source] = dict(
                uris=uris, algo=download_info.algo, checksum=download_info.checksum
            )

    return result


def index_download_checksums(dir: pathlib.Path) -> T.Dict[str, DownloadInfo]:
    result = {}
    hash_pattern = re.compile(r"(\w+)\s+([a-zA-Z0-9]+)\s+(\S+)\s*")

    for hashfile in dir.rglob("*.hash"):
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
    parser.add_argument(
        "--patch-dir",
        type=pathlib.Path,
        help="Optional path to search for hash files. Should have same the value as BR2_GLOBAL_PATCH_DIR.",
    )
    args = parser.parse_args()

    package_info = json.loads(args.input.read_text())
    checksums_index = index_download_checksums(pathlib.Path("."))
    if args.patch_dir:
        checksums_index |= index_download_checksums(args.patch_dir)
    downloads_info = create_download_info(checksums_index, package_info)
    output = json.dumps(downloads_info, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(output)
    else:
        print(output)


if __name__ == "__main__":
    main()
