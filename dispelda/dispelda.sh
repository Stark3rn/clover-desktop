#!/usr/bin/env bash
set -e

# ==============================================================================
# Script d'installation modulaire Fedora Everything (Minimal -> Custom Setup)
# Cible : Fedora 44+ (niri et Noctalia sont dans les dépôts officiels)
# ==============================================================================

# Éléments qui ont échoué, listés à la fin sans interrompre le script
FAILED=()

if [ "$EUID" -eq 0 ]; then
  echo "Ne lancez pas ce script en root (sudo). Lancez-le en tant qu'utilisateur normal."
  exit 1
fi

# Les fichiers de config du dépôt vivent dans dotfiles/ (à la racine du dépôt)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dotfiles"

# Copie dotfiles/<source> vers <cible>. Si une config différente existe déjà,
# elle est sauvegardée à côté (.bak-horodatage) avant d'être remplacée.
install_dotfile() {
  local src="$DOTFILES_DIR/$1" target="$2"
  if [ ! -f "$src" ]; then
    echo "[!] Dotfile introuvable : $src"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  if [ -f "$target" ] && ! cmp -s "$src" "$target"; then
    cp "$target" "$target.bak-$(date +%Y%m%d-%H%M%S)"
  fi
  cp "$src" "$target"
  echo "[*] Config appliquée : $target"
}

# Installe Zed. Le script officiel télécharge depuis cloud.zed.dev, qui renvoie
# parfois des erreurs 500 : dans ce cas on prend la même archive sur GitHub.
install_zed() {
  if [ -x "$HOME/.local/bin/zed" ] || command -v zed > /dev/null 2>&1; then
    echo "[*] Zed est déjà installé."
    return 0
  fi
  if curl -fsSL https://zed.dev/install.sh | sh; then
    return 0
  fi

  echo "[!] Le script officiel de Zed a échoué : repli sur l'archive GitHub..."
  local arch tmp
  arch="$(uname -m)"
  tmp="$(mktemp -d)"
  curl -fL -o "$tmp/zed.tar.gz" \
    "https://github.com/zed-industries/zed/releases/latest/download/zed-linux-${arch}.tar.gz"
  rm -rf "$HOME/.local/zed.app"
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
  tar -xzf "$tmp/zed.tar.gz" -C "$HOME/.local/"
  rm -rf "$tmp"
  ln -sf "$HOME/.local/zed.app/bin/zed" "$HOME/.local/bin/zed"
  cp "$HOME/.local/zed.app/share/applications/dev.zed.Zed.desktop" "$HOME/.local/share/applications/dev.zed.Zed.desktop"
  sed -i "s|Icon=zed|Icon=$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png|g; s|Exec=zed|Exec=$HOME/.local/zed.app/bin/zed|g" \
    "$HOME/.local/share/applications/dev.zed.Zed.desktop"
}

clear
echo "=== CONFIGURATION INITIALE FEDORA EVERYTHING ==="

# 0. Prérequis système (Dépôts RPM Fusion, Flathub & Homebrew)
echo "[*] Mise à jour initiale et activation de RPM Fusion (free + nonfree) & Flathub..."
sudo dnf upgrade --refresh -y
sudo dnf install -y dnf-plugins-core curl wget git tar unzip flatpak bash-completion

# Le dépôt nonfree complet est obligatoire : le driver legacy 580xx n'est que là.
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

