####################################################################################################
# Skript vyhleda vsechny synchronizovane uzivatele z Active Directory
# Skript overi, zda se uzivatel uspesne prihlasil do prostredi podle IdentityLogonEvents v Sentinel/Log Analytics
# Autor: 
####################################################################################################

# Microsoft Graph - pouze pro seznam synchronizovanych uzivatelu a MFA metody
Connect-MgGraph -Scopes "User.Read.All","UserAuthenticationMethod.Read.All" -NoWelcome

# Azure / Log Analytics
Connect-AzAccount

# Log Analytics Workspace ID
$WorkspaceId = "<LOG_ANALYTICS_WORKSPACE_ID>"

# Log soubory
$LogPathSigned = "C:\Scripts\users_Signed.log"
$LogPathNotSigned = "C:\Scripts\users_NotSigned.log"

# Ziskani vsech synchronizovanych uzivatelu
$AllSynced = Get-MgUser -All -Filter "onPremisesSyncEnabled eq true" -Property Id,UserPrincipalName,DisplayName

Get-Date
Write-Host "Celkem uzivatelu:" $AllSynced.Count

####################################################################################################
# KQL - prvni uspesne prihlaseni z IdentityLogonEvents
####################################################################################################

$KqlQuery = @"
IdentityLogonEvents
| where ActionType == "LogonSuccess"
| where isnotempty(AccountObjectId)
| summarize FirstLogin = min(Timestamp) by AccountObjectId, AccountUpn
| project ObjectId = tostring(AccountObjectId), UserPrincipalName = AccountUpn, FirstLogin
"@

$QueryResult = Invoke-AzOperationalInsightsQuery `
    -WorkspaceId $WorkspaceId `
    -Query $KqlQuery `
    -Timespan (New-TimeSpan -Days 365)

# Vynuceni nacteni vysledku do pameti
$LoginRows = @($QueryResult.Results)

# Hashtable pro rychle lookup podle ObjectId
$LoginByObjectId = @{}

foreach ($row in $LoginRows) {
    if ($row.ObjectId) {
        $key = $row.ObjectId.ToString().ToLower()
        $LoginByObjectId[$key] = $row
    }
}

####################################################################################################
# Rozdeleni uzivatelu - bez parallel/throttle
####################################################################################################

$SignedUsers = @()
$NotSignedUsers = @()

foreach ($user in $AllSynced) {

    $userId = $user.Id.ToString().ToLower()

    if ($LoginByObjectId.ContainsKey($userId)) {

        $loginInfo = $LoginByObjectId[$userId]

        $SignedUsers += [PSCustomObject]@{
            Id                = $user.Id
            UserPrincipalName = $user.UserPrincipalName
            DisplayName       = $user.DisplayName
            FirstLogin        = $loginInfo.FirstLogin
        }
    }
    else {

        $NotSignedUsers += [PSCustomObject]@{
            Id                = $user.Id
            UserPrincipalName = $user.UserPrincipalName
            DisplayName       = $user.DisplayName
            FirstLogin        = $null
        }
    }
}

####################################################################################################
# NOT signed seznam UPN uzivatelu
####################################################################################################

$NotSignedOutput = $NotSignedUsers | ForEach-Object {
    $_.UserPrincipalName
}

####################################################################################################
# SIGNED seznam uzivatelu + MFA metody - sekvencne, bez parallel
####################################################################################################

$SignedOutput = @()

foreach ($signedUser in $SignedUsers) {

    try {
        $methods = Get-MgUserAuthenticationMethod -UserId $signedUser.Id

        $methodTypes = $methods | ForEach-Object {
            $_.AdditionalProperties.'@odata.type'
        }

        $SignedOutput += $signedUser.UserPrincipalName
        $SignedOutput += $signedUser.FirstLogin
        $SignedOutput += ($methodTypes -join ",")
        $SignedOutput += "----------------------------------------------"
    }
    catch {
        $SignedOutput += $signedUser.UserPrincipalName
        $SignedOutput += $signedUser.FirstLogin
        $SignedOutput += "ERROR retrieving methods"
        $SignedOutput += "----------------------------------------------"
    }
}

####################################################################################################
# Zapis vystupu
####################################################################################################

$SignedOutput | Set-Content $LogPathSigned
$NotSignedOutput | Set-Content $LogPathNotSigned

####################################################################################################
# Statistiky
####################################################################################################

Write-Host "------------------------------------------------------"
Write-Host "Celkem synchronizovanych uzivatelu:" $AllSynced.Count
Write-Host "Prihlasenych = $($SignedUsers.Count)" -ForegroundColor Green
Write-Host "Neprihlasenych = $($NotSignedUsers.Count)" -ForegroundColor Red
Get-Date