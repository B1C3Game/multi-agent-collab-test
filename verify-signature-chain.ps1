param(
    [string]$TrustConfigPath = "trust-config.json",
    [string]$A1SignaturePath = "signatures/task-001-a1-signature.md",
    [string]$A2SignaturePath = "signatures/task-001-a2-signature.md",
    [string]$CaptainSignaturePath = "signatures/task-001-captain-signature.md",
    [string]$OutputJsonPath = "evidence/signature-chain-latest.json"
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

function Get-SignatureArtifact {
    param([string]$SignatureFilePath, [string]$Content)

    $lines = $Content -split "`r?`n"
    $role = $null
    $payloadPath = $null
    $payloadSha = $null

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('role:')) { $role = $trimmed.Substring(5).Trim() }
        elseif ($trimmed.StartsWith('payload_path:')) { $payloadPath = $trimmed.Substring(13).Trim() }
        elseif ($trimmed.StartsWith('payload_sha256:')) { $payloadSha = $trimmed.Substring(15).Trim() }
    }

    $sigLineIndex = -1
    for ($i = 0; $i -lt ($lines.Count - 1); $i++) {
        if ($lines[$i].Trim().StartsWith('<!-- CHAIN-SIGNATURE:')) { $sigLineIndex = $i; break }
    }
    if ($sigLineIndex -lt 0) { throw "Missing CHAIN-SIGNATURE block in $SignatureFilePath" }

    $sigLine = $lines[$sigLineIndex].Trim()
    if (-not $sigLine.EndsWith(' -->')) { throw "Malformed CHAIN-SIGNATURE block in $SignatureFilePath" }

    $sigBody = $sigLine.Substring(21, $sigLine.Length - 25)

    $firstColon = $sigBody.IndexOf(':')
    if ($firstColon -lt 1) { throw "Incomplete CHAIN-SIGNATURE block in $SignatureFilePath" }

    $sigRole = $sigBody.Substring(0, $firstColon)
    $remainingAfterRole = $sigBody.Substring($firstColon + 1)

    $secondColon = $remainingAfterRole.IndexOf(':')
    if ($secondColon -lt 1) { throw "Incomplete CHAIN-SIGNATURE block in $SignatureFilePath" }

    $sigUid = $remainingAfterRole.Substring(0, $secondColon)
    $remainingAfterUid = $remainingAfterRole.Substring($secondColon + 1)

    if ($remainingAfterUid.Length -lt 85) { throw "Incomplete CHAIN-SIGNATURE block in $SignatureFilePath" }

    $sigTimestamp = $remainingAfterUid.Substring(0, 20)
    if ($remainingAfterUid[20] -ne ':') { throw "Malformed timestamp separator in CHAIN-SIGNATURE block in $SignatureFilePath" }

    $sigHash = $remainingAfterUid.Substring(21)
    $claimText = $lines[$sigLineIndex + 1].Trim()

    return [PSCustomObject]@{
        artifact_path = $SignatureFilePath
        role = $role
        payload_path = $payloadPath
        payload_sha256 = $payloadSha
        sig_role = $sigRole
        sig_uid = $sigUid
        sig_timestamp = $sigTimestamp
        sig_hash = $sigHash
        claim_text = $claimText
    }
}

