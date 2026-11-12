# 🍀 clover-desktop

Mon dépôt de **Configuration-as-Code** et de post-installation pour mes deux environnements de travail au quotidien :

* **🛡️ `drainda` (Windows)** — *Zone d'anti-magie.* Pensée pour purger le bloatware et la télémétrie de Windows, isoler proprement les outils via Scoop et retrouver un workflow pilotable au clavier.
* **✨ `dispelda` (Fedora Everything)** — *Zone infusée de magie.* Partie d'une installation minimale sans interface graphique pour bâtir un bureau Wayland sur-mesure, léger, rapide et compatible *Secure Boot*.

---

## 🗂️ Structure du dépôt

```text
clover-desktop/
├── drainda/                 # Windows (Scoop + WinGet + Unbloat)
│   └── setup.ps1
├── dispelda/                # Fedora Everything (DNF + Flatpak + Brew + Wayland)
│   └── setup-fedora.sh
├── dotfiles/                # Configurations par application (cross-OS & spécifiques)
├── keybinds/                # Raccourcis clavier (WM, terminaux, éditeurs)
├── wallpapers/              # Fonds d'écran
├── scripts/                 # Scripts custom, tâches planifiées (cron) et alias Nushell
└── README.md
```

## 🚀 Étapes de déploiement (De zéro à opérationnel)

### Étape 1 : Bootstrap de l'OS
1. Cloner ce dépôt sur la machine fraîchement installée.
2. Lancer le script correspondant à l'OS et sélectionner les modules souhaités dans le menu interactif (Core, Dev/SecOps, Ricing, Drivers, Unbloat...) :

- Sur Windows (drainda) :
```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\drainda\setup.ps1
```
- Sur Fedora Everything (dispelda) :
```sh
chmod +x ./dispelda/setup-fedora.sh
./dispelda/setup-fedora.sh
```
3. (Linux uniquement) Si les pilotes Nvidia ont été installés, valider l'enregistrement de la clé MOK sur l'écran bleu au redémarrage pour conserver le Secure Boot actif.

### Étape 2 : Déployer les Dotfiles par application

Une fois les paquets installés, lier ou copier les fichiers de configuration depuis dotfiles/ vers leurs emplacements respectifs :

Application,OS,Emplacement cible
Nushell,Windows & Linux,%APPDATA%\nushell\config.nu / ~/.config/nushell/config.nu
Starship,Windows & Linux,~/.config/starship.toml
Zed,Windows & Linux,%APPDATA%\Zed\settings.json / ~/.config/zed/settings.json
Rio,Windows,%LOCALAPPDATA%\rio\config.toml
GlazeWM & Zebar,Windows,~/.glzr/glazewm/config.yaml & ~/.glzr/zebar/
Kitty,Linux,~/.config/kitty/kitty.conf
Hyprland / Niri,Linux,~/.config/hypr/hyprland.conf ou ~/.config/niri/config.kdl
Caelestia / Noctalia,Linux,~/.config/quickshell/

### Étape 3 : Appliquer les raccourcis clavier (keybinds/)

Les scripts écrivent eux-mêmes ces raccourcis dans la config de GlazeWM (Windows) et d'Hyprland ou Niri (Linux). Ce sont les mêmes partout, pour ne pas avoir à réfléchir en changeant de machine. « Super » correspond à la touche Windows.

| Raccourci | Action |
| --- | --- |
| `Super + T` | Ouvrir le terminal (Rio sur Windows, Kitty sur Fedora) |
| `Super + R` | Ouvrir le lanceur d'applications (Flow Launcher sur Windows, Noctalia avec Niri, fuzzel avec Hyprland) |
| `Super + C` | Fermer la fenêtre active |
| `Super + [1-9]` | Aller à l'espace de travail 1 à 9 |
| `Super + Shift + [1-9]` | Envoyer la fenêtre active vers l'espace de travail 1 à 9 |
| `Super + Shift + E` | Quitter la session (GlazeWM, Hyprland ou Niri) |

Petite précision pour Windows : `Super + T`, `Super + R` et `Super + [1-9]` ont déjà un sens dans Windows (barre des tâches, fenêtre Exécuter). GlazeWM les intercepte tant qu'il tourne. S'il est fermé, Windows reprend la main.

Zed est configuré avec une indentation de 2 espaces, y compris pour Python et Rust, qui en utilisent 4 par défaut. Les scripts ne créent le `settings.json` que s'il n'existe pas, afin de ne pas écraser ta config. S'il est déjà là, ajoute-y `"tab_size": 2` toi-même.

### Étape 4 : Mettre en place les Wallpapers (wallpapers/)

- Sur Windows (drainda) : Appliquer manuellement ou via script PowerShell le fond d'écran sombre/minimaliste assorti au thème Zebar/Rio.

- Sur Fedora (dispelda) : Configurer le daemon de fond d'écran Wayland (swww ou intégré via Caelestia / Noctalia Shell) pour pointer vers le dossier wallpapers/.

### Étape 5 : Activer les Custom Scripts, Cron & Alias (scripts/)

1. Alias Nushell (aliases.nu) :
  - Sourcer le fichier d'alias commun dans config.nu pour unifier les commandes sur les deux OS (k pour kubectl, tf pour terraform, lg pour lazygit, cat vers bat, etc.).

2. Scripts utilitaires :
  - Scripts de nettoyage rapide de conteneurs Podman / clusters k3d locaux.
  - Audit rapide des services au démarrage sous Windows (via Autoruns / PowerShell).

