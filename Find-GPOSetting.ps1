# Funkce skriptu:
# 
#  Odstraní nepovolené znaky* a ! z názvu GPO.
#  Exportuje GPO do XML.
#  Vyhledá nastavení „Cokoliv“.
#  Vypíše názvy GPO, kde bylo nastavení nalezeno.

# ===================================================================================
# Vytvoření složky pro export
$ExportFolder = "C:\GPOReports"
New-Item -ItemType Directory -Path $ExportFolder -Force

# Definice hledaného výrazu
#$SearchTerm = "Kerberos client support for claims"
$SearchTerm = "KDC support for claims"

Write-host " ----------------------------------------------------------------"
Write-host "Hledam GPO nastaveni: $SearchTerm "
Write-host " ----------------------------------------------------------------"

# Získání všech GPO a zpracování názvů
Get-GPO -All | ForEach-Object {
    $OriginalName = $_.DisplayName
    # Odstranění nepovolených znaků: * ! a mezera
    $SanitizedName = $OriginalName -replace '[-*! ]', ''

    # Cesta k souboru
    $FilePath = Join-Path $ExportFolder "$SanitizedName.xml"

    # Export do XML
    Get-GPOReport -Name $OriginalName -ReportType Xml -Path $FilePath

    # Vyhledání výrazu v obsahu
    # $Content = Get-Content $FilePath
    $Content = Get-Content $FilePath -ErrorAction SilentlyContinue
    if ($Content -match $SearchTerm) {
        Write-Host "Nastavení nalezeno v GPO: $SanitizedName" -ForegroundColor Green
    }
}