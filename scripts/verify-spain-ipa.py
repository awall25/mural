#!/usr/bin/env python3
"""Verify the signed personal-fork package before TestFlight upload."""
import plistlib
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="spain-ipa-") as folder:
    root = Path(folder)
    with zipfile.ZipFile(sys.argv[1]) as archive:
        for name in archive.namelist():
            if not (root / name).resolve().is_relative_to(root.resolve()):
                raise SystemExit("Unsafe IPA path")
        archive.extractall(root)
    app, = (root / "Payload").glob("*.app")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "com.awall25.spaintrip"
    assert info["CFBundleDisplayName"] == "Spain Trip"
    assert info["CFBundleShortVersionString"] == "1.0"
    assert info["CFBundleVersion"] == sys.argv[2]
    assert info["UIDeviceFamily"] == [1]
    assert "audio" not in info.get("UIBackgroundModes", [])
    assert "NSSpeechRecognitionUsageDescription" in info
    assert "NSMicrophoneUsageDescription" in info
    assert "NSCameraUsageDescription" in info  # Required by the retained WebRTC binary.
    assert "CFBundleURLTypes" not in info
    assert info["MuralManagedAccountsEnabled"] == "NO"
    assert info["MuralApplePurchasesEnabled"] == "NO"
    entitlements = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)], check=True, capture_output=True).stdout
    signed = plistlib.loads(entitlements)
    assert signed["application-identifier"] == "L484ETZTGA.com.awall25.spaintrip"
    assert not signed.get("get-task-allow", False)
    assert "com.apple.developer.applesignin" not in signed
    print("Verified Spain Trip 1.0 (%s): signature, identity, permissions, iPhone support and disabled hosted features." % sys.argv[2])
