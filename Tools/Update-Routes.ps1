
Import-Module .\Modules\CIPPCore

$Functions = Get-Command -Module CIPPCore | Where-Object { $_.Visibility -eq 'Public' }
$Results = foreach ($Function in $Functions) {
    $GetHelp = @{
        Name = $Function
    }
    $Help = Get-Help @GetHelp
    if ($Help.RelatedLinks -and $Help.Functionality -eq 'Entrypoint' -and $Help.relatedLinks.navigationLink.linkText) {
        foreach ($LinkText in $Help.RelatedLinks.navigationLink.linkText) {
            if ($LinkText -match '^(?<Method>[A-Z]+) (?<Path>.+)$') {
                $Path = $Matches.Path
                $Method = $Matches.Method
                [PSCustomObject]@{
                    uri    = $Path
                    name   = $Function.Name
                    method = $Method
                }
            }
        }
    }
}
$Results = $Results | Group-Object -Property uri, name | ForEach-Object {
    [PSCustomObject]@{
        uri     = $_.Group[0].uri
        name    = $_.Group[0].name
        methods = @($_.Group.method)
    }
}
$Results
ConvertTo-Json -InputObject @($Results) | Out-File -FilePath api-routes.json -Force
