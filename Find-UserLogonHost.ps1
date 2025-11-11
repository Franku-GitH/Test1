# Find Logon events for a user connecting to a server

$User = "uzivatel@domena.local"
$OutputServer = "C:\Logs\RDP_Server_$($User)_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"

Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625,4624,4776} |
Where-Object { $_.Message -like "*$User*" } |
Select-Object TimeCreated, Id, @{Name='Computer';Expression={$_.MachineName}}, Message |
Sort-Object TimeCreated -Descending |
Export-Csv -Path $OutputServer -NoTypeInformation

Write-Host "Export dokončen: $OutputServer"
