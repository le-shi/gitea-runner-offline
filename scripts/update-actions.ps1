param(
    [string]$LockFile = (Join-Path $PSScriptRoot '..\actions.lock')
)

$ErrorActionPreference = 'Stop'
$updated = [System.Collections.Generic.List[string]]::new()

foreach ($line in Get-Content -LiteralPath $LockFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        $updated.Add($line)
        continue
    }

    $cacheName, $repository, $oldCommit, $friendlyRef = $line -split '\|', 4
    $resolved = git ls-remote $repository "refs/tags/$friendlyRef" "refs/tags/$friendlyRef^{}" "refs/heads/$friendlyRef"
    if ($LASTEXITCODE -ne 0 -or -not $resolved) {
        throw "Unable to resolve $repository@$friendlyRef"
    }

    $peeled = $resolved | Where-Object { $_ -match '\^\{\}$' } | Select-Object -First 1
    $selected = if ($peeled) { $peeled } else { $resolved | Select-Object -First 1 }
    $commit = ($selected -split '\s+')[0]
    if ($commit -notmatch '^[0-9a-f]{40}$') {
        throw "Invalid resolved commit for $repository@$friendlyRef"
    }

    $updated.Add("$cacheName|$repository|$commit|$friendlyRef")
}

$content = ($updated -join "`n") + "`n"
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $LockFile), $content, [System.Text.UTF8Encoding]::new($false))
