#!/usr/bin/env python3
"""Opdaterer sidestore/source.json (AltStore/SideStore-kildeformat) med en ny version.

Brug: make_source.py <version> <build> <ipa-sti> <download-url>
"""
import json, os, sys
from datetime import datetime, timezone

version, build, ipa, url = sys.argv[1:5]
path = os.path.join(os.path.dirname(__file__), "..", "sidestore", "source.json")
raw = "https://raw.githubusercontent.com/Thyxo/Lie-Detector/main"
icon = f"{raw}/ios/MindTrace/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

try:
    with open(path) as f:
        old_versions = json.load(f)["apps"][0]["versions"]
except Exception:
    old_versions = []

new = {
    "version": version,
    "buildVersion": build,
    "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "localizedDescription": f"Build {build}",
    "downloadURL": url,
    "size": os.path.getsize(ipa),
    "minOSVersion": "17.0",
}
versions = [new] + [v for v in old_versions if v.get("version") != version][:4]

source = {
    "name": "MindTrace",
    "identifier": "dk.thyxo.mindtrace.source",
    "subtitle": "Løgnedetektor med magnet",
    "description": "Kilde til MindTrace – opdateres automatisk ved hver ny build.",
    "iconURL": icon,
    "website": "https://github.com/Thyxo/Lie-Detector",
    "tintColor": "#3BC4CA",
    "apps": [{
        "name": "MindTrace",
        "bundleIdentifier": "dk.thyxo.mindtrace",
        "developerName": "Thyxo",
        "subtitle": "Sandt eller falsk?",
        "localizedDescription": "Tryllerekvisit: telefonen føres over tilskuerens hånd og afslører med magnetometeret, om der gemmer sig en magnet. Magnet = Falsk.",
        "iconURL": icon,
        "tintColor": "#3BC4CA",
        "category": "entertainment",
        "screenshots": [],
        "versions": versions,
        "appPermissions": {
            "entitlements": [],
            "privacy": {"NSMotionUsageDescription": "Bruges til at måle magnetfeltet."},
        },
    }],
    "news": [],
}

with open(path, "w") as f:
    json.dump(source, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"source.json -> {version} ({build}), {new['size']} bytes")
