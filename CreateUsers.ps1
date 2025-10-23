# Přihlášení do Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All Group.ReadWrite.All"


# Cesty k souborům
$CsvPath = "C:\temp\Scripts\users.csv"
$LogPath = "C:\temp\Scripts\user_creation_log.csv"

# ID cílové skupiny
$GroupId = "accc13ef-d100-4eac-a754-3f6a389a9f50"


# Funkce pro generování hesla
function New-Password {
    param([int]$Length = 12)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*()-_=+'
    -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

# Inicializace logu
"DisplayName,UserPrincipalName,GeneratedPassword,Status" | Out-File -FilePath $LogPath -Encoding UTF8

# Počítadla
$CreatedCount = 0
$SkippedCount = 0
$FailedCount = 0

# Načtení uživatelů z CSV
$Users = Import-Csv -Path $CsvPath

foreach ($User in $Users) {
    try {
        # Ověření existence uživatele
        $ExistingUser = Get-MgUser -Filter "userPrincipalName eq '$($User.UserPrincipalName)'" -ErrorAction SilentlyContinue

        if ($ExistingUser) {
            Write-Host "[SKIP] User already exists: $($User.UserPrincipalName)" -ForegroundColor Yellow
            "$($User.DisplayName),$($User.UserPrincipalName),N/A,Skipped (Already Exists)" | Out-File -FilePath $LogPath -Append -Encoding UTF8
            $SkippedCount++
            continue
        }

        # Generování hesla
        $Password = New-Password
        $PasswordProfile = @{
            Password = $Password
            ForceChangePasswordNextSignIn = $true
        }

        Write-Host "[CREATE] Creating user: $($User.DisplayName)" -ForegroundColor Cyan

        # Vytvoření uživatele
        $NewUser = New-MgUser `
            -AccountEnabled:$true `
            -DisplayName $User.DisplayName `
            -GivenName $User.FirstName `
            -Surname $User.LastName `
            -UserPrincipalName $User.UserPrincipalName `
            -MailNickname ($User.UserPrincipalName.Split("@")[0]) `
            -CompanyName $User.Company `
            -PasswordProfile $PasswordProfile

        # Přidání do skupiny
        New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $NewUser.Id

        Write-Host "[OK] User created and added to group: $($User.UserPrincipalName)" -ForegroundColor Green
        "$($User.DisplayName),$($User.UserPrincipalName),$Password,Success" | Out-File -FilePath $LogPath -Append -Encoding UTF8
        $CreatedCount++
    }
    catch {
        Write-Host "[ERROR] Failed to create user $($User.UserPrincipalName): $_" -ForegroundColor Red
        "$($User.DisplayName),$($User.UserPrincipalName),$Password,Failed: $_" | Out-File -FilePath $LogPath -Append -Encoding UTF8
        $FailedCount++
    }
}

# Souhrn
Write-Host "`n=== SUMMARY ===" -ForegroundColor White
Write-Host "Created: $CreatedCount" -ForegroundColor Green
Write-Host "Skipped: $SkippedCount" -ForegroundColor Yellow
Write-Host "Failed:  $FailedCount" -ForegroundColor Red
Write-Host "`nLog saved to: $LogPath" -ForegroundColor White