if ! command -v brew &> /dev/null && [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  # Déjà installé (relance du script) mais pas encore dans le PATH de cette session
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

if ! command -v brew &> /dev/null; then
  echo "[*] Installation de Homebrew (pour les outils CLI récents)..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ==============================================================================
# MENU DE SÉLECTION DES MODULES
# ==============================================================================
echo ""
echo "Quels modules souhaitez-vous installer ?"
options=(
  "Core / General (Zen, Kitty, Nushell, Starship, CLI tools, Apps...)"
  "Dev / SecOps (Zed, Python+pipx, Node, Rust, Podman, K3d, Helm, Azure, Trivy, K9s...)"
  "Gaming (Steam via RPM Fusion pour les libs 32 bits Nvidia, Discord)"
  "Corporate (Teams for Linux Electron)"
  "Drivers (détection auto : Nvidia selon la série + Secure Boot, firmwares Wi-Fi/Bluetooth Intel)"
  "Ricing Wayland (Hyprland+Caelestia et/ou Niri+Noctalia, SDDM, clavier AZERTY, socle minimal)"
)
selected=(1 1 0 0 0 1)

for i in "${!options[@]}"; do
  mark="[ ]"; [ "${selected[$i]}" -eq 1 ] && mark="[X]"
  echo "$((i+1)). $mark ${options[$i]}"
done

echo ""
read -rp "Entrez les numéros des modules séparés par des espaces (ex: 1 2 5 6) ou Entrée pour défaut : " choix
if [ -n "$choix" ]; then
  selected=(0 0 0 0 0 0)
  for c in $choix; do
    idx=$((c-1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#options[@]}" ]; then
      selected[$idx]=1
    fi
  done
fi

# Sous-choix pour le module Ricing si activé : un ou plusieurs environnements
want_hypr=0
want_niri=0
if [ "${selected[5]}" -eq 1 ]; then
  echo ""
  echo "Quels environnements Wayland souhaitez-vous installer ? (les deux sont possibles)"
  echo "1. Hyprland + Caelestia (Quickshell)"
  echo "2. Niri + Noctalia Shell"
  read -rp "Votre choix (1, 2, ou 1 2 pour les deux ; Entrée = les deux) : " ricing_choice
  ricing_choice="${ricing_choice:-1 2}"
  if [[ "$ricing_choice" == *1* ]]; then want_hypr=1; fi
  if [[ "$ricing_choice" == *2* ]]; then want_niri=1; fi
  if [ "$want_hypr" -eq 0 ] && [ "$want_niri" -eq 0 ]; then
    echo "[!] Choix non reconnu : Hyprland et Niri seront tous deux installés."
    want_hypr=1
    want_niri=1
  fi
fi

# Détection d'une machine virtuelle (VMware, VirtualBox, KVM...)
is_vm=0
virt="$(systemd-detect-virt 2>/dev/null || true)"
if [ -n "$virt" ] && [ "$virt" != "none" ]; then
  is_vm=1
  echo "[*] Machine virtuelle détectée : $virt"
fi

# ==============================================================================
# EXÉCUTION DES INSTALLATIONS
# ==============================================================================

if [ "${selected[0]}" -eq 1 ]; then
  echo -e "\n--- Installation du module CORE / GENERAL ---"

  # Terminal Kitty & polices Nerd Fonts
  sudo dnf install -y kitty jetbrains-mono-fonts-all
  # (l'archive de release est stable, contrairement aux chemins du dépôt qui changent)
  mkdir -p ~/.local/share/fonts/JetBrainsMonoNerd
  nerd_tmp="$(mktemp -d)"
  curl -fL -o "$nerd_tmp/JetBrainsMono.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -oq "$nerd_tmp/JetBrainsMono.zip" '*.ttf' -d ~/.local/share/fonts/JetBrainsMonoNerd
  rm -rf "$nerd_tmp"
  fc-cache -f

  # Shell Nushell, Prompt Starship & Outils CLI modernes
  brew install nushell starship ripgrep bat lazygit

  # Applications graphiques via Flathub
  flatpak install -y flathub \
    app.zen_browser.zen \
    io.github.brunofin.Cohesion \
    com.spotify.Client \
    org.audacityteam.Audacity \
    org.onlyoffice.desktopeditors \
    com.jgraph.drawio.desktop \
    org.localsend.localsend_app \
    org.videolan.VLC \
    io.github.peazip.PeaZip

  # Configuration basique : Kitty -> Nushell -> Starship
  mkdir -p ~/.config/kitty ~/.config/nushell ~/.cache/starship
  cat << 'EOF' > ~/.config/kitty/kitty.conf
shell /home/linuxbrew/.linuxbrew/bin/nu
font_family JetBrainsMono Nerd Font
font_size 11.5
EOF

  /home/linuxbrew/.linuxbrew/bin/starship init nu > ~/.cache/starship/init.nu
  # Évite de dupliquer ces lignes si le script est relancé
  if ! grep -q "starship/init.nu" ~/.config/nushell/config.nu 2>/dev/null; then
    cat << 'EOF' >> ~/.config/nushell/config.nu
$env.config.show_banner = false
$env.PATH = ($env.PATH | split row (char esep) | prepend '/home/linuxbrew/.linuxbrew/bin' | prepend $"($env.HOME)/.local/bin")
use ~/.cache/starship/init.nu
EOF
  fi
fi

if [ "${selected[1]}" -eq 1 ]; then
  echo -e "\n--- Installation du module DEV / SECOPS ---"

  # Outils natifs + Python & pipx
  sudo dnf install -y git python3 python3-pip pipx podman podman-compose nodejs npm rust cargo \
    gcc gcc-c++ make cmake gdb
  pipx ensurepath

  # Client API Bruno (Flathub)
  flatpak install -y flathub com.usebruno.Bruno

  # Éditeur Zed (script officiel, avec repli sur l'archive GitHub si leur serveur est en panne)
  install_zed

  # Zed : config versionnée dans dotfiles/zed
  install_dotfile zed/settings.json ~/.config/zed/settings.json

  # Outils DevOps / SecOps via Brew (un par un : une formule absente ne bloque pas les autres)
  # - terraform et tflint ne sont plus dans homebrew-core : tap HashiCorp / archive GitHub (plus bas)
  # - azure-cli n'est plus dans homebrew-core : dépôt RPM Microsoft (plus bas)
  # - kubectl est un alias de kubernetes-cli
  for formula in hashicorp/tap/terraform kubernetes-cli k3d helm helmfile trivy k9s stern; do
    brew install "$formula" || FAILED+=("brew : $formula")
  done

  # tflint : binaire de la dernière release GitHub, dans ~/.local/bin
  case "$(uname -m)" in
    x86_64)  tflint_arch="amd64" ;;
    aarch64) tflint_arch="arm64" ;;
    *)       tflint_arch="" ;;
  esac
  if [ -n "$tflint_arch" ]; then
    tflint_tmp="$(mktemp -d)"
    if curl -fL -o "$tflint_tmp/tflint.zip" \
        "https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_${tflint_arch}.zip" \
      && unzip -oq "$tflint_tmp/tflint.zip" tflint -d "$tflint_tmp" \
      && mkdir -p ~/.local/bin && install -m 0755 "$tflint_tmp/tflint" ~/.local/bin/tflint; then
      echo "[*] tflint installé dans ~/.local/bin"
    else
      FAILED+=("tflint")
    fi
    rm -rf "$tflint_tmp"
  fi

  # Azure CLI : dépôt RPM officiel Microsoft (celui de RHEL 9 sert aussi à Fedora)
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm \
    || echo "[i] Dépôt Microsoft déjà configuré."
  sudo dnf install -y azure-cli || FAILED+=("azure-cli")

  # Claude Code CLI : installé dans ~/.local (le préfixe global de Fedora, /usr, demanderait root)
  npm install -g --prefix ~/.local @anthropic-ai/claude-code || FAILED+=("claude-code")