try {
    $config = (Read-TextFile -Path $TrustConfigPath) | ConvertFrom-Json
    $trusted = @($config.trusted_uids)
    $futureSeconds = [int]$config.timestamp.allowFutureSeconds
    $maxAgeDays = [int]$config.timestamp.maxAgeDays

    $a1 = Get-SignatureArtifact -SignatureFilePath $A1SignaturePath -Content (Read-TextFile -Path $A1SignaturePath)
    $a2 = Get-SignatureArtifact -SignatureFilePath $A2SignaturePath -Content (Read-TextFile -Path $A2SignaturePath)
    $captain = Get-SignatureArtifact -SignatureFilePath $CaptainSignaturePath -Content (Read-TextFile -Path $CaptainSignaturePath)

    $artifacts = @($a1, $a2, $captain)
    $results = @()

    $expected = @{ 'a1-scaffold'='a1-uuid'; 'a2-ack'='a2-uuid'; 'captain-approval'='b1c3-uuid' }

    $mapOk = $true
    $mapReasons = @()
    foreach ($a in $artifacts) {
        if ($a.role -ne $a.sig_role) { $mapOk = $false; $mapReasons += "role mismatch in $($a.artifact_path)"; continue }
        if (-not $expected.ContainsKey($a.role)) { $mapOk = $false; $mapReasons += "unexpected role: $($a.role)"; continue }
        if ($a.sig_uid -ne $expected[$a.role]) { $mapOk = $false; $mapReasons += "role signer mismatch for $($a.role)" }
        if ($trusted -notcontains $a.sig_uid) { $mapOk = $false; $mapReasons += "signer not trusted: $($a.sig_uid)" }
    }
    if ($mapOk) {
        $s1Reason = 'Role to UID mapping is valid.'
    }
    else {
        $s1Reason = $mapReasons -join '; '
    }
    $results += Add-Result -Id 'S1_ROLE_UID_MAPPING' -Passed:$mapOk -Reason $s1Reason

    $hashOk = $true
    $hashReasons = @()
    foreach ($a in $artifacts) {
        $expectedHash = Get-StringSha256 -Text $a.claim_text
        if ($expectedHash -ne $a.sig_hash) { $hashOk = $false; $hashReasons += "signature hash mismatch in $($a.artifact_path)" }
    }
    if ($hashOk) {
        $s2Reason = 'Signature claim hashes are valid.'
    }
    else {
        $s2Reason = $hashReasons -join '; '
    }
    $results += Add-Result -Id 'S2_SIGNATURE_HASHES' -Passed:$hashOk -Reason $s2Reason

    $tsOk = $true
    $tsReasons = @()
    $parsed = @{}
    $now = [DateTimeOffset]::UtcNow
    foreach ($a in $artifacts) {
        $t = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse($a.sig_timestamp, [ref]$t)) { $tsOk = $false; $tsReasons += "invalid timestamp in $($a.artifact_path)"; continue }
        if ($t -gt $now.AddSeconds($futureSeconds)) { $tsOk = $false; $tsReasons += "future timestamp in $($a.artifact_path)" }
        if ($t -lt $now.AddDays(-$maxAgeDays)) { $tsOk = $false; $tsReasons += "stale timestamp in $($a.artifact_path)" }
        $parsed[$a.role] = $t
    }
    if ($tsOk -and $parsed.ContainsKey('a1-scaffold') -and $parsed.ContainsKey('a2-ack') -and $parsed.ContainsKey('captain-approval')) {
        if ($parsed['a1-scaffold'] -gt $parsed['a2-ack'] -or $parsed['a2-ack'] -gt $parsed['captain-approval']) {
            $tsOk = $false
            $tsReasons += 'signature chain timestamps are not monotonic'
        }
    }
    if ($tsOk) {
        $s3Reason = 'Signature timestamps are valid and monotonic.'
    }
    else {
        $s3Reason = $tsReasons -join '; '
    }
    $results += Add-Result -Id 'S3_SIGNATURE_TIMESTAMPS' -Passed:$tsOk -Reason $s3Reason

    $payloadOk = $true
    $payloadReasons = @()

    $firstPath = $artifacts[0].payload_path
    $firstHash = $artifacts[0].payload_sha256

    foreach ($a in $artifacts) {
        if ([string]::IsNullOrWhiteSpace($a.payload_path) -or [string]::IsNullOrWhiteSpace($a.payload_sha256)) {
            $payloadOk = $false
            $payloadReasons += "payload fields missing in $($a.artifact_path)"
            continue
        }
        if ($a.payload_path -ne $firstPath -or $a.payload_sha256 -ne $firstHash) {
            $payloadOk = $false
            $payloadReasons += "payload reference mismatch in $($a.artifact_path)"
        }
    }

    if (-not (Test-Path -LiteralPath $firstPath)) {
        $payloadOk = $false
        $payloadReasons += "payload file missing: $firstPath"
    }
    else {
        $actualHash = (Get-FileHash -LiteralPath $firstPath -Algorithm SHA256).Hash.ToLower()
        if ($actualHash -ne $firstHash) {
            $payloadOk = $false
            $payloadReasons += 'payload hash mismatch'
        }
    }
    if ($payloadOk) {
        $s4Reason = 'All signatures reference the same valid payload and hash.'
    }
    else {
        $s4Reason = $payloadReasons -join '; '
    }
    $results += Add-Result -Id 'S4_PAYLOAD_REFERENCE' -Passed:$payloadOk -Reason $s4Reason

    $allPassed = ($results | Where-Object { -not $_.passed }).Count -eq 0
    $status = if ($allPassed) { 'pass' } else { 'fail' }

    $payload = [PSCustomObject]@{
        signatureChainInput = [PSCustomObject]@{
            trustConfigPath = $TrustConfigPath
            a1SignaturePath = $A1SignaturePath
            a2SignaturePath = $A2SignaturePath
            captainSignaturePath = $CaptainSignaturePath
        }
        signatureChainResult = [PSCustomObject]@{
            status = $status
            checks = $results
        }
    }

    $json = $payload | ConvertTo-Json -Depth 6
    if ($OutputJsonPath) {
        $outDir = Split-Path -Path $OutputJsonPath -Parent
        if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
        Set-Content -LiteralPath $OutputJsonPath -Value $json -Encoding utf8
    }

    Write-Host "Signature Chain Status: $status"
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
