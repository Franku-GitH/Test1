####################################################################################################
# Skript vyhleda vsechny synchronizovane uzivatele z Active Directory
# Skript overi prihlaseni a exportuje do CSV
####################################################################################################

Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, UserAuthenticationMethod.Read.All -NoWelcome

# změna na CSV
$LogPathSigned = "C:\Scripts\users_Signed.csv"
$LogPathNotSigned = "C:\Scripts\users_NotSigned.csv"

# přidán lastPasswordChangeDateTime ✅
$AllSynced = Get-MgUser -All -Filter "onPremisesSyncEnabled eq true" `
    -Property Id,UserPrincipalName,DisplayName,SignInActivity,lastPasswordChangeDateTime

Get-Date
Write-Host "Celkem uzivatelu:" $AllSynced.Count

# Rozdeleni uzivatelu
$SignedUsers = $AllSynced | Where-Object { $_.SignInActivity.LastSuccessfulSignInDateTime }
$NotSignedUsers = $AllSynced | Where-Object { -not $_.SignInActivity.LastSuccessfulSignInDateTime }

####################################################################################################
# NOT SIGNED → CSV (UPN + LastPasswordChange)
####################################################################################################

$NotSignedOutput = $NotSignedUsers | Select-Object `
    @{Name="UPN";Expression={$_.UserPrincipalName}},
    @{Name="LastPasswordChange";Expression={$_.lastPasswordChangeDateTime}}

####################################################################################################
# SIGNED → CSV (UPN, LastSignIn, LastPasswordChange, MFA1-10)
####################################################################################################

$SignedOutput = $SignedUsers | ForEach-Object -Parallel {

    try {
        $methods = Get-MgUserAuthenticationMethod -UserId $_.Id

        $methodTypes = $methods | ForEach-Object {
            $_.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', ''
        }

        # fixni max 10 MFA
        $mfa = @()
        for ($i = 0; $i -lt 10; $i++) {
            if ($i -lt $methodTypes.Count) {
                $mfa += $methodTypes[$i]
            } else {
                $mfa += $null
            }
        }

        [PSCustomObject]@{
            UPN = $_.UserPrincipalName
            LastSignIn = $_.SignInActivity.LastSuccessfulSignInDateTime
            LastPasswordChange = $_.lastPasswordChangeDateTime
            MFA1 = $mfa[0]
            MFA2 = $mfa[1]
            MFA3 = $mfa[2]
            MFA4 = $mfa[3]
            MFA5 = $mfa[4]
            MFA6 = $mfa[5]
            MFA7 = $mfa[6]
            MFA8 = $mfa[7]
            MFA9 = $mfa[8]
            MFA10 = $mfa[9]
        }
    }
    catch {
        [PSCustomObject]@{
            UPN = $_.UserPrincipalName
            LastSignIn = $_.SignInActivity.LastSuccessfulSignInDateTime
            LastPasswordChange = $_.lastPasswordChangeDateTime
            MFA1 = "ERROR"
            MFA2 = $null
            MFA3 = $null
            MFA4 = $null
            MFA5 = $null
            MFA6 = $null
            MFA7 = $null
            MFA8 = $null
            MFA9 = $null
            MFA10 = $null
        }
    }

} -ThrottleLimit 10

####################################################################################################
# EXPORT CSV
####################################################################################################

$SignedOutput | Export-Csv $LogPathSigned -NoTypeInformation -Encoding UTF8
$NotSignedOutput | Export-Csv $LogPathNotSigned -NoTypeInformation -Encoding UTF8

####################################################################################################
# STATISTIKY
####################################################################################################

Write-Host "------------------------------------------------------"
Write-Host "Celkem synchronizovanych uzivatelu:" $AllSynced.Count
Write-Host "Prihlasenych = $($SignedUsers.Count)" -ForegroundColor Green
Write-Host "Neprihlasenych = $($NotSignedUsers.Count)" -ForegroundColor Red
Get-Date