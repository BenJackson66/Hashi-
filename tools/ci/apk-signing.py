#!/usr/bin/env python3
"""Verify public signing certificates. No keystore/password inputs or key creation."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys


def fingerprint(apk: Path, apksigner: str) -> str:
    if not apk.is_file():
        raise ValueError("APK not found")
    result = subprocess.run(
        [apksigner, "verify", "--verbose", "--print-certs", str(apk)],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise ValueError("APK signature verification failed")
    digests = re.findall(
        r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})\s*$",
        result.stdout, re.MULTILINE,
    )
    if len(digests) != 1:
        raise ValueError("Expected exactly one APK signing certificate")
    return digests[0].lower()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apksigner", default=str(Path(os.environ.get("ANDROID_HOME", "")) / "build-tools/36.1.0/apksigner"))
    sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify", help="Require the APK certificate to match supplied public DER certificate")
    verify.add_argument("apk", type=Path)
    verify.add_argument("--certificate", type=Path, required=True)
    verify.add_argument("--output", type=Path, required=True, help="Public SHA-256 fingerprint, never a key")
    compare = sub.add_parser("compare", help="Verify two signed APKs use the same certificate")
    compare.add_argument("first", type=Path)
    compare.add_argument("second", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "verify":
            digest = fingerprint(args.apk, args.apksigner)
            expected = hashlib.sha256(args.certificate.read_bytes()).hexdigest()
            if digest != expected:
                raise ValueError("APK certificate does not match the supplied signing identity")
            args.output.write_text(digest + "\n")
            print("APK certificate matches the supplied signing identity.")
        else:
            if args.first.resolve() == args.second.resolve():
                raise ValueError("Supply APKs from two distinct builds")
            if fingerprint(args.first, args.apksigner) != fingerprint(args.second, args.apksigner):
                raise ValueError("The APKs use different signing certificates")
            print("Both APK signatures are valid and use the same certificate.")
            print("Device upgrade and data retention still require an Android test.")
    except (OSError, ValueError) as error:
        # Avoid echoing subprocess output or filesystem paths to CI logs.
        message = str(error) if isinstance(error, ValueError) else "Unable to access the APK verification tools or files"
        print(message, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
