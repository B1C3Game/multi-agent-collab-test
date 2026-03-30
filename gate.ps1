param(
    [string]$FilePath = "SHARED.md",
    [string]$TrustConfigPath = "trust-config.json",
    [string]$A1SignaturePath = "signatures/task-001-a1-signature.md",
    [string]$A2SignaturePath = "signatures/task-001-a2-signature.md",
    [string]$CaptainSignaturePath = "signatures/task-001-captain-signature.md",
    [string]$OutputJsonPath = "evidence/gate-latest.json"
)

$ErrorActionPreference = 'Stop'

$editOut = "evidence/gate-edit-validation.json"
$sigOut = "evidence/gate-signature-validation.json"

powershell -NoProfile -ExecutionPolicy Bypass -File "validate-edits.ps1" -FilePath $FilePath -TrustConfigPath $TrustConfigPath -OutputJsonPath $editOut | Out-Null
$editCode = $LASTEXITCODE

powershell -NoProfile -ExecutionPolicy Bypass -File "verify-signature-chain.ps1" -TrustConfigPath $TrustConfigPath -A1SignaturePath $A1SignaturePath -A2SignaturePath $A2SignaturePath -CaptainSignaturePath $CaptainSignaturePath -OutputJsonPath $sigOut | Out-Null
$sigCode = $LASTEXITCODE

$passed = ($editCode -eq 0) -and ($sigCode -eq 0)
$status = if ($passed) { 'pass' } else { 'fail' }

$result = [PSCustomObject]@{
    collabGate = [PSCustomObject]@{
        status = $status
        editValidationExitCode = $editCode
        signatureValidationExitCode = $sigCode
        editValidationJson = $editOut
        signatureValidationJson = $sigOut
    }
}

$json = $result | ConvertTo-Json -Depth 6

if ($OutputJsonPath) {
    $dir = Split-Path -Path $OutputJsonPath -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $OutputJsonPath -Value $json -Encoding utf8
}

Write-Host "Collab Gate Status: $status"
Write-Host "Edit validation exit code: $editCode"
Write-Host "Signature validation exit code: $sigCode"

if ($passed) { exit 0 }
exit 1
