function Invoke-ListApiTest {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Core.Read
    .LINK
        GET /v1.0/api-test
    .LINK
        POST /v1.0/api-test
    .LINK
        DELETE /v1.0/api-test-delete
    .LINK
        PATCH /v1.0/api-test
    .LINK
        PUT /v1.0/api-test
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    Write-LogMessage -headers $Headers -API $APIName -message 'Accessed this API' -Sev 'Debug'

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = ($Request | ConvertTo-Json -Depth 5)
        })
}
