function Set-ExtensionRefreshToken {
    <#
    .FUNCTIONALITY
        Internal
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Scope = 'Function')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Extension,
        [Parameter(Mandatory = $true)]
        [string]$RefreshToken
    )

    if ($PSCmdlet.ShouldProcess('API Key', "Set API Key for $Extension")) {
        $Var = "Ext_$Extension"
        $Name = '{0}_RefreshToken' -f $Extension
        if ($env:AzureWebJobsStorage -eq 'UseDevelopmentStorage=true') {
            $DevSecretsTable = Get-CIPPTable -tablename 'DevSecrets'
            $Secret = [PSCustomObject]@{
                'PartitionKey' = $Extension
                'RowKey'       = $Name
                'RefreshToken' = $RefreshToken
            }
            Add-CIPPAzDataTableEntity @DevSecretsTable -Entity $Secret -Force
        } else {
            $keyvaultname = ($ENV:WEBSITE_DEPLOYMENT_ID -split '-')[0]
            $null = Connect-AzAccount -Identity
            $SubscriptionId = $ENV:WEBSITE_OWNER_NAME -split '\+' | Select-Object -First 1
            $null = Set-AzContext -SubscriptionId $SubscriptionId
            $null = Set-AzKeyVaultSecret -VaultName $keyvaultname -Name $Name -SecretValue (ConvertTo-SecureString -AsPlainText -Force -String $RefreshToken)
        }
        Set-Item -Path "ENV:$Var" -Value $RefreshToken -Force -ErrorAction SilentlyContinue
    }
    return $true
}
