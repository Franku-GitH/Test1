$User = "uzivatel@domena.local"
$DCs = @("DC1","DC2","DC3")  # Zde doplň názvy nebo IP adresy DC
$OutputDC = "C:\Logs\RDP_DCs_$($User)_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"

$Results = foreach ($DC in $DCs) {
    Get-WinEvent -ComputerName $DC -FilterHashtable @{LogName='Security'; ID=4768,4769,4771,4820,4821,4822,4823,4964} |
    Where-Object { $_.Message -like "*$User*" } |
    Select-Object TimeCreated, Id, @{Name='DomainController';Expression={$DC}}, Message
}

$Results | Sort-Object TimeCreated -Descending | Export-Csv -Path $OutputDC -NoTypeInformation

Write-Host "Export dokončen: $OutputDC"XeXeT0p-202