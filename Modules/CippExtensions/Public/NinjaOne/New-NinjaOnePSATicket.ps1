function New-NinjaOnePSATicket {
    [CmdletBinding()]
    param (
        [string]$Title,
        [string]$Description,
        [string]$Client
    )

    $Table = Get-CIPPTable -TableName Extensionsconfig
    $Configuration = ((Get-AzDataTableEntity @Table).config | ConvertFrom-Json -ea stop).NinjaOne
    $TicketTable = Get-CIPPTable -TableName 'PSATickets'
    $TitleHash = Get-StringHash -String $Title

    if ($Configuration.Enabled -eq $false -or $Configuration.PSAEnabled -eq $false) {
        Write-Information 'NinjaOne PSA integration is disabled'
        return $false
    }

    $Token = Get-NinjaOneToken -Configuration $Configuration

    if ($Configuration.ConsolidateTickets) {
        $ExistingTicket = Get-CIPPAzDataTableEntity @TicketTable -Filter "PartitionKey eq 'NinjaOne' and RowKey eq '$($Client)-$($TitleHash)'"
        if ($ExistingTicket) {
            Write-Information "Ticket already exists in NinjaOne: $($ExistingTicket.TicketID)"

            $Ticket = Invoke-RestMethod -Uri "https://$($Configuration.Instance)/api/v2/ticketing/ticket/$($ExistingTicket.TicketID)" -Method Get -Headers @{Authorization = "Bearer $($Token.access_token)" }
            Write-Information "Ticket status: $($Ticket.status)"
            if ($Ticket.status.displayName -notin @('Closed', 'Resolved')) {
                Write-Information 'Ticket is still open, adding new comment'

                $FormData = @{
                    'comment.public'               = 'true'
                    'comment.htmlBody'             = $Description
                    'comment.timeTracked'          = ''
                    'comment.duplicateInIncidents' = 'false'
                }

                try {
                    Invoke-RestMethod -Uri "https://$($Configuration.Instance)/api/v2/ticketing/ticket/$($ExistingTicket.TicketID)/comment" -Method Post -Form $FormData -Headers @{Authorization = "Bearer $($Token.access_token)" }
                    Write-Information "Comment added to ticket in NinjaOne: $($ExistingTicket.TicketID)"
                    return
                } catch {
                    Write-LogMessage -message "Failed to add comment to NinjaOne ticket: $($_.Exception.Message)" -API 'NinjaOnePSATicket' -sev Error -LogData (Get-CippException -Exception $_)
                    Write-Information "Failed to add comment to NinjaOne ticket: $($_.Exception.Message)"
                }
            }
        }
    }

    Write-Information "Creating new ticket in NinjaOne for $Client"
    $Body = @{
        clientId     = $Client
        ticketFormId = $Configuration.PSATicketForm.value ?? 1
        subject      = $Title
        description  = @{
            public               = $true
            htmlBody             = $Description
            duplicateInIncidents = $true
        }
        status       = '1000'
        type         = 'PROBLEM'
    }

    $Headers = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer $($Token.access_token)"
    }

    Write-Information ($Headers | ConvertTo-Json -Depth 5)
    try {
        $Result = New-GraphPOSTRequest -Uri "https://$($Configuration.Instance)/api/v2/ticketing/ticket" -Body ($Body | ConvertTo-Json -Depth 5) -Headers $Headers -NoAuthCheck $true
        if ($Result) {
            Write-Host "Ticket created for $Client"

            if ($Configuration.ConsolidateTickets) {
                $TicketObject = [PSCustomObject]@{
                    PartitionKey = 'NinjaOne'
                    RowKey       = "$($Client)-$($TitleHash)"
                    Title        = $Title
                    ClientId     = $Client
                    TicketID     = $Result.id
                }
                Add-CIPPAzDataTableEntity @TicketTable -Entity $TicketObject -Force
                Write-Information 'Ticket added to consolidation table'
            }
        }
        return $Result
    } catch {
        Write-LogMessage -message "Failed to create ticket in NinjaOne: $($_.Exception.Message)" -API 'NinjaOnePSATicket' -sev Error -LogData (Get-CippException -Exception $_)
        Write-Information "Failed to create ticket in NinjaOne: $($_.Exception.Message)"
    }
}