fi

if [ "${selected[2]}" -eq 1 ]; then
  echo -e "\n--- Installation du module GAMING ---"
  # Steam en RPM (RPM Fusion nonfree) : le Flatpak Steam a besoin d'un runtime
  # Nvidia GL assorti, peu fiable avec la branche legacy 580xx.
  sudo dnf install -y steam
  flatpak install -y flathub com.discordapp.Discord
fi

if [ "${selected[3]}" -eq 1 ]; then
  echo -e "\n--- Installation du module CORPORATE ---"
  flatpak install -y flathub com.github.IsmaelMartinez.teams_for_linux
fi

if [ "${selected[4]}" -eq 1 ]; then
  echo -e "\n--- Installation du module DRIVERS ---"

  sudo dnf install -y pciutils

  # --- Détection du matériel ---------------------------------------------------
  gpu_lines="$(lspci -nn | grep -Ei 'VGA compatible|3D controller|Display controller' || true)"
  echo "[*] Cartes graphiques détectées :"
  echo "${gpu_lines:-(aucune)}" | sed 's/^/    /'

  # Wi-Fi + Bluetooth Intel : drivers dans le noyau, il ne manque que les firmwares
  if lspci | grep -Ei 'Network controller.*Intel' > /dev/null; then
    echo "[*] Wi-Fi Intel détecté : installation des firmwares Wi-Fi et Bluetooth..."
    sudo dnf install -y iwlwifi-mvm-firmware iwlbluetooth-firmware NetworkManager-wifi bluez
    sudo systemctl enable --now NetworkManager bluetooth
  fi

  # --- Choix du driver selon la génération de la carte -------------------------
  # Le code de la puce figure dans le nom lspci (ex : "GP104 [GeForce GTX 1070]").
  #   Blackwell/Ada/Ampere/Turing (GB/AD/GA/TU : RTX 50/40/30/20, GTX 16) -> akmod-nvidia
  #   Volta/Pascal/Maxwell (GV/GP/GM : GTX 750, 9xx, 10xx)               -> akmod-nvidia-580xx
  #   Kepler (GK : GTX 6xx/7xx)                                          -> akmod-nvidia-470xx
  #   Plus ancien (Fermi, Tesla...)                                      -> nouveau (pilote libre)
  nv_branch=""
  if echo "$gpu_lines" | grep -qi 'NVIDIA'; then
    nv_line="$(echo "$gpu_lines" | grep -i 'NVIDIA' | head -n 1)"
    chip="$(echo "$nv_line" | grep -oE '\b(G[A-Z]|AD|TU)[0-9]{2,3}[A-Z]?\b|\bG[0-9]{2,3}\b' | head -n 1 || true)"
    case "$chip" in
      GB*|AD*|GA*|TU*) nv_branch="current" ;;
      GV*|GP*|GM*)     nv_branch="580xx" ;;
      GK*)             nv_branch="470xx" ;;
      GF*|GT*|G[0-9]*) nv_branch="none" ;;
      *)
        echo "[?] Génération Nvidia non reconnue (puce : '${chip:-inconnue}')."
        echo "    1. RTX 20/30/40/50 ou GTX 16  (akmod-nvidia)"
        echo "    2. GTX 750, 9xx ou 10xx       (akmod-nvidia-580xx)"
        echo "    3. GTX 6xx ou 7xx             (akmod-nvidia-470xx)"
        echo "    4. Aucun (nouveau)"
        read -rp "Votre choix (1-4) : " nv_pick
        case "$nv_pick" in
          1) nv_branch="current" ;;
          2) nv_branch="580xx" ;;
          3) nv_branch="470xx" ;;
          *) nv_branch="none" ;;
        esac
        ;;
    esac
    echo "[*] Nvidia : puce '${chip:-?}' -> branche '$nv_branch'"
  else
    echo "[*] Pas de carte Nvidia : les pilotes Mesa (AMD/Intel) sont déjà inclus dans Fedora."
  fi

  case "$nv_branch" in
    current) nv_pkgs="akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-libs.i686" ;;
    580xx)   nv_pkgs="akmod-nvidia-580xx xorg-x11-drv-nvidia-580xx-cuda xorg-x11-drv-nvidia-580xx-libs.i686" ;;
    470xx)   nv_pkgs="akmod-nvidia-470xx xorg-x11-drv-nvidia-470xx-cuda xorg-x11-drv-nvidia-470xx-libs.i686"
             echo "[!] Kepler (470xx) : le support Wayland est très limité, niri/Hyprland risquent de ne pas démarrer." ;;
    none)    nv_pkgs=""
             echo "[!] Carte Nvidia trop ancienne pour un driver propriétaire : nouveau sera utilisé." ;;
    *)       nv_pkgs="" ;;
  esac

  if [ -n "$nv_pkgs" ]; then
    # Secure Boot : enregistrer la clé MOK AVANT d'installer le driver
    sudo dnf install -y kmodtool akmods mokutil openssl
    if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
      echo "[*] Secure Boot actif : génération et enregistrement de la clé MOK..."
      sudo kmodgenca -a
      echo ">>> IMPORTANT : un mot de passe temporaire va être demandé pour enregistrer la clé."
      echo ">>> Au prochain redémarrage, écran bleu : Enroll MOK > Continue > Yes > mot de passe > Reboot."
      sudo mokutil --import /etc/pki/akmods/certs/public_key.der
    fi

    # shellcheck disable=SC2086
    sudo dnf install -y $nv_pkgs

    echo "[*] Attente de la compilation du module Nvidia (5 à 10 min)..."
    for _ in $(seq 1 40); do
      modinfo -F version nvidia > /dev/null 2>&1 && break
      sleep 15
    done
    if modinfo -F version nvidia > /dev/null 2>&1; then
      echo "[*] Module Nvidia prêt : $(modinfo -F version nvidia)"
    else
      echo "[!] Module pas encore compilé. Lancez 'sudo akmods --force' avant de redémarrer."
    fi

    # Modesetting (obligatoire pour les compositeurs Wayland)
    sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1"

    # Correctif VRAM pour niri (sinon ~1 Gio de VRAM au lieu de ~100 Mio)
    sudo mkdir -p /etc/nvidia/nvidia-application-profiles-rc.d
    sudo tee /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json > /dev/null << 'EOF'
{
    "rules": [
        {
            "pattern": { "feature": "procname", "matches": "niri" },
            "profile": "Limit Free Buffer Pool On Wayland Compositors"
        }
    ],
    "profiles": [
        {
            "name": "Limit Free Buffer Pool On Wayland Compositors",
            "settings": [ { "key": "GLVidHeapReuseRatio", "value": 0 } ]
        }
    ]
}
EOF
  fi
