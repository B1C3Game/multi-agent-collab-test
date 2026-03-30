param(
  [switch]$RequireSignedCommit,
  [switch]$RequireDCO
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HeadSignatureCode {
  $line = git log -1 --format="%H %G?" 2>$null
  if (-not $line) {
    throw "Unable to read HEAD commit info."
  }
  $parts = $line.Trim().Split(" ")
  if ($parts.Count -lt 2) {
    throw "Unexpected git log format while reading signature status."
  }
  return @{ Hash = $parts[0]; SigCode = $parts[1] }
}

function Get-HeadMessage {
  return git log -1 --pretty=%B 2>$null
}

# %G? codes: G=good, U=good unknown trust, X=good expired key, Y=good expired sig, R=good revoked key, N=no sig, B=bad sig
$head = Get-HeadSignatureCode
$message = Get-HeadMessage

$signedCommitOk = $head.SigCode -in @("G", "U", "X", "Y", "R")
$hasDCO = $false
if ($message) {
  $hasDCO = [regex]::IsMatch($message, "(?im)^Signed-off-by:\s+.+<.+>$")
}

$checks = @(
  [pscustomobject]@{
    id = "P1"
    name = "HEAD commit signed"
    required = [bool]$RequireSignedCommit
    pass = $signedCommitOk
    details = "Signature code: $($head.SigCode)"
  }
  [pscustomobject]@{
    id = "P2"
    name = "DCO trailer present"
    required = [bool]$RequireDCO
    pass = $hasDCO
    details = if ($hasDCO) { "Signed-off-by trailer found" } else { "No Signed-off-by trailer" }
  }
)

$requiredFailures = @($checks | Where-Object { $_.required -and -not $_.pass })
$allRequiredPass = ($requiredFailures.Count -eq 0)

$result = [pscustomobject]@{
  timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
  repo = (Get-Location).Path
  head_commit = $head.Hash
  checks = $checks
  pass = $allRequiredPass
}

$result | ConvertTo-Json -Depth 6

if (-not $allRequiredPass) {
  exit 1
}
