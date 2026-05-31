param(
    [string]$SshTarget = 'root@47.123.6.68',
    [string]$RemoteCursorRoot = '',
    [switch]$WhatIf
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Info($Message) { Write-Host ("[INFO] " + $Message) -ForegroundColor Cyan }
function Ok($Message) { Write-Host ("[OK] " + $Message) -ForegroundColor Green }
function Warn($Message) { Write-Host ("[WARN] " + $Message) -ForegroundColor Yellow }
function Fail($Message) { Write-Host ("[ERROR] " + $Message) -ForegroundColor Red; exit 1 }

function QuoteRemoteArg($Value) {
    return "'" + ([string]$Value).Replace("'", "'\''") + "'"
}

if ([string]::IsNullOrWhiteSpace($SshTarget)) {
    Fail 'Missing -SshTarget, for example: root@47.123.6.68'
}

$remoteScript = @'
#!/usr/bin/env bash
set -euo pipefail

root_arg="${1:-}"
translation_arg="${2:-}"
timestamp="$(date +%Y%m%d-%H%M%S)"

if [ -z "$translation_arg" ] || [ ! -f "$translation_arg" ]; then
  echo "[ERROR] Missing uploaded Git translation JSON." >&2
  exit 1
fi

find_git_nls_files() {
  if [ -n "$root_arg" ]; then
    find "$root_arg" -type f \( -path "*/extensions/git/package.nls.json" -o -path "*/resources/app/extensions/git/package.nls.json" \)
    return
  fi

  for root in "$HOME/.cursor-server/bin" "/root/.cursor-server/bin"; do
    if [ -d "$root" ]; then
      find "$root" -type f \( -path "*/extensions/git/package.nls.json" -o -path "*/resources/app/extensions/git/package.nls.json" \)
    fi
  done
}

mapfile -t files < <(find_git_nls_files | sort -u)

if [ "${#files[@]}" -eq 0 ]; then
  echo "[ERROR] No remote Cursor Server Git package.nls.json files were found." >&2
  echo "        Try passing the server root, for example:" >&2
  echo "        -RemoteCursorRoot /root/.cursor-server/bin/linux-x64/<commit>" >&2
  exit 1
fi

for file in "${files[@]}"; do
  backup="${file}.bak-${timestamp}"
  cp "$file" "$backup"
  python3 - "$file" "$translation_arg" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))

translation_path = pathlib.Path(sys.argv[2])
translations = json.loads(translation_path.read_text(encoding="utf-8"))
if isinstance(translations, dict) and isinstance(translations.get("contents"), dict):
    translations = translations["contents"].get("package", translations)

changed = []
for key, value in translations.items():
    if isinstance(value, dict) and "message" in value:
        value = value["message"]
    if not isinstance(value, str):
        continue
    current = data.get(key)
    if isinstance(current, dict) and "message" in current:
        if current.get("message") != value:
            current["message"] = value
            changed.append(key)
    elif current != value:
        data[key] = value
        changed.append(key)

path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print(f"[OK] patched {path} ({len(changed)} keys changed)")
PY
  echo "[OK] backup: ${backup}"
done

