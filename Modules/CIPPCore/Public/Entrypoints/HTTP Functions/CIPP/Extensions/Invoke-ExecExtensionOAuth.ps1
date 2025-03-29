function Invoke-ExecExtensionOAuth {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Extension.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    Write-LogMessage -headers $Headers -API $APIName -message 'Accessed this API' -Sev 'Debug'

    $Extension = $Request.Query.Extension
    $Code = $Request.Query.code

    $Table = Get-CIPPTable -TableName Extensionsconfig
    $Configuration = (Get-CIPPAzDataTableEntity @Table).config | ConvertFrom-Json -Depth 10

    try {
        switch ($Extension) {
            'NinjaOne' {
                $NinjaConfig = $Configuration.NinjaOne
                $APIKey = Get-ExtensionAPIKey -Extension $Extension
                $Token = Invoke-RestMethod -Uri "https://$($NinjaConfig.Instance)/oauth/token" -Method Post -Body @{
                    client_id     = $NinjaConfig.ClientID
                    client_secret = $APIKey
                    code          = $Code
                    grant_type    = 'authorization_code'
                    redirect_uri  = $NinjaConfig.RedirectURI
                }

                $RefreshToken = $Token.refresh_token

                Set-ExtensionRefreshToken -Extension $Extension -RefreshToken $RefreshToken
                $ResponseBody = @{
                    status  = "success"
                    message = "OAuth code processed successfully."
                }
            }
            default {
                throw "Unsupported extension: $Extension"
            }
        }
    } catch {
        $ResponseBody = @{
            status  = "error"
            message = $_.Exception.Message
        }
    }

    # Use Push-OutputBinding to return the response
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $ResponseBody | ConvertTo-Json -Depth 10
    })
}
