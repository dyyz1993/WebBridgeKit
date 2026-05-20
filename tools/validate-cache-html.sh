#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="${WBK_CACHE_HTML_BASE_URL:-http://localhost:8081/test_resources/cache-html-validation}"
OUT_DIR="${WBK_CACHE_HTML_OUT_DIR:-/tmp/wbk-cache-html-validation}"

mkdir -p "$OUT_DIR"

cd "$ROOT"

bash scripts/services.sh start >/dev/null
bash scripts/services.sh verify >/dev/null

python3 - "$BASE_URL" "$OUT_DIR" <<'PY'
import json
import re
import sys
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

base_url = sys.argv[1].rstrip("/")
out_dir = Path(sys.argv[2])

manifest_url = f"{base_url}/manifest.json"

class ResourceParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.resources = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "link" and attrs.get("href"):
            self.resources.append(("link", "href", attrs["href"]))
        elif tag == "script" and attrs.get("src"):
            self.resources.append(("script", "src", attrs["src"]))
        elif tag in {"img", "iframe", "audio", "video", "source"} and attrs.get("src"):
            self.resources.append((tag, "src", attrs["src"]))
        if attrs.get("srcset"):
            for candidate in attrs["srcset"].split(","):
                url = candidate.strip().split(" ")[0]
                if url:
                    self.resources.append((tag, "srcset", url))

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "WBK cache-html validator"})
    with urllib.request.urlopen(req, timeout=10) as response:
        data = response.read()
        headers = dict(response.headers.items())
        return response.status, headers, data

def absolutize(url, relative):
    if relative.startswith("data:") or relative.startswith("javascript:"):
        return None
    return urllib.parse.urljoin(url, relative)

manifest_status, manifest_headers, manifest_data = fetch(manifest_url)
manifest = json.loads(manifest_data.decode("utf-8"))

results = {
    "baseURL": base_url,
    "manifestStatus": manifest_status,
    "cases": [],
    "failures": []
}

for case in manifest["cases"]:
    page_url = f"{base_url}/{case['path']}"
    status, headers, data = fetch(page_url)
    html = data.decode("utf-8")
    parser = ResourceParser()
    parser.feed(html)

    resources = []
    for tag, attr, raw_url in parser.resources:
        absolute = absolutize(page_url, raw_url)
        if absolute is None:
            resources.append({
                "tag": tag,
                "attr": attr,
                "raw": raw_url,
                "absolute": None,
                "status": "ignored"
            })
            continue

        try:
            resource_status, resource_headers, resource_data = fetch(absolute)
            ok = 200 <= resource_status < 300
            resources.append({
                "tag": tag,
                "attr": attr,
                "raw": raw_url,
                "absolute": absolute,
                "status": resource_status,
                "bytes": len(resource_data),
                "cacheControl": resource_headers.get("Cache-Control", "")
            })
            if not ok:
                results["failures"].append(f"{case['id']}: {raw_url} -> HTTP {resource_status}")
        except Exception as exc:
            resources.append({
                "tag": tag,
                "attr": attr,
                "raw": raw_url,
                "absolute": absolute,
                "status": "error",
                "error": str(exc)
            })
            results["failures"].append(f"{case['id']}: {raw_url} -> {exc}")

    css_urls = []
    for match in re.finditer(r"<link[^>]+href=[\"']([^\"']+\\.css)[\"']", html, flags=re.I):
        css_url = absolutize(page_url, match.group(1))
        if not css_url:
            continue
        try:
            _, _, css_data = fetch(css_url)
            css_text = css_data.decode("utf-8", errors="ignore")
            for css_ref in re.findall(r"url\\([\"']?([^\"')]+)[\"']?\\)", css_text):
                css_absolute = absolutize(css_url, css_ref)
                if css_absolute:
                    css_urls.append(css_absolute)
        except Exception:
            pass

    for css_absolute in css_urls:
        try:
            resource_status, resource_headers, resource_data = fetch(css_absolute)
            resources.append({
                "tag": "css",
                "attr": "url()",
                "raw": css_absolute,
                "absolute": css_absolute,
                "status": resource_status,
                "bytes": len(resource_data),
                "cacheControl": resource_headers.get("Cache-Control", "")
            })
        except Exception as exc:
            resources.append({
                "tag": "css",
                "attr": "url()",
                "raw": css_absolute,
                "absolute": css_absolute,
                "status": "error",
                "error": str(exc)
            })
            results["failures"].append(f"{case['id']}: CSS url {css_absolute} -> {exc}")

    cache_control = headers.get("Cache-Control", "")
    if "max-age=3600" not in cache_control:
        results["failures"].append(f"{case['id']}: missing max-age=3600 Cache-Control header")

    results["cases"].append({
        "id": case["id"],
        "url": page_url,
        "status": status,
        "cacheControl": cache_control,
        "resourceCount": len([r for r in resources if r["status"] != "ignored"]),
        "ignoredCount": len([r for r in resources if r["status"] == "ignored"]),
        "resources": resources
    })

report_json = out_dir / "report.json"
report_json.write_text(json.dumps(results, indent=2), encoding="utf-8")

lines = [
    "# Cache HTML Validation Report",
    "",
    f"- Base URL: `{base_url}`",
    f"- Manifest: HTTP {manifest_status}",
    f"- Failures: {len(results['failures'])}",
    "",
    "| Case | Page | Resources | Ignored | Cache-Control | Status |",
    "|------|------|-----------|---------|---------------|--------|"
]

for case in results["cases"]:
    status_text = "PASS" if all(isinstance(r["status"], int) and 200 <= r["status"] < 300 or r["status"] == "ignored" for r in case["resources"]) else "CHECK"
    lines.append(
        f"| {case['id']} | `{case['url']}` | {case['resourceCount']} | {case['ignoredCount']} | `{case['cacheControl']}` | {status_text} |"
    )

if results["failures"]:
    lines.extend(["", "## Failures", ""])
    lines.extend(f"- {failure}" for failure in results["failures"])

lines.extend(["", "## Notes", ""])
lines.append("- `ignored` resources are intentionally skipped data/javascript URLs.")
lines.append("- CSS `url()` references are checked by this script even though the current Swift parser only parses HTML tags.")

report_md = out_dir / "report.md"
report_md.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"Report JSON: {report_json}")
print(f"Report Markdown: {report_md}")
print(json.dumps({
    "cases": len(results["cases"]),
    "failures": len(results["failures"]),
    "report": str(report_md)
}, indent=2))

if results["failures"]:
    sys.exit(1)
PY
