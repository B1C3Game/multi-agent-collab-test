param(
    [string]$FilePath = "SHARED.md",
    [string]$TrustConfigPath = "trust-config.json",
    [string]$OutputJsonPath = "evidence/validation-latest.json"
)

$ErrorActionPreference = 'Stop'

function Read-TextFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw
}

function Add-Result {
    param([string]$Id, [bool]$Passed, [string]$Reason)
    [PSCustomObject]@{
        id = $Id
        passed = $Passed
        reason = $Reason
    }
}

try {
    $content = Read-TextFile -Path $FilePath
    $configRaw = Read-TextFile -Path $TrustConfigPath
    $config = $configRaw | ConvertFrom-Json

    $trusted = @($config.trusted_uids)
    $conditional = @($config.conditionally_trusted_uids)
    $blocked = @($config.blocked_uids)

    $allowFutureSeconds = [int]$config.timestamp.allowFutureSeconds
    $maxAgeDays = [int]$config.timestamp.maxAgeDays

    $lines = $content -split "`r?`n"
    $blocks = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '<!-- EDIT') {
            $uid = $null
            $timestamp = $null
            $intent = $null
            $editor = $null

            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                $line = $lines[$j].Trim()
                if ($line -eq '-->') {
                    $i = $j
                    break
                }
                if ($line.StartsWith('UID:')) { $uid = $line.Substring(4).Trim() }
                elseif ($line.StartsWith('TIMESTAMP:')) { $timestamp = $line.Substring(10).Trim() }
                elseif ($line.StartsWith('INTENT:')) { $intent = $line.Substring(7).Trim() }
                elseif ($line.StartsWith('EDITOR:')) { $editor = $line.Substring(7).Trim() }
            }

            $blocks += [PSCustomObject]@{
                uid = $uid
                timestamp = $timestamp
                intent = $intent
                editor = $editor
            }
        }
    }

    $results = @()

    $hasBlocks = $blocks.Count -gt 0
    if ($hasBlocks) {
        $e1Reason = "Found $($blocks.Count) edit block(s)."
    }
    else {
        $e1Reason = 'No edit blocks found.'
    }
    $results += Add-Result -Id 'E1_EDIT_BLOCKS_PRESENT' -Passed:$hasBlocks -Reason $e1Reason

    $allFieldsPresent = $true
    $fieldReasons = @()
    foreach ($b in $blocks) {
        if ([string]::IsNullOrWhiteSpace($b.uid) -or [string]::IsNullOrWhiteSpace($b.timestamp) -or [string]::IsNullOrWhiteSpace($b.intent) -or [string]::IsNullOrWhiteSpace($b.editor)) {
            $allFieldsPresent = $false
            $fieldReasons += 'Missing one or more required fields in an edit block.'
        }
    }
    if ($allFieldsPresent) {
        $e2Reason = 'All edit blocks include UID, TIMESTAMP, INTENT, and EDITOR.'
    }
    else {
        $e2Reason = ($fieldReasons -join '; ')
    }
    $results += Add-Result -Id 'E2_REQUIRED_FIELDS' -Passed:$allFieldsPresent -Reason $e2Reason

    $uidPolicyPassed = $true
    $uidReasons = @()
    foreach ($b in $blocks) {
        if ($blocked -contains $b.uid) {
            $uidPolicyPassed = $false
            $uidReasons += "Blocked UID used: $($b.uid)"
            continue
        }
        if ((-not ($trusted -contains $b.uid)) -and (-not ($conditional -contains $b.uid))) {
            $uidPolicyPassed = $false
            $uidReasons += "UID not allowed by trust policy: $($b.uid)"
        }
    }
    if ($uidPolicyPassed) {
        $e3Reason = 'All UIDs satisfy trust policy.'
    }
    else {
        $e3Reason = ($uidReasons -join '; ')
    }
    $results += Add-Result -Id 'E3_UID_POLICY' -Passed:$uidPolicyPassed -Reason $e3Reason

    $timestampPassed = $true
    $timestampReasons = @()
    $now = [DateTimeOffset]::UtcNow
    foreach ($b in $blocks) {
        $parsed = [DateTimeOffset]::MinValue
        $ok = [DateTimeOffset]::TryParse($b.timestamp, [ref]$parsed)
        if (-not $ok) {
            $timestampPassed = $false
            $timestampReasons += "Invalid timestamp: $($b.timestamp)"
            continue
        }
        if ($parsed -gt $now.AddSeconds($allowFutureSeconds)) {
            $timestampPassed = $false
            $timestampReasons += "Future timestamp beyond policy: $($b.timestamp)"
        }
        if ($parsed -lt $now.AddDays(-$maxAgeDays)) {
            $timestampPassed = $false
            $timestampReasons += "Stale timestamp beyond policy: $($b.timestamp)"
        }
    }
    if ($timestampPassed) {
        $e4Reason = 'All timestamps satisfy policy.'
    }
    else {
        $e4Reason = ($timestampReasons -join '; ')
    }
    $results += Add-Result -Id 'E4_TIMESTAMP_POLICY' -Passed:$timestampPassed -Reason $e4Reason

    $allPassed = ($results | Where-Object { -not $_.passed }).Count -eq 0
    $status = if ($allPassed) { 'pass' } else { 'fail' }

    $payload = [PSCustomObject]@{
        editValidationInput = [PSCustomObject]@{
            filePath = $FilePath
            trustConfigPath = $TrustConfigPath
        }
        editValidationResult = [PSCustomObject]@{
            status = $status
            checks = $results
        }
    }

    $json = $payload | ConvertTo-Json -Depth 6

    if ($OutputJsonPath) {
        $outDir = Split-Path -Path $OutputJsonPath -Parent
        if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }
        Set-Content -LiteralPath $OutputJsonPath -Value $json -Encoding utf8
    }

    Write-Host "Edit Validation Status: $status"
    foreach ($r in $results) {
        $symbol = if ($r.passed) { '[PASS]' } else { '[FAIL]' }
        Write-Host "$symbol $($r.id): $($r.reason)"
    }

    if ($allPassed) { exit 0 }
    exit 1
}
catch {
    Write-Error $_
    exit 1
}