fi

if [ "$is_vm" -eq 1 ]; then
  echo -e "\n--- Outils pour machine virtuelle ---"
  # Mesa (pilote 3D virtuel vmwgfx), diagnostic OpenGL (glxinfo), terminal de secours sans OpenGL (foot)
  sudo dnf install -y mesa-dri-drivers mesa-demos foot
  if [ "$virt" = "vmware" ]; then
    sudo dnf install -y open-vm-tools open-vm-tools-desktop
    sudo systemctl enable --now vmtoolsd || true
  fi
fi

if [ "${selected[5]}" -eq 1 ]; then
  echo -e "\n--- Installation du socle Wayland minimal (depuis Fedora Everything) ---"
  # Audio (PipeWire), Réseau + Wi-Fi + Bluetooth, Polkit, Trousseau, Portails XDG,
  # Polices, Display Manager (SDDM, greeter X11)
  sudo dnf install -y \
    pipewire pipewire-pulseaudio pipewire-alsa wireplumber \
    NetworkManager NetworkManager-wifi network-manager-applet bluez \
    polkit xfce-polkit gnome-keyring \
    xdg-desktop-portal xdg-desktop-portal-gtk \
    google-noto-sans-fonts google-noto-color-emoji-fonts jetbrains-mono-fonts-all \
    wl-clipboard grim slurp brightnessctl pamixer wev \
    sddm sddm-x11

  # Clavier AZERTY dès l'installation : console (TTY) et configuration X11,
  # que lit l'écran de connexion SDDM. Hyprland et Niri sont réglés plus bas.
  sudo localectl set-keymap fr
  sudo localectl set-x11-keymap fr pc105

  sudo systemctl enable NetworkManager bluetooth sddm
  sudo systemctl set-default graphical.target

  # Variables Nvidia pour Hyprland : seulement si une vraie carte Nvidia est utilisée
  # (dans une VM, elles casseraient OpenGL)
  use_nvidia_env=0
  if lspci | grep -qi 'NVIDIA' && { [ -n "${nv_pkgs:-}" ] || rpm -qa 'akmod-nvidia*' | grep -q .; }; then
    use_nvidia_env=1
  fi

  mkdir -p ~/.config/quickshell

  if [ "$want_hypr" -eq 1 ]; then
    echo -e "\n--- Installation de HYPRLAND + CAELESTIA ---"
    sudo dnf copr enable -y errornointernet/quickshell
    sudo dnf install -y quickshell fuzzel
    # Hyprland n'est plus dans les dépôts officiels Fedora. On utilise nikromen/hyprland
    # (builds fc43 à rawhide, avec hyprland, hypridle, hyprlock et le portail).
    # solopasha/hyprland n'a plus que le chroot rawhide : ne marche pas sur une version stable.
    sudo dnf copr enable -y nikromen/hyprland
    sudo dnf install -y hyprland hypridle hyprlock xdg-desktop-portal-hyprland

    # Clonage de Caelestia Shell (prêt pour tes dotfiles)
    if [ ! -d ~/.config/quickshell/caelestia ]; then
      git clone https://github.com/caelestia-dots/shell.git ~/.config/quickshell/caelestia
    fi

    # Config minimale Hyprland pour lancer Kitty et Caelestia au démarrage
    mkdir -p ~/.config/hypr
    hypr_conf=~/.config/hypr/hyprland.conf
    [ -f "$hypr_conf" ] && cp "$hypr_conf" "$hypr_conf.bak"
    cat << 'EOF2' > "$hypr_conf"
