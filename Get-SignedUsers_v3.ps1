####################################################################################################
# Skript vyhleda vsechny synchronizovane uzivatele z Active Directory
# Skript overi, zda se uzivatel uspesne prihlasil do prostredi (neuspesne prihlaseni se nepocita)
# Autor: frantisek.kurec@microsoft.com
####################################################################################################
Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, UserAuthenticationMethod.Read.All -NoWelcome

$LogPathSigned = "C:\Scripts\users_Signed.log"
$LogPathNotSigned = "C:\Scripts\users_NotSigned.log"

$AllSynced = Get-MgUser -All -Filter "onPremisesSyncEnabled eq true" -Property Id,UserPrincipalName,DisplayName

$Now = Get-Date
$Threshold = $Now.AddDays(-30)

Get-Date
Write-Host "Celkem uzivatelu:" $AllSynced.Count

# Rozdeleni uzivatelu
$Evaluation = $AllSynced | ForEach-Object -Parallel {

    $logins = Get-MgAuditLogSignIn -Filter "userId eq '$($_.Id)'" -All

    if (-not $logins) {

        [PSCustomObject]@{
            UserPrincipalName = $_.UserPrincipalName
            State = "NeverSigned"
            FirstLogin = $null
            LastLogin = $null
        }

    } else {

        $FirstLogin = ($logins | Sort-Object createdDateTime | Select-Object -First 1).createdDateTime
        $LastLogin = ($logins | Sort-Object createdDateTime -Descending | Select-Object -First 1).createdDateTime

        if ($LastLogin -lt $using:Threshold) {

            [PSCustomObject]@{
                UserPrincipalName = $_.UserPrincipalName
                State = "Inactive>30d"
                FirstLogin = $FirstLogin
                LastLogin = $LastLogin
            }

        } else {

            [PSCustomObject]@{
                UserPrincipalName = $_.UserPrincipalName
                State = "Active"
                FirstLogin = $FirstLogin
                LastLogin = $LastLogin
            }

        }
    }

} -ThrottleLimit 10

# Rozdeleni
$NotSignedUsers = $Evaluation | Where-Object { $_.State -eq "NeverSigned" }
$SignedUsers = $Evaluation | Where-Object { $_.State -ne "NeverSigned" }

# NOT signed
$NotSignedOutput = $NotSignedUsers.UserPrincipalName

# SIGNED + MFA
$SignedResults = $SignedUsers | ForEach-Object -Parallel {

    try {
        $methods = Get-MgUserAuthenticationMethod -UserId $_.UserPrincipalName

        $methodTypes = $methods | ForEach-Object {
            $_.AdditionalProperties.'@odata.type'
        }

        @(
            $_.UserPrincipalName
            $_.State
            $_.FirstLogin
            $_.LastLogin
            ($methodTypes -join ",")
            "----------------------------------------------"
        )
    }
    catch {
        @(
            $_.UserPrincipalName
            $_.State
            $_.FirstLogin
            $_.LastLogin
            "ERROR retrieving methods"
            "----------------------------------------------"
        )
    }

} -ThrottleLimit 10

$SignedOutput = $SignedResults | ForEach-Object { $_ }

$SignedOutput | Set-Content $LogPathSigned
$NotSignedOutput | Set-Content $LogPathNotSigned

# Statistiky
Write-Host "------------------------------------------------------"
Write-Host "Celkem synchronizovanych uzivatelu:" $AllSynced.Count
Write-Host "Prihlasenych = $($SignedUsers.Count)" -ForegroundColor Green
Write-Host "Neprihlasenych = $($NotSignedUsers.Count)" -ForegroundColor Red
Get-Date