3. Automatisation / Cron :
  - Linux (crontab ou timers systemd utilisateur) : Mise à jour périodique des paquets brew, flatpak et nettoyage du cache.
  - Windows (Planificateur de tâches) : Mise à jour silencieuse hebdomadaire via scoop update *.

## 🖥️ Ce que le script Fedora met en place pour que le bureau marche tout seul

Au-delà des paquets, `dispelda.sh` règle les détails qu'on oublie d'habitude :

- **Carte graphique** : le module Drivers lit `lspci` et choisit le driver selon la génération. Si la puce n'est pas reconnue, il te demande quoi installer.

  | Série | Driver |
  | --- | --- |
  | RTX 20/30/40/50, GTX 16 | `akmod-nvidia` |
  | GTX 750, 9xx, 10xx | `akmod-nvidia-580xx` (jamais `akmod-nvidia`, qui ne gère plus Pascal) |
  | GTX 6xx, 7xx | `akmod-nvidia-470xx` (Wayland très limité) |
  | Plus ancien | nouveau, rien à installer |
  | AMD, Intel | Mesa, déjà inclus dans Fedora |

  Pour une Nvidia, le script ajoute les libs 32 bits pour Steam, `nvidia-drm.modeset=1` et un profil qui évite que niri avale ~1 Gio de VRAM. Il attend la fin de la compilation du module avant de te laisser redémarrer.
- **Secure Boot** : la clé MOK n'est générée que si Secure Boot est actif. Au reboot, écran bleu : *Enroll MOK* → *Continue* → *Yes* → mot de passe → *Reboot*.
- **Wi-Fi et Bluetooth Intel (AX210)** : si une carte Wi-Fi Intel est détectée, firmwares `iwlwifi-mvm-firmware` et `iwlbluetooth-firmware`, plus NetworkManager et bluez activés.
- **Applis X11 (Steam, Proton)** : `xwayland-satellite`, lancé automatiquement par niri.
- **Partage d'écran** : `xdg-desktop-portal-gnome`. **Sélecteurs de fichiers** : `xdg-desktop-portal-gtk`.
- **Mots de passe et privilèges** : `gnome-keyring` et un agent polkit lancés au démarrage de la session.
- **Noctalia** : démarrée par niri, avec les raccourcis du panneau de contrôle, des réglages et du volume, et une règle pour ouvrir ses fenêtres en flottant.
- **Écran de connexion** : SDDM, avec choix de session niri ou Hyprland.
- **Polices** : Noto (texte et emoji) et JetBrains Mono.

Niri a aussi des raccourcis de navigation (`Super + flèches` pour changer de colonne ou de fenêtre, `Super + Shift + flèches` pour les déplacer, `Super + F` pour maximiser, `Print` pour les captures d'écran). Niri et Noctalia ne sont dans les dépôts officiels qu'à partir de Fedora 44 ; en dessous, le script saute cette étape.

### Dépannage

| Symptôme | Piste |
| --- | --- |
| Écran noir au lancement de niri | Modesetting à `N` ou module Nvidia absent : `cat /sys/module/nvidia_drm/parameters/modeset` et `lsmod \| grep nvidia` |
| Nvidia perdu après une mise à jour du noyau | Le module se recompile au boot. Patiente, ou `sudo akmods --force` puis redémarre |
| `dnf` veut installer un driver 59x | `akmod-nvidia` a été installé par erreur : `sudo dnf remove akmod-nvidia` |
| Paquets 580xx introuvables | Le dépôt `rpmfusion-nonfree` complet n'est pas activé |
| Pas de Wi-Fi | `sudo dmesg \| grep iwlwifi` : une erreur de firmware veut dire que `iwlwifi-mvm-firmware` manque |
| Deux barres à l'écran | Une ligne `spawn-at-startup "waybar"` traîne dans la config niri |

### Réinitialiser Windows sans perdre Fedora

Une réinitialisation de Windows laisse les partitions Fedora tranquilles, mais remet presque toujours le gestionnaire de démarrage Windows en premier. Fedora est toujours là, il faut juste lui rendre la priorité.

- **Avant** : depuis Fedora, note les disques avec `lsblk -f` et l'entrée de démarrage avec `sudo efibootmgr -v`.
- **Pendant** : avec « Réinitialiser ce PC » → *Supprimer tout*, vérifie que « Supprimer les fichiers de tous les lecteurs ? » est sur **Non**. Avec une clé USB, débranche le SSD Fedora ou ne supprime que les partitions du disque Windows.
- **Après** : choisis Fedora dans le menu de boot (F11 sur MSI), puis `sudo efibootmgr -o 0001,0000` (numéros à adapter, Fedora en premier).
- **Entrée Fedora disparue** : depuis une clé live Fedora, `sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Fedora" --loader '\EFI\fedora\shimx64.efi'` (disque et partition à adapter).
- **Partition EFI formatée** : depuis la clé live, monte le système, fais un `chroot`, puis `dnf reinstall shim-x64 grub2-efi-x64 grub2-common` et `grub2-mkconfig -o /boot/grub2/grub.cfg`.

## 📝 Checklist post-installation

- [ ] Vérifier les programmes au démarrage sous Windows (Gestionnaire des tâches > Démarrage ou autoruns)
- [ ] Authentifier les outils CLI (gh auth login, az login, claude)
- [ ] Vérifier la détection des polices JetBrainsMono Nerd Font dans Rio / Kitty et Zed
- [ ] Tester la création d'un cluster local k3d avec Podman