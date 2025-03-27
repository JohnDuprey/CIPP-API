function Get-NinjaOnePSAForms {
    [CmdletBinding()]
    param()

    $Table = Get-CIPPTable -TableName Extensionsconfig
    $Configuration = ((Get-AzDataTableEntity @Table).config | ConvertFrom-Json -ea stop).NinjaOne

    $Token = Get-NinjaOneToken -configuration $Configuration
    $After = 0
    $PageSize = 1000
    $NinjaPSAForms = do {
        $Result = (Invoke-WebRequest -Uri "https://$($Configuration.Instance)/api/v2/ticketing/ticket-form?pageSize=$PageSize&after=$After" -Method GET -Headers @{Authorization = "Bearer $($token.access_token)" } -ContentType 'application/json').content | ConvertFrom-Json -Depth 100
        $Result | Select-Object name, @{n = 'value'; e = { $_.id } }
        $ResultCount = ($Result.id | Measure-Object -Maximum)
        $After = $ResultCount.maximum

    } while ($ResultCount.count -eq $PageSize)
    @($NinjaPSAForms)
}
