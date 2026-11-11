#!/usr/bin/env python3
"""Unlock the existing local FinBot distribution keychain before exporting."""
import subprocess
from pathlib import Path


def main():
    auth_root = Path.home() / "Documents/Auths/FinBot"
    keychain = auth_root / "FinBot-Signing.keychain-db"
    password_file = auth_root / "FinBot-Signing-Keychain.password"
    if not keychain.is_file() or not password_file.is_file():
        raise SystemExit("FinBot signing keychain is missing. See docs/ios/internal-testflight-workflow.md.")
    if password_file.stat().st_mode & 0o077:
        raise SystemExit("Signing password file must have owner-only permissions (chmod 600).")
    password = password_file.read_text().strip()

    def run(args):
        result = subprocess.run(args, capture_output=True, text=True)
        if result.returncode:
            raise SystemExit(result.stderr.strip() or "Could not prepare signing keychain.")
        return result.stdout

    run(["security", "unlock-keychain", "-p", password, str(keychain)])
    existing = run(["security", "list-keychains", "-d", "user"])
    paths = [line.strip().strip('"') for line in existing.splitlines() if line.strip()]
    run(["security", "list-keychains", "-d", "user", "-s", str(keychain)]
        + [path for path in paths if path != str(keychain)])
    identities = run(["security", "find-identity", "-v", "-p", "codesigning", str(keychain)])
    if "Apple Distribution:" not in identities:
        raise SystemExit("No valid Apple Distribution identity in the FinBot signing keychain.")
    print("FinBot distribution signing is ready.")


if __name__ == "__main__":
    main()
