
<# 
    Export všech GPO + HTML report
    Autor: F. Kurec
    Popis:
      - Zálohuje všechny GPO do zadané složky
      - Vygeneruje souhrnný HTML report všech GPO
      - Volitelně vygeneruje i samostatné HTML pro každé GPO

    Požadavky: RSAT/GPMC, moduly GroupPolicy + ActiveDirectory, oprávnění v doméně
#>

# ===== Nastavení =====
$Domain      = (Get-ADDomain).DNSRoot        # nebo ručně: 'contoso.local'
$BackupPath  = 'C:\install\GPO_Backup_25112025'               # cílová složka pro zálohy GPO
$ReportPath  = 'C:\install\GPO_Reports_25112025'              # cílová složka pro HTML reporty
$PerGpoHtml  = $true                         # true = generovat HTML pro každé GPO zvlášť

# ===== Příprava prostředí =====
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module GroupPolicy     -ErrorAction Stop  # PS 3.0+ se načítá automaticky
} catch {
    Write-Error "Nepodařilo se načíst potřebné moduly: $_"
    exit 1
}

# Vytvoření složek, pokud neexistují
foreach ($p in @($BackupPath, $ReportPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        New-Item -ItemType Directory -Path $p | Out-Null
    }
}

Write-Host "Doména: $Domain"
Write-Host "Backup: $BackupPath"
Write-Host "Reporty: $ReportPath"

# ===== Záloha všech GPO =====
# Pozn.: Backup-GPO neumí -All; použijeme Get-GPO -All a iteraci
$allGpos = Get-GPO -All -Domain $Domain
if (-not $allGpos) {
    Write-Warning "Nebyla nalezena žádná GPO."
} else {
    foreach ($gpo in $allGpos) {
        try {
            Backup-GPO -Guid $gpo.Id -Path $BackupPath -ErrorAction Stop
            Write-Host "Zálohováno: $($gpo.DisplayName)"
        } catch {
            Write-Warning "Záloha selhala pro '$($gpo.DisplayName)': $_"
        }
    }
}

# ===== Souhrnný HTML report všech GPO =====
# Vytvoří jeden souhrnný HTML soubor s popisem / nastaveními všech GPO
$summaryHtml = Join-Path $ReportPath "All-GPOs-$((Get-Date).ToString('yyyyMMdd-HHmm')).html"
try {
    Get-GPOReport -All -Domain $Domain -ReportType HTML -Path $summaryHtml
    Write-Host "Souhrnný report: $summaryHtml"
} catch {
    Write-Warning "Generování souhrnného reportu selhalo: $_"
}

# ===== Volitelné: HTML report pro každé GPO zvlášť =====
if ($PerGpoHtml -and $allGpos) {
    $perGpoDir = Join-Path $ReportPath "Per-GPO"
    if (-not (Test-Path $perGpoDir)) { New-Item -ItemType Directory -Path $perGpoDir | Out-Null }

    foreach ($gpo in $allGpos) {
        $safeName = ($gpo.DisplayName -replace '[\\/:*?"<>|]', '_')
        $gpoHtml  = Join-Path $perGpoDir "$safeName.html"
        try {
            Get-GPOReport -Guid $gpo.Id -Domain $Domain -ReportType HTML -Path $gpoHtml
            Write-Host "Report: $gpoHtml"
        } catch {
            Write-Warning "Report selhal pro '$($gpo.DisplayName)': $_"
        }
    }
}

Write
