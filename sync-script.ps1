param(
    [int]$IntervalMinutes = 5,
    [switch]$RunOnce
)

$ErrorActionPreference = 'Stop'

function Run-GitSync {
    Write-Host "Running git sync at $(Get-Date -Format o)"
    git pull --rebase
    git add -A
    if (-not (git diff --cached --quiet)) {
        git commit -m "sync: automated collaboration sync"
        git push
    }
    else {
        Write-Host "No local changes to commit."
    }
}

if ($RunOnce) {
    Run-GitSync
    exit 0
}

while ($true) {
    try {
        Run-GitSync
    }
    catch {
        Write-Host "Sync error: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds ($IntervalMinutes * 60)
}
