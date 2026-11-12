# ==============================================================================
# Script d'installation modulaire Windows (Scoop + WinGet)
#
# À lancer dans un terminal NORMAL (pas administrateur) : Scoop et plusieurs
# applis (Rio, Claude Code...) refusent de s'installer en admin. Seul le module
# Unbloat a besoin de droits élevés : il s'exécute dans une fenêtre séparée qui
# demande l'élévation (UAC) au moment voulu.
# ==============================================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "[!] Ce script ne doit pas être lancé en administrateur." -ForegroundColor Red
    Write-Host "    Scoop et certaines applis refusent de s'installer dans un terminal élevé." -ForegroundColor Red
    Write-Host "    Ouvre un terminal PowerShell normal et relance le script." -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour quitter..."
    Exit 1
}

Clear-Host
Write-Host "=== CONFIGURATION INITIALE WINDOWS ===" -ForegroundColor Cyan

# 0. Autoriser l'exécution de scripts de façon permanente pour l'utilisateur courant
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
} catch {
    Write-Host "[!] Impossible de modifier l'ExecutionPolicy (stratégie imposée ?) : $($_.Exception.Message)" -ForegroundColor Yellow
}

# Liste des paquets qui ont échoué, affichée à la fin
$script:Failures = @()

function Install-ScoopApps {
    param([string[]]$Packages)
    foreach ($pkg in $Packages) {
        $name = $pkg.Split('/')[-1]
        scoop install $pkg
        $installed = $false
        try { $installed = [bool](scoop list | Where-Object { $_.Name -eq $name }) } catch {}
        if (-not $installed) { $script:Failures += "scoop : $pkg" }
    }
}

function Install-WingetApp {
    param([string]$Id)
    winget install --id $Id -e --accept-source-agreements --accept-package-agreements
    # 0 = installé, -1978335189 = déjà installé / aucune mise à jour applicable
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { $script:Failures += "winget : $Id" }
}

# 1. Installation de Scoop si absent
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installation de Scoop..." -ForegroundColor Green
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

Write-Host "[*] Ajout des buckets Scoop..." -ForegroundColor Green
scoop install git 2>$null
scoop bucket add extras 2>$null
scoop bucket add versions 2>$null
scoop bucket add nerd-fonts 2>$null

# ==============================================================================
# MENU DE SÉLECTION DES MODULES
# ==============================================================================
Write-Host "`nQuels modules souhaitez-vous installer ?" -ForegroundColor Cyan
$modules = @(
    @{ Name = "Core / General (Navigateur, Simplenote, Outils CLI/GUI...)"; Selected = $true },
    @{ Name = "Dev / SecOps (Python, Node, Rust, K3d, Helm, Azure, Trivy, K9s, Stern, TFLint...)"; Selected = $true },
    @{ Name = "Gaming (Steam, Discord)"; Selected = $false },
    @{ Name = "Corporate (Teams)"; Selected = $false },
    @{ Name = "Music (ASIO4ALL)"; Selected = $false },
    @{ Name = "Ricing (GlazeWM, Zebar, Flow Launcher)"; Selected = $true },
    @{ Name = "Unbloat & Privacy (Suppression Edge/Copilot/OneDrive, demande l'élévation UAC)"; Selected = $false }
)

for ($i = 0; $i -lt $modules.Count; $i++) {
    $status = if ($modules[$i].Selected) { "[X]" } else { "[ ]" }
    Write-Host "$($i + 1). $status $($modules[$i].Name)"
}

$choix = Read-Host "`nEntrez les numéros des modules à installer séparés par des espaces (ex: 1 2 6) ou appuyez sur Entrée pour la sélection par défaut"
if (-not [string]::IsNullOrWhiteSpace($choix)) {
    for ($i = 0; $i -lt $modules.Count; $i++) { $modules[$i].Selected = $false }
    foreach ($c in $choix.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) {
        $idx = [int]$c - 1
        if ($idx -ge 0 -and $idx -lt $modules.Count) { $modules[$idx].Selected = $true }
    }
}

# ==============================================================================
# EXÉCUTION DES INSTALLATIONS
# ==============================================================================

if ($modules[0].Selected) {
    Write-Host "`n--- Installation du module CORE / GENERAL ---" -ForegroundColor Yellow
    Install-ScoopApps @(
        "extras/zen-browser", "extras/notion", "extras/simplenote", "extras/spotify",
        "extras/audacity", "extras/onlyoffice-desktopeditors", "extras/draw.io",
        "extras/localsend", "extras/vlc", "extras/peazip", "extras/rio",
        "main/starship", "main/nu", "main/ripgrep", "main/bat",
        "nerd-fonts/JetBrainsMono-NF"
    )
}