monitor=,preferred,auto,1

exec-once = /usr/libexec/xfce-polkit
exec-once = gnome-keyring-daemon --start --components=secrets
exec-once = qs -c caelestia

# Clavier AZERTY
input {
    kb_layout = fr
}

$terminal = kitty
$menu = fuzzel

bind = SUPER, T, exec, $terminal
bind = SUPER, R, exec, $menu
bind = SUPER, C, killactive,
bind = SUPER SHIFT, E, exit,
EOF2

    # Super + [1-9] : changer d'espace de travail / Super + Shift + [1-9] : y déplacer la fenêtre
    # On utilise les codes de touches (10 à 18) : sur AZERTY, les chiffres sont en Shift,
    # les codes fonctionnent quelle que soit la disposition.
    for i in {1..9}; do
      echo "bind = SUPER, code:$((i + 9)), workspace, $i" >> "$hypr_conf"
      echo "bind = SUPER SHIFT, code:$((i + 9)), movetoworkspace, $i" >> "$hypr_conf"
    done

    if [ "$use_nvidia_env" -eq 1 ]; then
      cat << 'EOF2' >> "$hypr_conf"

# Nvidia sous Wayland
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
EOF2
    fi

    if [ "$is_vm" -eq 1 ]; then
      cat << 'EOF2' >> "$hypr_conf"

