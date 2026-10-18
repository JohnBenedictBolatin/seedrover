[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(0,1000000)][double]$UsedGb,
    [datetime]$ResetDate = [datetime]::new(2026, 10, 30),
    [double]$IncludedGb = 1.0,
    [double]$ReserveMb = 20.0,
    [double]$TargetDailyMb = 25.0,
    [string]$CsvPath
)
$ErrorActionPreference = 'Stop'
$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $CsvPath) { $CsvPath = Join-Path $scriptDirectory '../docs/automation/supabase-log-ingestion.csv' }
$now = ([DateTimeOffset]::UtcNow).ToOffset([TimeSpan]::FromHours(8))
$day = $now.Date.ToString('yyyy-MM-dd')
$resetDay = $ResetDate.Date.ToString('yyyy-MM-dd')
$remainingMb = [math]::Round([math]::Max(0, ($IncludedGb - $UsedGb) * 1000), 2)
$daysUntilReset = [math]::Max(1, [math]::Ceiling(($ResetDate.Date - $now.Date).TotalDays))
$remainingBudgetMb = [math]::Max(0, $remainingMb - $ReserveMb) / $daysUntilReset
$dailyBudgetMb = [math]::Round([math]::Min($TargetDailyMb, $remainingBudgetMb), 2)
$absolutePath = [IO.Path]::GetFullPath($CsvPath)
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($absolutePath)) | Out-Null
$history = if (Test-Path -LiteralPath $absolutePath) {
    @(Import-Csv -LiteralPath $absolutePath)
} else { @() }
$latest = $history | Where-Object { $_.reset_date -eq $resetDay } | Select-Object -Last 1
$dailyIncreaseMb = ''
if ($latest) {
    $elapsedDays = ([datetime]$day - [datetime]$latest.recorded_date).TotalDays
    if ($elapsedDays -ge 1) {
        $dailyIncreaseMb = [math]::Round([math]::Max(0, ($UsedGb - [double]$latest.used_gb) * 1000) / $elapsedDays, 2)
    }
}
$row = [pscustomobject][ordered]@{
    recorded_date = $day
    reset_date = $resetDay
    used_gb = $UsedGb
    remaining_mb = $remainingMb
    observed_daily_increase_mb = $dailyIncreaseMb
    safe_daily_budget_mb = $dailyBudgetMb
    reserve_mb = $ReserveMb
    days_until_reset = $daysUntilReset
}
$append = @($row | ConvertTo-Csv -NoTypeInformation) | Select-Object -Last 1
if (Test-Path -LiteralPath $absolutePath) {
    Add-Content -LiteralPath $absolutePath -Value $append -Encoding UTF8
} else {
    @($row | ConvertTo-Csv -NoTypeInformation) | Set-Content -LiteralPath $absolutePath -Encoding UTF8
}
$row | Format-List
if ($dailyIncreaseMb -ne '' -and [double]$dailyIncreaseMb -gt $dailyBudgetMb) {
    Write-Warning "Observed log ingestion of $dailyIncreaseMb MB per day is over the $dailyBudgetMb MB safe daily budget. Review source counts with scripts/measure-supabase-logs.ps1."
}
