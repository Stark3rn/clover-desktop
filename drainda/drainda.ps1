# ==============================================================================
# Script d'installation modulaire Windows (Scoop + WinGet)
# ==============================================================================

# Vérification des droits administrateur (requis pour certains unbloats / winget)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Relance du script en mode Administrateur..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Clear-Host
Write-Host "=== CONFIGURATION INITIALE WINDOWS ===" -ForegroundColor Cyan

# 1. Installation de Scoop si absent
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installation de Scoop..." -ForegroundColor Green
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

Write-Host "[*] Ajout des buckets Scoop..." -ForegroundColor Green
scoop bucket add extras 2>$null
scoop bucket add versions 2>$null
scoop bucket add nerd-fonts 2>$null
scoop install git 2>$null

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
    @{ Name = "Unbloat & Privacy (Suppression Edge/Copilot/OneDrive)"; Selected = $false }
)

for ($i = 0; $i -lt $modules.Count; $i++) {
    $status = if ($modules[$i].Selected) { "[X]" } else { "[ ]" }
    Write-Host "$($i + 1). $status $($modules[$i].Name)"
}

$choix = Read-Host "`nEntrez les numéros des modules à installer séparés par des espaces (ex: 1 2 6) ou appuyez sur Entrée pour la sélection par défaut"
if (-not [string]::IsNullOrWhiteSpace($choix)) {
    for ($i = 0; $i -lt $modules.Count; $i++) { $modules[$i].Selected = $false }
    foreach ($c in $choix.Split(' ')) {
        $idx = [int]$c - 1
        if ($idx -ge 0 -and $idx -lt $modules.Count) { $modules[$idx].Selected = $true }
    }
}

# ==============================================================================
# EXÉCUTION DES INSTALLATIONS
# ==============================================================================

if ($modules[0].Selected) {
    Write-Host "`n--- Installation du module CORE / GENERAL ---" -ForegroundColor Yellow
    scoop install extras/zen-browser extras/notion extras/simplenote extras/spotify extras/audacity extras/onlyoffice-desktopeditors extras/draw.io extras/localsend extras/vlc extras/peazip extras/rio main/starship main/nu main/ripgrep main/bat nerd-fonts/JetBrainsMono-NF
}

if ($modules[1].Selected) {
    Write-Host "`n--- Installation du module DEV / SECOPS ---" -ForegroundColor Yellow
    scoop install main/git main/python main/nodejs-lts main/rustup main/terraform main/tflint main/kubectl main/k3d main/helm main/helmfile main/azure-cli main/trivy main/k9s main/stern extras/bruno extras/zed extras/lazygit
    
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

    winget install --id RedHat.Podman-Desktop -e --accept-source-agreements --accept-package-agreements
    winget install --id Anthropic.ClaudeCode -e --accept-source-agreements --accept-package-agreements
}

if ($modules[2].Selected) {
    Write-Host "`n--- Installation du module GAMING ---" -ForegroundColor Yellow
    scoop install extras/steam extras/discord
}

if ($modules[3].Selected) {
    Write-Host "`n--- Installation du module CORPORATE ---" -ForegroundColor Yellow
    winget install --id Microsoft.Teams -e --accept-source-agreements --accept-package-agreements
}

if ($modules[4].Selected) {
    Write-Host "`n--- Installation du module MUSIC ---" -ForegroundColor Yellow
    scoop install extras/asio4all
}

if ($modules[5].Selected) {
    Write-Host "`n--- Installation du module RICING ---" -ForegroundColor Yellow
    scoop install extras/flow-launcher extras/glazewm extras/zebar

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
    
    # Suppression OneDrive
    Write-Host "Suppression de OneDrive..."
    taskkill /f /im OneDrive.exe 2>$null
    & "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" /uninstall 2>$null

    # Désactivation Copilot (Registre)
    Write-Host "Désactivation de Copilot..."
    reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f

    # Télémétrie & Widgets
    Write-Host "Désactivation de la télémétrie et des widgets..."
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f

    Write-Host "Pour un unbloat plus poussé (Edge, etc.), lancement de l'utilitaire Chris Titus Tech..." -ForegroundColor Cyan
    iwr -useb https://christitus.com/win | iex
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
    Add-Content -Path "$nuDir\config.nu" -Value $nuConfig -Encoding utf8
}

Write-Host "`n=== INSTALLATION TERMINÉE AVEC SUCCÈS ! ===" -ForegroundColor Green
Read-Host "Appuyez sur Entrée pour quitter..."