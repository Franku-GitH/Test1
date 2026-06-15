####################################################################################################
# Skript vyhleda vsechny synchronizovane uzivatele z Active Directory
# Overi prihlaseni (poslednich ~30 dni)
# Export do CSV:
#   Signed: UPN, FirstLogin, LastPasswordChange, MFA1-10
#   NotSigned: UPN
####################################################################################################

# CONNECT
Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, UserAuthenticationMethod.Read.All -NoWelcome

# PATHS
$LogPathSigned = "C:\Scripts\users_Signed.csv"
$LogPathNotSigned = "C:\Scripts\users_NotSigned.csv"

# USERS
$AllSynced = Get-MgUser -All -Filter "onPremisesSyncEnabled eq true" `
    -Property Id,UserPrincipalName,DisplayName,lastPasswordChangeDateTime

Get-Date
Write-Host "Celkem uzivatelu:" $AllSynced.Count

# ARRAYS
$SignedUsersOutput = @()
$NotSignedUsersOutput = @()

####################################################################################################
# LOGIN EVALUATION
####################################################################################################

foreach ($user in $AllSynced) {

    try {
        $logins = Get-MgAuditLogSignIn `
            -Filter "userId eq '$($user.Id)' and status/errorCode eq 0" `
            -Top 50

        if ($logins) {

            $FirstLogin = ($logins | Sort-Object createdDateTime | Select-Object -First 1).createdDateTime

            ####################################################################################################
            # MFA METHODS
            ####################################################################################################

            try {
                $methods = Get-MgUserAuthenticationMethod -UserId $user.Id

                $methodTypes = $methods | ForEach-Object {
                    $_.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', ''
                }
            }
            catch {
                $methodTypes = @("ERROR")
            }

            # fixni max 10 sloupcu
            $mfaColumns = @()
            for ($i = 0; $i -lt 10; $i++) {
                if ($i -lt $methodTypes.Count) {
                    $mfaColumns += $methodTypes[$i]
                }
                else {
                    $mfaColumns += $null
                }
            }

            $SignedUsersOutput += [PSCustomObject]@{
                UPN = $user.UserPrincipalName
                FirstLogin = $FirstLogin
                LastPasswordChange = $user.lastPasswordChangeDateTime
                MFA1 = $mfaColumns[0]
                MFA2 = $mfaColumns[1]
                MFA3 = $mfaColumns[2]
                MFA4 = $mfaColumns[3]
                MFA5 = $mfaColumns[4]
                MFA6 = $mfaColumns[5]
                MFA7 = $mfaColumns[6]
                MFA8 = $mfaColumns[7]
                MFA9 = $mfaColumns[8]
                MFA10 = $mfaColumns[9]
            }

        }
        else {
            $NotSignedUsersOutput += [PSCustomObject]@{
                UPN = $user.UserPrincipalName
            }
        }
    }
    catch {
        $NotSignedUsersOutput += [PSCustomObject]@{
            UPN = $user.UserPrincipalName
        }
    }
}

####################################################################################################
# EXPORT CSV
####################################################################################################

$SignedUsersOutput | Export-Csv -Path $LogPathSigned -NoTypeInformation -Encoding UTF8
$NotSignedUsersOutput | Export-Csv -Path $LogPathNotSigned -NoTypeInformation -Encoding UTF8

####################################################################################################
# STATS
####################################################################################################

Write-Host "------------------------------------------------------"
Write-Host "Celkem synchronizovanych uzivatelu:" $AllSynced.Count
Write-Host "Prihlasenych = $($SignedUsersOutput.Count)" -ForegroundColor Green
Write-Host "Neprihlasenych = $($NotSignedUsersOutput.Count)" -ForegroundColor Red
Get-Date