if ($modules[1].Selected) {
    Write-Host "`n--- Installation du module DEV / SECOPS ---" -ForegroundColor Yellow
    Install-ScoopApps @(
        "main/git", "main/python", "main/nodejs-lts", "main/rustup", "main/terraform",
        "main/tflint", "main/kubectl", "main/k3d", "main/helm", "main/helmfile",
        "main/azure-cli", "main/trivy", "main/k9s", "main/stern",
        "extras/bruno", "extras/zed", "extras/lazygit"
    )

    # Mise à jour propre de pip sur l'unique instance Python Scoop
    python -m pip install --upgrade pip

    # Zed : indentation sur 2 espaces (ne touche pas à une config existante)
    $zedDir = "$env:APPDATA\Zed"
    $zedSettings = "$zedDir\settings.json"
    if (-not (Test-Path $zedDir)) { New-Item -ItemType Directory -Path $zedDir -Force | Out-Null }
    if (-not (Test-Path $zedSettings)) {
        $zedConfig = @"
{
  "tab_size": 2,
  "hard_tabs": false,
  "languages": {
    "Python": { "tab_size": 2, "hard_tabs": false },
    "Rust": { "tab_size": 2, "hard_tabs": false }
  }
}
"@
        Set-Content -Path $zedSettings -Value $zedConfig -Encoding utf8
    } else {
        Write-Host "[!] $zedSettings existe déjà : ajoutez-y `"tab_size`": 2 à la main." -ForegroundColor Yellow
    }

    # Podman Desktop demande lui-même l'élévation (UAC) si son installeur en a besoin
    Install-WingetApp "RedHat.Podman-Desktop"
    Install-WingetApp "Anthropic.ClaudeCode"
}

if ($modules[2].Selected) {
    Write-Host "`n--- Installation du module GAMING ---" -ForegroundColor Yellow
    Install-ScoopApps @("extras/steam", "extras/discord")
}

if ($modules[3].Selected) {
    Write-Host "`n--- Installation du module CORPORATE ---" -ForegroundColor Yellow
    Install-WingetApp "Microsoft.Teams"
}

if ($modules[4].Selected) {
    Write-Host "`n--- Installation du module MUSIC ---" -ForegroundColor Yellow
    # L'installeur d'ASIO4ALL peut réclamer l'élévation ; en cas d'échec, voir le récapitulatif final
    Install-ScoopApps @("extras/asio4all")
}

if ($modules[5].Selected) {
    Write-Host "`n--- Installation du module RICING ---" -ForegroundColor Yellow
    Install-ScoopApps @("extras/flow-launcher", "extras/glazewm", "extras/zebar")

    # GlazeWM : raccourcis identiques à ceux de Fedora (Super = touche Windows)
    $glazeDir = "$env:USERPROFILE\.glzr\glazewm"
    $glazeConfig = "$glazeDir\config.yaml"
    if (-not (Test-Path $glazeDir)) { New-Item -ItemType Directory -Path $glazeDir -Force | Out-Null }
    if (Test-Path $glazeConfig) { Copy-Item $glazeConfig "$glazeConfig.bak" -Force }

    $workspaces = (1..9 | ForEach-Object { "  - name: `"$_`"" }) -join "`n"
    $workspaceBinds = (1..9 | ForEach-Object {
@"
  - commands: ["focus --workspace $_"]
    bindings: ["lwin+$_"]
  - commands: ["move --workspace $_", "focus --workspace $_"]
    bindings: ["lwin+shift+$_"]
"@
    }) -join "`n"

    $glazeYaml = @"
general:
  startup_commands: []
  focus_follows_cursor: false

workspaces:
$workspaces

keybindings:
  # Super + T : terminal (Rio)
  - commands: ["shell-exec rio"]
    bindings: ["lwin+t"]
  # Super + R : lanceur d'applications (Flow Launcher)
  - commands: ["shell-exec Flow.Launcher.exe"]
    bindings: ["lwin+r"]
  # Super + C : fermer la fenêtre active
  - commands: ["close"]
    bindings: ["lwin+c"]
  # Super + Shift + E : quitter GlazeWM
  - commands: ["wm-exit"]
    bindings: ["lwin+shift+e"]
  # Super + [1-9] / Super + Shift + [1-9] : espaces de travail
$workspaceBinds
"@
    Set-Content -Path $glazeConfig -Value $glazeYaml -Encoding utf8
}

if ($modules[6].Selected) {
    Write-Host "`n--- Application des scripts d'UNBLOAT ---" -ForegroundColor Yellow

    # Réglages utilisateur (HKCU) : pas besoin de droits admin
    Write-Host "Désactivation de Copilot et des widgets (utilisateur)..."
    reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f

    # Réglages machine (HKLM), OneDrive et utilitaire Chris Titus : dans une fenêtre élevée
    $unbloatScript = @'
Write-Host "=== UNBLOAT (administrateur) ===" -ForegroundColor Cyan

Write-Host "Suppression de OneDrive..."
taskkill /f /im OneDrive.exe 2>$null
$oneDriveSetup = if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" } else { "$env:SystemRoot\System32\OneDriveSetup.exe" }
& $oneDriveSetup /uninstall 2>$null

Write-Host "Désactivation de Copilot, de la télémétrie et de la localisation (machine)..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f

Write-Host "Pour un unbloat plus poussé (Edge, etc.), lancement de l'utilitaire Chris Titus Tech..." -ForegroundColor Cyan
iwr -useb https://christitus.com/win | iex
'@
    $unbloatPath = Join-Path $env:TEMP "drainda-unbloat.ps1"
    Set-Content -Path $unbloatPath -Value $unbloatScript -Encoding utf8
    try {
        Write-Host "Une fenêtre administrateur va s'ouvrir (validation UAC requise)..." -ForegroundColor Cyan
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$unbloatPath`"" -Verb RunAs -Wait
    } catch {
        Write-Host "[!] Élévation refusée ou impossible : l'unbloat machine n'a pas été appliqué." -ForegroundColor Yellow
        $script:Failures += "unbloat : partie administrateur non exécutée"
    } finally {
        Remove-Item $unbloatPath -Force -ErrorAction SilentlyContinue
    }
}

# ==============================================================================
# CONFIGURATION MINIMALE (Rio -> Nushell -> Starship)
# ==============================================================================
if ($modules[0].Selected) {
    Write-Host "`n--- Configuration basique de Rio & Nushell ---" -ForegroundColor Yellow

    # 1. Rio : définir Nushell comme shell par défaut et JetBrainsMono Nerd Font
    $rioDir = "$env:LOCALAPPDATA\rio"
    if (-not (Test-Path $rioDir)) { New-Item -ItemType Directory -Path $rioDir -Force | Out-Null }

    $rioConfig = @"
[shell]
program = "nu"
args = []

[fonts]
family = "JetBrainsMono Nerd Font"
size = 14
"@
    Set-Content -Path "$rioDir\config.toml" -Value $rioConfig -Encoding utf8

    # 2. Nushell : initialiser Starship et désactiver la bannière de bienvenue
    $nuDir = "$env:APPDATA\nushell"
    if (-not (Test-Path $nuDir)) { New-Item -ItemType Directory -Path $nuDir -Force | Out-Null }

    $starshipInitDir = "$env:USERPROFILE\.cache\starship"
    if (-not (Test-Path $starshipInitDir)) { New-Item -ItemType Directory -Path $starshipInitDir -Force | Out-Null }
    starship init nu | Out-File -FilePath "$starshipInitDir\init.nu" -Encoding utf8

    $nuConfig = @"
`$env.config.show_banner = false
use ~/.cache/starship/init.nu
"@
    $nuConfigPath = "$nuDir\config.nu"
    # Évite de dupliquer les lignes si le script est relancé
    if (-not (Test-Path $nuConfigPath) -or -not (Select-String -Path $nuConfigPath -Pattern "starship/init.nu" -Quiet)) {
        Add-Content -Path $nuConfigPath -Value $nuConfig -Encoding utf8
    }
}

# ==============================================================================
# RÉCAPITULATIF
# ==============================================================================
if ($script:Failures.Count -gt 0) {
    Write-Host "`n=== TERMINÉ, MAIS CERTAINS ÉLÉMENTS ONT ÉCHOUÉ ===" -ForegroundColor Yellow
    $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "Relance l'installation de ces éléments à la main (certains installeurs demandent l'élévation)." -ForegroundColor Yellow
} else {
    Write-Host "`n=== INSTALLATION TERMINÉE AVEC SUCCÈS ! ===" -ForegroundColor Green
}
Read-Host "Appuyez sur Entrée pour quitter..."
