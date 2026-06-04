####################################################################################################
# Skript vyhleda vsechny synchronizovane uzivatele z Active Directory
# Skript overi, zda se uzivatel uspesne prihlasil do prostredi (neuspesne prihlaseni se nepocita)
# Autor: frantisek.kurec@microsoft.com
####################################################################################################

connect-mggraph -scopes User.Read.All,AuditLog.Read.All, UserAuthenticationMethod.Read.All

$LogPathSigned = "C:\Scripts\users_Signed.log"
$LogPathNotSigned = "C:\Scripts\users_NotSigned.log"


$AllSynced = Get-MgUser -All -Filter "onPremisesSyncEnabled eq true" -property signInActivity,onPremisesSyncEnabled, Id, DisplayName, userPrincipalName
Get-Date
Write-host "Celkem uzivatelu: " $AllSynced.Count
Write-Host "Zpracovavam informace do logu: $LogPathSigned a $LogPathNotSigned"

$yesCounter = 0
$notCounter = 0
Foreach ($usr in $AllSynced){

    if ($usr.signInActivity.lastSuccessfulSignInDateTime){
        
            #Write-host $usr.userPrincipalName -ForegroundColor Green
            Add-Content -Path $LogPathSigned -Value $usr.userPrincipalName
            Add-Content -Path $LogPathSigned -Value $usr.signInActivity.lastSuccessfulSignInDateTime
            $UsrMethods=Get-MgUserAuthenticationMethod -UserId $usr.Id
            Add-Content -Path $LogPathSigned -Value $UsrMethods.additionalProperties.'@odata.type'
            Add-Content -Path $LogPathSigned -Value "----------------------------------------------"
            $yesCounter ++
            #Write-host "----------------------------------------------"
        }

        else {
        
            #Write-host $usr.userPrincipalName -ForegroundColor Red
            $notCounter ++
            Add-Content -Path $LogPathNotSigned -Value $usr.userPrincipalName
        }

}
Write-host " ------------------------------------------------------"
Write-host "Celkem synchronizovanych uzivatelu:" $AllSynced.Count
Write-host "Prihlasenych = $yesCounter" -ForegroundColor Green
Write-host "Nerihlasenych = $notCounter" -ForegroundColor Red
Get-Date

# Test pro jednoho uzivatele
# $objectId="e1a5cba8-c860-4b1e-92fc-b6e035738e4c"
# $on=Get-MgUser -UserId $objectId -Property "signInActivity"
# if ($on.signInActivity.lastSuccessfulSignInDateTime){"YES"} else {"NO"}




