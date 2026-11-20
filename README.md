# clover-desktop

Mon dépôt de post-installation pour mes deux machines du quotidien. Tout ce qu'il faut pour repartir de zéro en quelques commandes :

- **`drainda` (Windows)** : l'anti-magie. Il vire le bloatware et la télémétrie, installe les outils via Scoop et WinGet, et donne un bureau qui se pilote au clavier.
- **`dispelda` (Fedora Everything)** : la magie. On part d'une installation minimale, sans interface, pour construire un bureau Wayland léger, rapide et compatible Secure Boot.

---

## Structure du dépôt

```text
clover/
├── drainda/
│   └── drainda.ps1      # Windows (Scoop + WinGet + Unbloat)
├── dispelda/
│   └── dispelda.sh      # Fedora Everything (DNF + Flatpak + Brew + Wayland)
├── dotfiles/            # Une config par application, copiée par les scripts
│   └── zed/
│       └── settings.json
└── README.md
```

`dotfiles/` est la source de vérité des configs : les scripts y piochent ce dont ils ont besoin, une application par dossier. Pour l'instant, il ne contient que Zed. Les dossiers `keybinds/`, `wallpapers/` et `scripts/` mentionnés plus bas sont prévus mais pas encore créés.

## Déploiement, de zéro à opérationnel

### Étape 1 : installer les paquets et configurer l'OS

Clone ce dépôt sur la machine toute neuve, puis lance le script de ton OS. Un menu te laisse choisir les modules (Core, Dev/SecOps, Ricing, Drivers, Unbloat...).

#### Windows

Ouvre un terminal PowerShell **normal**, pas administrateur. Scoop refuse de s'installer dans un terminal élevé, et plusieurs applis (Rio, Claude Code) font pareil. Le script s'arrête d'ailleurs tout seul s'il détecte des droits admin. Seul le module Unbloat a besoin d'élévation : il ouvre sa propre fenêtre et te demande la validation UAC au moment voulu.

Pour pouvoir lancer des scripts `.ps1`, autorise-les une fois pour ton compte. Ce réglage est permanent et ne touche pas aux autres utilisateurs :

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Pour vérifier ce qui est en place :

```powershell
Get-ExecutionPolicy -List
```

Avec `RemoteSigned`, les scripts locaux tournent sans souci. Ceux qui viennent d'Internet (un zip téléchargé, par exemple) doivent être signés ou débloqués. Un `git clone` n'a pas ce problème, mais si Windows râle, débloque le fichier :

```powershell
Unblock-File .\drainda\drainda.ps1
```

Si tu préfères ne rien changer de façon durable, tu peux aussi lancer le script pour une seule session :

```powershell
powershell -ExecutionPolicy Bypass -File .\drainda\drainda.ps1
```

Le lancement normal :

```powershell
.\drainda\drainda.ps1
```

Ce que le script ajoute côté Windows, au-delà des applis :

- **Visual C++ Redistributable** (`Microsoft.VCRedist.2015+.x64` via WinGet) : sans lui, Rio et d'autres programmes plantent avec « MSVCP140.dll introuvable ». L'installeur demande la validation UAC.
- **Fichiers de config** générés (GlazeWM, Rio, Nushell) écrits en UTF-8 sans BOM. Windows PowerShell 5.1 en ajoute un par défaut, et des parseurs stricts comme celui de GlazeWM s'y cassent.

À la fin, le script affiche la liste des paquets qui ont échoué, s'il y en a. Certains installeurs demandent des droits admin (ASIO4ALL, Podman Desktop) : relance-les à la main dans ce cas.

#### Fedora Everything

```sh
chmod +x ./dispelda/dispelda.sh
./dispelda/dispelda.sh
```

Si les pilotes Nvidia ont été installés avec Secure Boot actif, valide l'enregistrement de la clé MOK sur l'écran bleu au redémarrage, sinon le driver ne se chargera pas.

### Étape 2 : déployer les dotfiles

Une fois les paquets en place, copie ou lie les fichiers de configuration depuis `dotfiles/` vers leur emplacement :

