﻿####################################################################################################
# Skript vyhleda vsechny synchronizovane uzivatele z Active Directory
# Skript overi, zda se uzivatel uspesne prihlasil do prostredi (neuspesne prihlaseni se nepocita)
# Autor: frantisek.kurec@microsoft.com
####################################################################################################

Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, UserAuthenticationMethod.Read.All -NoWelcome

$LogPathSigned = "C:\Scripts\users_Signed.log"
$LogPathNotSigned = "C:\Scripts\users_NotSigned.log"

$AllSynced = Get-MgUser -All -Filter "onPremisesSyncEnabled eq true" -Property Id,UserPrincipalName,DisplayName,SignInActivity

Get-Date
Write-Host "Celkem uzivatelu:" $AllSynced.Count

# Rozdeleni uzivatelu
$SignedUsers = $AllSynced | Where-Object { $_.SignInActivity.LastSuccessfulSignInDateTime }
$NotSignedUsers = $AllSynced | Where-Object { -not $_.SignInActivity.LastSuccessfulSignInDateTime }

# NOT signed seznam UPN uzivatelu 
$NotSignedOutput = $NotSignedUsers.UserPrincipalName

# SIGNED seznam uzivatelu zpracovani MFA
$SignedResults = $SignedUsers | ForEach-Object -Parallel {

    try {
        $methods = Get-MgUserAuthenticationMethod -UserId $_.Id

        $methodTypes = $methods | ForEach-Object {
            $_.AdditionalProperties.'@odata.type'
        }

        # format vystupu 
        @(
            $_.UserPrincipalName
            $_.SignInActivity.LastSuccessfulSignInDateTime
            ($methodTypes -join ",")
            "----------------------------------------------"
        )
    }
    catch {
        @(
            $_.UserPrincipalName
            $_.SignInActivity.LastSuccessfulSignInDateTime
            "ERROR retrieving methods"
            "----------------------------------------------"
        )
    }

} -ThrottleLimit 10 # Throttle kvuli Azure blokaci/zpomalovani

# Flatten (puvodne pole)
$SignedOutput = $SignedResults | ForEach-Object { $_ }

# zapis vystupu
$SignedOutput | Set-Content $LogPathSigned
$NotSignedOutput | Set-Content $LogPathNotSigned

# Statistiky
Write-Host "------------------------------------------------------"
Write-Host "Celkem synchronizovanych uzivatelu:" $AllSynced.Count
Write-Host "Prihlasenych = $($SignedUsers.Count)" -ForegroundColor Green
Write-Host "Neprihlasenych = $($NotSignedUsers.Count)" -ForegroundColor Red
Get-Date