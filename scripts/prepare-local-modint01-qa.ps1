[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][ValidateSet('Prepare', 'Restore')][string]$Action,
  [Parameter(Mandatory)][string]$BackupDirectory
)
$ErrorActionPreference = 'Stop'
$taskRepository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskConfigPath = Join-Path $taskRepository 'supabase/config.toml'
$taskOriginalPath = Join-Path ([IO.Path]::GetFullPath($BackupDirectory)) 'config.toml'
$taskProject = 'planets-community-modint01-qa'
$taskBranch = git -C $taskRepository branch --show-current
if ($LASTEXITCODE -ne 0 -or $taskBranch -ne 'codex/modint01-moderation-auth-integration') {
  throw 'Use the existing MODINT01 branch/worktree, not another checkout.'
}
if (-not (Test-Path -LiteralPath $taskOriginalPath -PathType Leaf)) {
  throw "Canonical config backup missing: $taskOriginalPath. Back up the clean committed config before preparing."
}
$taskOriginal = [IO.File]::ReadAllText($taskOriginalPath)
if ($taskOriginal -notmatch '(?m)^project_id = "planets-community"\r?$') {
  throw 'Backup must contain the original canonical project, never another task configuration.'
}
$taskPrepared = $taskOriginal.Replace('project_id = "planets-community"', 'project_id = "planets-community-modint01-qa"')
$taskPorts = @{54321=54611;54322=54612;54320=54610;54329=54619;54323=54613;54324=54614;54327=54617;8083=8123}
foreach ($taskPort in $taskPorts.Keys) {
  if ($taskPrepared -notmatch "= $taskPort\b") { throw "Expected config port $taskPort missing; inspect config drift." }
  $taskPrepared = $taskPrepared -replace "= $taskPort\b", ("= " + $taskPorts[$taskPort])
}
$taskCurrent = [IO.File]::ReadAllText($taskConfigPath)
$taskNormalize = { param($value) ([regex]::Replace($value, '\r\n', [string][char]10)).TrimEnd() }
if ((& $taskNormalize $taskCurrent) -ne (& $taskNormalize $taskOriginal) -and
    (& $taskNormalize $taskCurrent) -ne (& $taskNormalize $taskPrepared)) {
  throw 'Configuration has unrelated changes; nothing was overwritten.'
}
if ($Action -eq 'Prepare') {
  if ($PSCmdlet.ShouldProcess($taskConfigPath, 'Prepare only MODINT01 project/ports from the retained canonical backup')) {
    [IO.File]::WriteAllText($taskConfigPath, $taskPrepared, [Text.UTF8Encoding]::new($false))
  }
  Write-Output 'MODINT01 configuration: API 54611 / DB 54612 / Mailpit 54614. No services started or data reset.'
} else {
  $taskRunningNames = docker ps --format '{{.Names}}'
  if ($LASTEXITCODE -ne 0) { throw 'Cannot establish Docker state; do not restore a live task config.' }
  if ($taskRunningNames | Where-Object { $_.EndsWith('_' + $taskProject) }) {
    throw 'Stop only the MODINT01 stack with its task config still selected, retaining normal backups, before Restore.'
  }
  if ($PSCmdlet.ShouldProcess($taskConfigPath, 'Restore exact canonical config bytes from the retained backup')) {
    Copy-Item -LiteralPath $taskOriginalPath -Destination $taskConfigPath
    if ((Get-FileHash -LiteralPath $taskConfigPath).Hash -ne (Get-FileHash -LiteralPath $taskOriginalPath).Hash) {
      throw 'Restored config hash differs from the canonical backup.'
    }
  }
  Write-Output 'Canonical config restoration checked; no other checkout/backend was touched.'
}