# Machine virtuelle : curseur logiciel (le curseur matériel disparaît souvent)
cursor {
    no_hardware_cursors = true
}

# Terminal de secours qui n'utilise pas OpenGL (si kitty ne démarre pas)
bind = SUPER SHIFT, T, exec, foot
EOF2
    fi
  fi

  if [ "$want_niri" -eq 1 ]; then
    echo -e "\n--- Installation de NIRI + NOCTALIA SHELL ---"
    if [ "$(rpm -E %fedora)" -lt 44 ]; then
      echo "[!] niri et noctalia ne sont dans les dépôts officiels qu'à partir de Fedora 44. Étape ignorée."
    else
      # xwayland-satellite : applis X11 (Steam, Proton) / portal-gnome : partage d'écran
      # xdg-desktop-portal-gtk (socle) : sélecteurs de fichiers
      sudo dnf install -y niri noctalia xwayland-satellite xdg-desktop-portal-gnome

      mkdir -p ~/.config/niri
      niri_conf=~/.config/niri/config.kdl
      [ -f "$niri_conf" ] && cp "$niri_conf" "$niri_conf.bak"
      cat << 'EOF2' > "$niri_conf"
// Clavier AZERTY
input {
  keyboard {
    xkb {
      layout "fr"
    }
  }
}

