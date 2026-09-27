# Creates a second, selectable Windows boot entry with Hyper-V and VSM disabled.
# Never import another computer's BCD backup. Run on the target PC only.
param([switch]$Remove, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
$description = 'Service Mode - Hypervisor Off'
$stateDir = Join-Path $env:LOCALAPPDATA 'ServiceBootMode'
$guidFile = Join-Path $stateDir 'entry-guid.txt'

function Invoke-Bcd([string[]]$Arguments) {
    $text = (& bcdedit.exe @Arguments 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "bcdedit $($Arguments -join ' ') failed:`n$text" }
    return $text
}
function Get-Entry([string]$Id) {
    $text = (& bcdedit.exe /enum $Id 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { return $null }
    return $text
}
function Is-OurEntry([string]$Text) {
    return $Text -and ($Text -match ('(?im)^description\s+' + [regex]::Escape($description) + '\s*$'))
}

Write-Host "Target computer: $env:COMPUTERNAME"
Write-Host 'This script NEVER imports the supplied BCD backup or modifies {current}.'
Write-Host 'Changing the boot configuration may trigger BitLocker recovery. Save your recovery key first.'
Write-Host 'Disabling the hypervisor/VSM reduces security in the alternate boot mode only.'
if ($DryRun) {
    Write-Host 'DRY RUN: no BCD commands or boot changes made.'
    Write-Host 'On the target PC, creation exports its BCD, copies {current}, and sets only the copy hypervisorlaunchtype=off and vsmlaunchtype=off.'
    exit 0
}

$admin = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    if ($Remove) { $arguments += ' -Remove' }
    try { Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -Wait }
    catch { Write-Error "Administrator approval was not granted: $_"; exit 1 }
    exit 0
}

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
if ($Remove) {
    if (-not (Test-Path -LiteralPath $guidFile)) { throw "No saved entry ID at $guidFile; nothing to remove." }
    $id = (Get-Content -LiteralPath $guidFile -Raw).Trim()
    if ($id -notmatch '^\{[0-9a-fA-F-]{36}\}$') { throw 'Saved entry ID has an invalid format.' }
    $entry = Get-Entry $id
    if (-not (Is-OurEntry $entry)) { throw 'Saved entry is missing or its description differs; refusing deletion.' }
    Write-Host "Will delete ONLY the alternate entry $id ($description)."
    if ((Read-Host 'Type REMOVE to continue') -cne 'REMOVE') { Write-Host 'Cancelled.'; exit 0 }
    Invoke-Bcd @('/delete', $id) | Write-Host
    Remove-Item -LiteralPath $guidFile
    Write-Host 'Alternate entry removed. Previous BCD backups remain in the state directory.'
    exit 0
}

if (Test-Path -LiteralPath $guidFile) {
    $existing = (Get-Content -LiteralPath $guidFile -Raw).Trim()
    if ($existing -match '^\{[0-9a-fA-F-]{36}\}$' -and (Is-OurEntry (Get-Entry $existing))) {
        Write-Host "Alternate boot entry already exists: $existing"; exit 0
    }
    throw "Existing state file does not point to a valid $description entry. Inspect manually: $guidFile"
}
Write-Host 'A local BCD backup will be saved before changes. No reboot will be performed.'
if ((Read-Host 'Type CREATE to continue') -cne 'CREATE') { Write-Host 'Cancelled.'; exit 0 }
$backup = Join-Path $stateDir ('BCD-before-service-mode-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bcd')
Invoke-Bcd @('/export', $backup) | Write-Host
if (-not (Test-Path -LiteralPath $backup) -or (Get-Item -LiteralPath $backup).Length -eq 0) { throw 'BCD export is missing or empty; no boot entry created.' }
Write-Host "Local backup: $backup"
$id = $null
try {
    $copy = Invoke-Bcd @('/copy', '{current}', '/d', $description)
    $match = [regex]::Match($copy, '\{[0-9a-fA-F-]{36}\}')
    if (-not $match.Success) { throw "Could not determine the new boot entry ID: $copy" }
    $id = $match.Value
    Invoke-Bcd @('/set', $id, 'hypervisorlaunchtype', 'off') | Write-Host
    Invoke-Bcd @('/set', $id, 'vsmlaunchtype', 'off') | Write-Host
    $entry = Invoke-Bcd @('/enum', $id)
    if (-not (Is-OurEntry $entry) -or $entry -notmatch '(?im)^hypervisorlaunchtype\s+off\s*$' -or $entry -notmatch '(?im)^vsmlaunchtype\s+off\s*$') {
        throw "New entry verification failed:`n$entry"
    }
    Set-Content -LiteralPath $guidFile -Value $id -Encoding ASCII
    Write-Host "SUCCESS: $description ($id). Select it from the Windows boot menu on the next restart."
    Write-Host "To remove it later: powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Remove"
} catch {
    Write-Warning $_.Exception.Message
    if ($id) {
        try { Invoke-Bcd @('/delete', $id) | Write-Host; Write-Warning 'Incomplete new entry removed.' }
        catch { Write-Warning "Automatic rollback failed for $id. Check BCD manually: $_" }
    }
    throw
}