cache_roots=()
if [ -n "$root_arg" ]; then
  resolved_root="$(cd "$root_arg" && pwd -P)"
  case "$resolved_root" in
    */.cursor-server/bin/*)
      cursor_home="${resolved_root%%/.cursor-server/bin/*}/.cursor-server"
      if [ -d "$cursor_home/data/CachedProfilesData" ]; then
        cache_roots+=("$cursor_home/data/CachedProfilesData")
      fi
      ;;
  esac
else
  for cursor_home in "$HOME/.cursor-server" "/root/.cursor-server"; do
    if [ -d "$cursor_home/data/CachedProfilesData" ]; then
      cache_roots+=("$cursor_home/data/CachedProfilesData")
    fi
  done
fi

deleted_cache_count=0
if [ "${#cache_roots[@]}" -gt 0 ]; then
  while IFS= read -r cache_file; do
    [ -n "$cache_file" ] || continue
    backup="${cache_file}.bak-${timestamp}"
    cp "$cache_file" "$backup"
    rm -f "$cache_file"
    deleted_cache_count=$((deleted_cache_count + 1))
    echo "[OK] removed extension cache: ${cache_file}"
    echo "[OK] cache backup: ${backup}"
  done < <(
    printf '%s\n' "${cache_roots[@]}" |
      sort -u |
      while IFS= read -r cache_root; do
        find "$cache_root" -type f \( -name "extensions.builtin.cache" -o -name "extensions.user.cache" \)
      done |
      sort -u
  )
fi

echo "[OK] Removed ${deleted_cache_count} remote extension cache file(s)."
echo "[OK] Remote Cursor Server Git localization patched."
echo "[WARN] Disconnect Remote SSH, stop the remote Cursor Server, then reconnect."
echo "[WARN] If the old text remains, run: pkill -f cursor-server"
'@

$remoteName = 'cursor-remote-git-zh.sh'
$remotePath = '/tmp/' + $remoteName
$remoteTranslationName = 'cursor-remote-git-zh-translations.json'
$remoteTranslationPath = '/tmp/' + $remoteTranslationName
$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ($remoteName + '-' + [System.Guid]::NewGuid().ToString('N'))
$translationTempPath = Join-Path ([System.IO.Path]::GetTempPath()) ($remoteTranslationName + '-' + [System.Guid]::NewGuid().ToString('N'))

try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempPath, $remoteScript, $utf8NoBom)

    $scriptDir = Split-Path -Parent $PSCommandPath
    $vsixPath = Join-Path $scriptDir 'ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052214.vsix'
    if (-not (Test-Path -LiteralPath $vsixPath -PathType Leaf)) {
        Fail ("Missing fused language pack VSIX: " + $vsixPath)
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($vsixPath)
    try {
        $entry = $zip.GetEntry('extension/translations/extensions/vscode.git.i18n.json')
        if ($null -eq $entry) {
            Fail 'Fused VSIX is missing extension/translations/extensions/vscode.git.i18n.json'
        }
        $stream = $entry.Open()
        try {
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
            try {
                $translationJson = $reader.ReadToEnd()
            } finally {
                $reader.Dispose()
            }
        } finally {
            $stream.Dispose()
        }
    } finally {
        $zip.Dispose()
    }

    foreach ($requiredKey in @('view.workbench.cloneRepository', 'view.workbench.learnMore')) {
        if (-not $translationJson.Contains('"' + $requiredKey + '"')) {
            Fail ("Fused Git translation is missing key: " + $requiredKey)
        }
    }
    [System.IO.File]::WriteAllText($translationTempPath, $translationJson, $utf8NoBom)

    $remoteRootArg = QuoteRemoteArg $RemoteCursorRoot
    $remoteCommand = "bash " + (QuoteRemoteArg $remotePath) + " " + $remoteRootArg + " " + (QuoteRemoteArg $remoteTranslationPath) + "; code=`$?; rm -f " + (QuoteRemoteArg $remotePath) + " " + (QuoteRemoteArg $remoteTranslationPath) + "; exit `$code"

    Info ("SSH target: " + $SshTarget)
    if (-not [string]::IsNullOrWhiteSpace($RemoteCursorRoot)) { Info ("Remote Cursor root: " + $RemoteCursorRoot) }
    Info ("Remote temp script: " + $remotePath)
    Info ("Remote translation JSON: " + $remoteTranslationPath)

    if ($WhatIf) {
        Write-Host ("WhatIf: scp " + $tempPath + " " + $SshTarget + ":" + $remotePath)
        Write-Host ("WhatIf: scp " + $translationTempPath + " " + $SshTarget + ":" + $remoteTranslationPath)
        Write-Host ("WhatIf: ssh " + $SshTarget + " " + $remoteCommand)
        Warn 'No remote files were changed because -WhatIf was used.'
        exit 0
    }

    Warn 'This patches the Git extension inside the remote Cursor Server, not the local Cursor install.'
    Warn 'You may be prompted for the SSH password.'

    & scp $tempPath ($SshTarget + ':' + $remotePath)
    if ($LASTEXITCODE -ne 0) { Fail ("scp failed with exit code: " + $LASTEXITCODE) }
    & scp $translationTempPath ($SshTarget + ':' + $remoteTranslationPath)
    if ($LASTEXITCODE -ne 0) { Fail ("scp translation JSON failed with exit code: " + $LASTEXITCODE) }

    & ssh $SshTarget $remoteCommand
    if ($LASTEXITCODE -ne 0) { Fail ("remote patch failed with exit code: " + $LASTEXITCODE) }

    Ok 'Remote Cursor Server Git localization patch completed.'
    Warn 'Disconnect Remote SSH, stop the remote Cursor Server, then reconnect.'
} finally {
    if (Test-Path -Path $tempPath -PathType Leaf) {
        Remove-Item -LiteralPath $tempPath -Force
    }
    if (Test-Path -Path $translationTempPath -PathType Leaf) {
        Remove-Item -LiteralPath $translationTempPath -Force
    }
}