| Application | OS | Emplacement cible |
| --- | --- | --- |
| Nushell | Windows et Linux | `%APPDATA%\nushell\config.nu` ou `~/.config/nushell/config.nu` |
| Starship | Windows et Linux | `~/.config/starship.toml` |
| Zed | Windows et Linux | `%APPDATA%\Zed\settings.json` ou `~/.config/zed/settings.json` |
| Rio | Windows | `%LOCALAPPDATA%\rio\config.toml` |
| GlazeWM et Zebar | Windows | `~/.glzr/glazewm/config.yaml` et `~/.glzr/zebar/` |
| Kitty | Linux | `~/.config/kitty/kitty.conf` |
| Hyprland ou Niri | Linux | `~/.config/hypr/hyprland.conf` ou `~/.config/niri/config.kdl` |
| Caelestia ou Noctalia | Linux | `~/.config/quickshell/` |

### Étape 3 : les raccourcis clavier

Les scripts écrivent eux-mêmes ces raccourcis dans la config de GlazeWM (Windows) et d'Hyprland ou Niri (Linux). Ils sont identiques partout, histoire de ne pas réfléchir en changeant de machine. « Super » est la touche Windows.

| Raccourci | Action |
| --- | --- |
| `Super + T` | Ouvrir le terminal (Rio sur Windows, Kitty sur Fedora) |
| `Super + R` | Ouvrir le lanceur d'applications (Flow Launcher sur Windows, Noctalia avec Niri, fuzzel avec Hyprland) |
| `Super + C` | Fermer la fenêtre active |
| `Super + [1-9]` | Aller à l'espace de travail 1 à 9 |
| `Super + Shift + [1-9]` | Envoyer la fenêtre active vers l'espace de travail 1 à 9 |
| `Super + Shift + E` | Quitter la session (GlazeWM, Hyprland ou Niri) |

Sur Fedora, le clavier est en AZERTY partout (console, écran de connexion SDDM, Hyprland et Niri). Les chiffres demandent Shift sur AZERTY, donc les raccourcis d'espaces de travail sont écrits autrement :

- **Hyprland** utilise les codes de touches (`code:10` à `code:18`), qui ne dépendent pas de la disposition. Tu appuies simplement sur `Super + &`, `é`, `"`, etc., sans Shift.
- **Niri** compare le symbole de la touche sans Shift : les raccourcis sont écrits `Mod+ampersand`, `Mod+eacute`, `Mod+quotedbl`, `Mod+apostrophe`, `Mod+parenleft`, `Mod+minus`, `Mod+egrave`, `Mod+underscore` et `Mod+ccedilla`. Si l'un d'eux ne répond pas, lance `wev` pour lire le nom exact de la touche.

Sous Windows, `Super + T`, `Super + R` et `Super + [1-9]` ont déjà un sens (barre des tâches, fenêtre Exécuter). GlazeWM les intercepte tant qu'il tourne ; s'il est fermé, Windows reprend la main.

