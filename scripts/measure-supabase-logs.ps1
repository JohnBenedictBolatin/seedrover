[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9]{20}$')][string]$ProjectRef = 'jnjezklorvdhwbjtbjsg',
    [ValidateRange(1,24)][int]$Hours = 24,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $OutputPath) { $OutputPath = Join-Path $scriptDirectory '../tmp/supabase-log-budget/log-summary.json' }
. (Join-Path $scriptDirectory 'supabase-management.ps1')
$end = [DateTime]::UtcNow
$start = $end.AddHours(-$Hours)
# Return aggregates only; raw log messages can contain application/user data.
$sql = @'
select source, count() as events,
sum(length(event_message)) as message_bytes,
sum(length(toJSONString(log_attributes))) as attribute_json_bytes,
countIf(upper(severity_text) in ('ERROR','FATAL','PANIC')) as error_events,
countIf(toInt32OrZero(log_attributes['response.status_code']) >= 400) as failed_http_events
from logs group by source order by events desc limit 30
'@
$path = '/v1/projects/' + $ProjectRef + '/analytics/endpoints/logs?sql=' + [Uri]::EscapeDataString($sql) +
    '&iso_timestamp_start=' + [Uri]::EscapeDataString($start.ToString('o')) +
    '&iso_timestamp_end=' + [Uri]::EscapeDataString($end.ToString('o'))
$response = Invoke-SeedRoverSupabaseRead -Path $path
if ($response.error) { throw ('Log query failed: ' + $response.error) }
$report = [ordered]@{
    project_ref = $ProjectRef
    start_utc = $start.ToString('o')
    end_utc = $end.ToString('o')
    note = 'Diagnostic counts and serialized field sizes, not billable ingestion. Use the organization Usage meter for the budget.'
    sources = @($response.result)
}
$absolutePath = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($absolutePath)) | Out-Null
$json = $report | ConvertTo-Json -Depth 8 -Compress
Add-Content -LiteralPath ($absolutePath + 'l') -Value $json -Encoding UTF8
$report | ConvertTo-Json -Depth 8
