#!/usr/bin/env bash
# GameKill - protecao em nivel de sistema (precisa de root).
#
#   sudo ~/.config/gamekill/system/install-system.sh               instala
#   sudo ~/.config/gamekill/system/install-system.sh --anti-freeze instala + MGLRU anti-travamento
#   sudo ~/.config/gamekill/system/install-system.sh --uninstall   remove tudo
#
# O que faz e por que:
#  1. systemd-oomd: hoje ele vigia user-UID.slice (dono = root). Nesse nivel
#     ele IGNORA o "ManagedOOMPreference=omit" dos servicos do KDE, porque
#     esses cgroups pertencem ao seu usuario -> ele pode matar o KWin e
#     derrubar a sessao inteira. Movemos a vigilancia de pressao para
#     user@UID.service (dono = seu usuario), onde o omit do KDE e respeitado.
#     A vigilancia por swap e desligada no slice do usuario (ela nunca
#     respeita omit em cgroups de usuario); o GameKill (swap 85% + pressao)
#     e o OOM do kernel (que prefere o jogo, oom_score_adj=700) cobrem isso.
#  2. MemoryLow=1200M no user@.service: permite que o KDE (session.slice,
#     MemoryLow=1G) seja protegido de ir para o swap quando o jogo esgota a RAM.
#  3. kernel.sysrq=244: habilita Alt+PrtSc+F (OOM manual: mata o jogo mesmo
#     com a tela congelada) e REISUB. So funciona no teclado fisico.
#  4. (--anti-freeze) MGLRU min_ttl_ms=1000: em vez de congelar o PC por
#     minutos em thrashing, o kernel age quando nao consegue manter nem 1s
#     de working set. Como o jogo tem o maior oom_score, ele e o escolhido.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Rode com sudo."; exit 1; }

F_SLICE=/etc/systemd/system/user-.slice.d/90-gamekill.conf
F_USER=/etc/systemd/system/user@.service.d/90-gamekill.conf
F_SYSRQ=/etc/sysctl.d/90-gamekill-sysrq.conf
F_MGLRU=/etc/tmpfiles.d/90-gamekill-mglru.conf

if [[ "${1:-}" == --uninstall ]]; then
    rm -fv "$F_SLICE" "$F_USER" "$F_SYSRQ" "$F_MGLRU"
    systemctl daemon-reload
    sysctl -q kernel.sysrq=16 || true
    [[ -w /sys/kernel/mm/lru_gen/min_ttl_ms ]] && echo 0 > /sys/kernel/mm/lru_gen/min_ttl_ms
    systemctl restart systemd-oomd
    echo "Removido. Faca logout/login para voltar ao padrao."
    exit 0
fi

install -Dm644 /dev/stdin "$F_SLICE" <<'EOF'
# GameKill: o oomd nao vigia mais o slice inteiro (nesse nivel ele ignora a
# protecao do KDE). Pressao e vigiada em user@.service (ver 90-gamekill.conf).
[Slice]
ManagedOOMMemoryPressure=auto
ManagedOOMSwap=auto
EOF

install -Dm644 /dev/stdin "$F_USER" <<'EOF'
# GameKill: oomd vigia a pressao aqui, onde ManagedOOMPreference=omit dos
# servicos do KDE e respeitado. Limite igual ao padrao do sistema (80%/30s).
[Service]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=80%
# Permite protecao de memoria (memory.low) para o KDE dentro da sessao.
MemoryLow=1200M
EOF

install -Dm644 /dev/stdin "$F_SYSRQ" <<'EOF'
# GameKill: 4=teclado 16=sync 32=remount-ro 64=sinais/OOM(F) 128=reboot
# Alt+PrtSc+F = kernel mata o processo com maior oom_score (o jogo).
kernel.sysrq = 244
EOF
sysctl -q -p "$F_SYSRQ"

if [[ "${1:-}" == --anti-freeze ]]; then
    install -Dm644 /dev/stdin "$F_MGLRU" <<'EOF'
# GameKill: protege 1s de working set; evita congelamentos longos por thrashing.
w- /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 1000
EOF
    systemd-tmpfiles --create "$F_MGLRU"
fi

systemctl daemon-reload
systemctl restart systemd-oomd

echo
echo "Instalado. Estado atual:"
for u in /sys/fs/cgroup/user.slice/user-*.slice; do
    s=${u##*/}; uid=${s#user-}; uid=${uid%.slice}
    echo "  $s: $(systemctl show "$s" -p ManagedOOMMemoryPressure -p ManagedOOMSwap --value | tr '\n' ' ')"
    echo "  user@$uid.service: $(systemctl show "user@$uid.service" -p ManagedOOMMemoryPressure -p MemoryLow --value | tr '\n' ' ')"
done
echo "  kernel.sysrq=$(sysctl -n kernel.sysrq)  min_ttl_ms=$(cat /sys/kernel/mm/lru_gen/min_ttl_ms 2>/dev/null)"
echo
echo "Recomendado: faca logout/login (ou reinicie) para tudo valer na sessao."
echo "Depois confira com: gamekill-watchdog --status"