La config de Zed (`dotfiles/zed/settings.json`) est copiée par les deux scripts. Si un `settings.json` différent existe déjà, il est sauvegardé à côté en `settings.json.bak-<date>` avant d'être remplacé. L'indentation est à `tab_size: 2` avec `hard_tabs: true` (des tabulations d'une largeur de 2).

### Étape 4 : les fonds d'écran

- **Windows** : applique à la main, ou avec un script PowerShell, un fond sombre et minimaliste assorti à Zebar et Rio.
- **Fedora** : configure le démon de fond d'écran Wayland (swww, ou celui de Caelestia / Noctalia) pour qu'il pointe sur `wallpapers/`.

### Étape 5 : alias, scripts et tâches planifiées

1. **Alias Nushell** (`aliases.nu`) : à sourcer dans `config.nu` pour avoir les mêmes commandes partout (`k` pour kubectl, `tf` pour terraform, `lg` pour lazygit, `cat` vers bat, etc.).
2. **Scripts utilitaires** : nettoyage rapide des conteneurs Podman et des clusters k3d locaux, audit des programmes lancés au démarrage sous Windows (Autoruns ou PowerShell).
3. **Automatisation** :
   - Linux : crontab ou timers systemd utilisateur pour mettre à jour brew et flatpak et nettoyer le cache.
   - Windows : une tâche planifiée hebdomadaire qui lance `scoop update *` en silence.

## Ce que le script Fedora règle pour que le bureau marche tout seul

Au-delà des paquets, `dispelda.sh` s'occupe des détails qu'on oublie d'habitude.

**Carte graphique** : le module Drivers lit `lspci` et choisit le driver selon la génération. Si la puce n'est pas reconnue, il te demande quoi installer.

| Série | Driver |
| --- | --- |
| RTX 20/30/40/50, GTX 16 | `akmod-nvidia` |
| GTX 750, 9xx, 10xx | `akmod-nvidia-580xx` (jamais `akmod-nvidia`, qui ne gère plus Pascal) |
| GTX 6xx, 7xx | `akmod-nvidia-470xx` (Wayland très limité) |
| Plus ancien | nouveau, rien à installer |
| AMD, Intel | Mesa, déjà inclus dans Fedora |

Pour une Nvidia, le script ajoute aussi les libs 32 bits pour Steam, `nvidia-drm.modeset=1` et un profil qui évite que niri avale environ 1 Gio de VRAM. Il attend la fin de la compilation du module avant de te laisser redémarrer.

| Sujet | Ce qui est mis en place |
| --- | --- |
| Secure Boot | La clé MOK n'est générée que si Secure Boot est actif. Au reboot, écran bleu : *Enroll MOK*, *Continue*, *Yes*, mot de passe, *Reboot*. |
| Wi-Fi et Bluetooth Intel (AX210) | Si une carte Intel est détectée : firmwares `iwlwifi-mvm-firmware` et `iwlbluetooth-firmware`, NetworkManager et bluez activés. |
| Applis X11 (Steam, Proton) | `xwayland-satellite`, lancé automatiquement par niri. |
| Partage d'écran | `xdg-desktop-portal-gnome`. |
| Sélecteurs de fichiers | `xdg-desktop-portal-gtk`. |
| Mots de passe et privilèges | `gnome-keyring` et un agent polkit, lancés au démarrage de la session. |
| Noctalia | Démarrée par niri, avec les raccourcis du panneau de contrôle, des réglages et du volume, et une règle pour ouvrir ses fenêtres en flottant. |
| Hyprland et Niri | Au choix, ou les deux à la fois : à la question du script, tape `1`, `2` ou `1 2` (Entrée = les deux). SDDM te laisse choisir la session au login. |
| Écran de connexion | SDDM avec son greeter X11, en AZERTY (`localectl set-x11-keymap fr`). La console (TTY) passe aussi en AZERTY. |
| Machine virtuelle | Détectée automatiquement. Le script installe alors `open-vm-tools` (sous VMware), `mesa-demos` pour `glxinfo`, `foot` comme terminal de secours (`Super + Shift + T`) et règle le curseur logiciel dans Hyprland. |
| Polices | Noto (texte et emoji) et JetBrains Mono. |

Niri a aussi des raccourcis de navigation : `Super + flèches` pour passer d'une colonne ou d'une fenêtre à l'autre, `Super + Shift + flèches` pour les déplacer, `Super + F` pour maximiser, `Print` pour les captures d'écran. Niri et Noctalia ne sont dans les dépôts officiels qu'à partir de Fedora 44 ; en dessous, le script saute cette étape.

### Dépannage

Windows :

| Symptôme | Piste |
| --- | --- |
| Rio ne s'ouvre pas, « MSVCP140.dll introuvable » | Installe le runtime : `winget install Microsoft.VCRedist.2015+.x64` |
| GlazeWM dit que la config est invalide | Vérifie que le fichier est en UTF-8 sans BOM, puis relance le script (il sauvegarde l'ancienne config dans `~/.glzr/backups/`) |

Fedora :

| Symptôme | Piste |
| --- | --- |
| Écran noir au lancement de niri | Modesetting à `N` ou module Nvidia absent : `cat /sys/module/nvidia_drm/parameters/modeset` et `lsmod \| grep nvidia` |
| Nvidia perdu après une mise à jour du noyau | Le module se recompile au démarrage. Patiente, ou `sudo akmods --force` puis redémarre |
| `dnf` veut installer un driver 59x | `akmod-nvidia` a été installé par erreur : `sudo dnf remove akmod-nvidia` |
| Paquets 580xx introuvables | Le dépôt `rpmfusion-nonfree` complet n'est pas activé |
| Pas de Wi-Fi | `sudo dmesg \| grep iwlwifi` : une erreur de firmware veut dire que `iwlwifi-mvm-firmware` manque |
| Deux barres à l'écran | Une ligne `spawn-at-startup "waybar"` traîne dans la config niri |
| Kitty ne se lance pas dans une VM | Voir la section VMware ci-dessous |

### Fedora dans VMware Workstation

Dans une VM, Fedora ne voit pas ta carte Nvidia : VMware présente une carte virtuelle (« VMware SVGA ») et le script n'installe donc aucun driver Nvidia, ce qui est normal. Ta RTX 5060 ne sert qu'à VMware, qui traduit la 3D de l'invité vers Windows.

Réglages côté VMware (VM éteinte), dans *Paramètres de la machine virtuelle*, onglet *Affichage* :

- Coche **Accélérer les graphismes 3D**. C'est le point le plus important : sans lui, il n'y a pas de pilote 3D et les applis OpenGL comme Kitty ont du mal à démarrer.
- Monte la **mémoire graphique** au maximum proposé.
- Donne à la VM au moins 4 cœurs et 8 Go de RAM.
- Garde VMware Workstation et le pilote Nvidia de Windows à jour (une RTX 50 demande des versions récentes des deux).

Dans Fedora, vérifie que la 3D est active :

```sh
glxinfo -B | grep -E "OpenGL renderer|OpenGL version"
```

« SVGA3D » ou « vmwgfx » dans le renderer est bon signe. « llvmpipe » signifie que la 3D est émulée par le processeur : relis les réglages ci-dessus.

Si Kitty ne s'ouvre pas dans Hyprland, ouvre une console (`Ctrl + Alt + F3`), connecte-toi, puis lance Kitty depuis la session pour lire l'erreur :

```sh
HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$(id -u)/hypr | head -n1) \
  hyprctl dispatch exec 'sh -c "kitty > /tmp/kitty.log 2>&1"'
cat /tmp/kitty.log
```

En attendant, `Super + Shift + T` ouvre `foot`, un terminal qui n'a pas besoin d'OpenGL.

### Réinitialiser Windows sans perdre Fedora

Une réinitialisation de Windows ne touche pas aux partitions Fedora, mais elle remet presque toujours le gestionnaire de démarrage Windows en premier. Fedora est toujours là, il faut juste lui rendre la priorité.

- **Avant** : depuis Fedora, note les disques avec `lsblk -f` et l'entrée de démarrage avec `sudo efibootmgr -v`.
- **Pendant** : avec « Réinitialiser ce PC » puis *Supprimer tout*, vérifie que « Supprimer les fichiers de tous les lecteurs ? » est sur **Non**. Avec une clé USB, débranche le SSD Fedora ou ne supprime que les partitions du disque Windows.
- **Après** : choisis Fedora dans le menu de démarrage (F11 sur MSI), puis `sudo efibootmgr -o 0001,0000` (numéros à adapter, Fedora en premier).
- **Entrée Fedora disparue** : depuis une clé live Fedora, `sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Fedora" --loader '\EFI\fedora\shimx64.efi'` (disque et partition à adapter).
- **Partition EFI formatée** : depuis la clé live, monte le système, fais un `chroot`, puis `dnf reinstall shim-x64 grub2-efi-x64 grub2-common` et `grub2-mkconfig -o /boot/grub2/grub.cfg`.

## Checklist après l'installation

- [ ] Vérifier les programmes lancés au démarrage sous Windows (Gestionnaire des tâches, onglet Démarrage, ou Autoruns)
- [ ] Se connecter aux outils en ligne de commande (`gh auth login`, `az login`, `claude`)
- [ ] Vérifier que la police JetBrainsMono Nerd Font est bien prise en compte dans Rio, Kitty et Zed
- [ ] Tester la création d'un cluster k3d local avec Podman