// Démarrage : agent polkit, trousseau, shell Noctalia
// (xwayland-satellite est lancé automatiquement par niri s'il est installé)
spawn-at-startup "/usr/libexec/xfce-polkit"
spawn-at-startup "gnome-keyring-daemon" "--start" "--components=secrets"
spawn-at-startup "noctalia"

// Les fenêtres Noctalia (réglages...) s'ouvrent en flottant
window-rule {
  match app-id="dev.noctalia.Noctalia"
  open-floating true
}

debug {
  // Notifications et activation de fenêtres depuis Noctalia
  honor-xdg-activation-with-invalid-serial
}

binds {
  // Raccourcis communs (identiques à GlazeWM / Hyprland)
  Mod+T { spawn "kitty"; }
  Mod+R { spawn-sh "noctalia msg panel-toggle launcher"; }
  Mod+C { close-window; }
  Mod+Shift+E { quit; }

  // Noctalia
  Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
  Mod+S { spawn-sh "noctalia msg panel-toggle control-center"; }
  Mod+Shift+Comma { spawn-sh "noctalia msg settings-toggle"; }
  XF86AudioRaiseVolume { spawn-sh "noctalia msg volume-up"; }
  XF86AudioLowerVolume { spawn-sh "noctalia msg volume-down"; }
  XF86AudioMute { spawn-sh "noctalia msg volume-mute"; }

  // Navigation (Mod+Minus/Equal sont pris par les espaces de travail 6 en AZERTY)
  Mod+Left { focus-column-left; }
  Mod+Right { focus-column-right; }
  Mod+Up { focus-window-up; }
  Mod+Down { focus-window-down; }
  Mod+Shift+Left { move-column-left; }
  Mod+Shift+Right { move-column-right; }
  Mod+Shift+Up { move-window-up; }
  Mod+Shift+Down { move-window-down; }
  Mod+F { maximize-column; }
  Mod+Shift+F { fullscreen-window; }
  Mod+Ctrl+Left { set-column-width "-10%"; }
  Mod+Ctrl+Right { set-column-width "+10%"; }

  // Captures d'écran
  Print { screenshot; }
  Ctrl+Print { screenshot-screen; }
  Alt+Print { screenshot-window; }

EOF2

      # Mod + [1-9] / Mod + Shift + [1-9] : niri compare le symbole de la touche SANS Shift.
      # Sur AZERTY, la rangée des chiffres donne & é " ' ( - è _ ç.
      azerty_digits=(ampersand eacute quotedbl apostrophe parenleft minus egrave underscore ccedilla)
      for i in {1..9}; do
        key="${azerty_digits[$((i - 1))]}"
        echo "  Mod+$key { focus-workspace $i; }" >> "$niri_conf"
        echo "  Mod+Shift+$key { move-window-to-workspace $i; }" >> "$niri_conf"
      done

      if [ "$is_vm" -eq 1 ]; then
        echo "" >> "$niri_conf"
        echo "  // Terminal de secours qui n'utilise pas OpenGL (si kitty ne démarre pas)" >> "$niri_conf"
        echo '  Mod+Shift+T { spawn "foot"; }' >> "$niri_conf"
      fi
      echo "}" >> "$niri_conf"

      niri validate || echo "[!] La config niri a une erreur : corrigez ~/.config/niri/config.kdl"
    fi
  fi
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo -e "\n=== CERTAINS ÉLÉMENTS ONT ÉCHOUÉ ==="
  printf '  - %s\n' "${FAILED[@]}"
  echo "Relance-les à la main ou relance le script (les paquets déjà installés sont ignorés)."
fi

echo -e "\n=== INSTALLATION FEDORA TERMINÉE ! Redémarrez pour démarrer sur votre session graphique. ==="
echo "Sur l'écran SDDM, choisissez la session niri (ou Hyprland). Sans SDDM : 'niri-session' depuis le TTY."
echo "Vérifs : nvidia-smi, cat /sys/module/nvidia_drm/parameters/modeset (Y), wpctl status."
