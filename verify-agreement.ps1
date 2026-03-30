param(
    [string]$AgreementPath = "AGENT-AGREEMENT.md",
    [string]$TrustConfigPath = "trust-config.json",
    [string]$OutputJsonPath = "evidence/agreement-validation-latest.json"
)

$ErrorActionPreference = 'Stop'

function Read-TextFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
    return Get-Content -LiteralPath $Path -Raw
}

function Get-StringSha256 {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLower()
    }
    finally {
        $sha.Dispose()
    }
}

function Add-Result {
    param([string]$Id, [bool]$Passed, [string]$Reason)
    [PSCustomObject]@{ id = $Id; passed = $Passed; reason = $Reason }
}

function Get-AgreementSignatures {
    param([string]$Content)

    $signatures = @()
    $lines = $Content -split "`r?`n"

    for ($i = 0; $i -lt ($lines.Count - 1); $i++) {
        $sigLine = $lines[$i].Trim()
        if (-not $sigLine.StartsWith('<!-- AGREEMENT-SIGNATURE:')) { continue }
        if (-not $sigLine.EndsWith(' -->')) { continue }

        $body = $sigLine.Substring(25, $sigLine.Length - 29)
        $firstColon = $body.IndexOf(':')
        if ($firstColon -lt 1) { continue }
        $uid = $body.Substring(0, $firstColon)
        $remaining = $body.Substring($firstColon + 1)

        if ($remaining.Length -lt 85) { continue }

        $timestamp = $remaining.Substring(0, 20)
        if ($remaining[20] -ne ':') { continue }
        $hash = $remaining.Substring(21)

        $claim = $lines[$i + 1].Trim()

        $signatures += [PSCustomObject]@{
            uid = $uid
            timestamp = $timestamp
            hash = $hash
            claim = $claim
        }
    }

    return $signatures
}

try {
    $agreement = Read-TextFile -Path $AgreementPath
    $config = (Read-TextFile -Path $TrustConfigPath) | ConvertFrom-Json
    $trusted = @($config.trusted_uids)

    $sigs = Get-AgreementSignatures -Content $agreement
    $results = @()

    $hasSigs = $sigs.Count -gt 0
    if ($hasSigs) { $a1 = "Found $($sigs.Count) agreement signature(s)." } else { $a1 = 'No agreement signatures found.' }
    $results += Add-Result -Id 'A1_SIGNATURES_PRESENT' -Passed:$hasSigs -Reason $a1

    $trustedSigned = $true
    $trustedReasons = @()
    foreach ($uid in $trusted) {
        if (-not ($sigs | Where-Object { $_.uid -eq $uid })) {
            $trustedSigned = $false
            $trustedReasons += "Trusted UID missing agreement signature: $uid"
        }
    }
    if ($trustedSigned) { $a2 = 'All trusted UIDs have signed the agreement.' } else { $a2 = $trustedReasons -join '; ' }
    $results += Add-Result -Id 'A2_TRUSTED_UIDS_SIGNED' -Passed:$trustedSigned -Reason $a2

    $hashesValid = $true
    $hashReasons = @()
    foreach ($sig in $sigs) {
        $expected = Get-StringSha256 -Text $sig.claim
        if ($expected -ne $sig.hash) {
            $hashesValid = $false
            $hashReasons += "Agreement signature hash mismatch for UID $($sig.uid)"
        }
    }
    if ($hashesValid) { $a3 = 'Agreement signature hashes are valid.' } else { $a3 = $hashReasons -join '; ' }
    $results += Add-Result -Id 'A3_SIGNATURE_HASHES' -Passed:$hashesValid -Reason $a3

    $allPassed = ($results | Where-Object { -not $_.passed }).Count -eq 0
    $status = if ($allPassed) { 'pass' } else { 'fail' }

    $payload = [PSCustomObject]@{
        agreementValidationInput = [PSCustomObject]@{
            agreementPath = $AgreementPath
            trustConfigPath = $TrustConfigPath
        }
        agreementValidationResult = [PSCustomObject]@{
            status = $status
            checks = $results
        }
    }

    $json = $payload | ConvertTo-Json -Depth 6

    if ($OutputJsonPath) {
        $dir = Split-Path -Path $OutputJsonPath -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -LiteralPath $OutputJsonPath -Value $json -Encoding utf8
    }

    Write-Host "Agreement Validation Status: $status"
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
