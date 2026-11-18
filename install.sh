#!/usr/bin/env bash
# Instala o GameKill para o usuario atual (sem root).
# Parte de sistema (opcional, root): sudo ~/.config/gamekill/system/install-system.sh
set -euo pipefail
cd "$(dirname "$0")"

BIN="$HOME/.local/bin"
CFG="$HOME/.config/gamekill"
UNITS="$HOME/.config/systemd/user"
APPS="$HOME/.local/share/applications"

# Servicos do KDE/audio que o systemd-oomd nunca deve escolher como vitima
PROTECTED_UNITS=(dbus-broker pipewire pipewire-pulse plasma-kded6 plasma-ksmserver
                 plasma-kwin_wayland plasma-plasmashell plasma-xdg-desktop-portal-kde
                 gamekill-watchdog)

install -Dm755 bin/gamekill bin/gamekill-watchdog -t "$BIN"
install -Dm755 config/pre-recovery -t "$CFG"
[[ -e "$CFG/protected-appids" ]] || install -Dm644 config/protected-appids -t "$CFG"
install -Dm755 system/install-system.sh -t "$CFG/system"
install -Dm644 README.md -t "$CFG"

install -Dm644 systemd/gamekill-watchdog.service -t "$UNITS"
install -Dm644 systemd/session.slice.d/90-gamekill-protect.conf -t "$UNITS/session.slice.d"
for u in "${PROTECTED_UNITS[@]}"; do
    install -Dm644 systemd/service-protect/90-gamekill-protect.conf -t "$UNITS/$u.service.d"
done

mkdir -p "$APPS"
sed "s#@BINDIR@#$BIN#" applications/gamekill-now.desktop > "$APPS/gamekill-now.desktop"

systemctl --user daemon-reload
systemctl --user enable --now gamekill-watchdog.service

echo "GameKill instalado. Verifique com: gamekill-watchdog --status"
echo "Protecao de sistema (opcional): sudo $CFG/system/install-system.sh"
