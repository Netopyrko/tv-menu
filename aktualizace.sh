#!/bin/bash
# Nastaví na ZBOXu automatickou aktualizaci stránky s menu z GitHubu (stačí spustit jednou).
#
# Spuštění na ZBOXu (musí mít internet):
#   curl -fsSL https://raw.githubusercontent.com/Netopyrko/tv-menu/main/aktualizace.sh | sudo bash
#
# Z GitHubu se aktualizuje JEN stránka (index.html), která běží v prohlížeči – nic, co by
# běželo s právy roota. Tenhle skript i časovač zůstávají na ZBOXu pevně.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Spusť jako root:  ... | sudo bash" >&2
  exit 1
fi

cat > /usr/local/bin/tv-menu-aktualizace <<'EOF'
#!/bin/bash
# Stáhne aktuální stránku s menu z GitHubu; když se změnila, nahradí ji a restartuje prohlížeč.
set -euo pipefail
ZDROJ="https://raw.githubusercontent.com/Netopyrko/tv-menu/main/index.html"
CIL=/opt/tv-menu/index.html
NOVA="$(mktemp)"
trap 'rm -f "$NOVA"' EXIT

curl -fsS --max-time 60 -o "$NOVA" "$ZDROJ?t=$(date +%s)"

# Pojistka: nahradit jen celou stránkou s menu, ne chybovou stránkou ani useknutým souborem
if ! grep -q 'tv-menu-posledni' "$NOVA" || ! grep -q '</html>' "$NOVA"; then
  echo "Stažený soubor nevypadá jako stránka s menu – nic neměním" >&2
  exit 1
fi

if ! cmp -s "$NOVA" "$CIL"; then
  install -m 644 "$NOVA" "$CIL"
  echo "Stránka aktualizována – restartuji prohlížeč"
  pkill -u kiosk chromium || true
fi
EOF
chmod 755 /usr/local/bin/tv-menu-aktualizace

cat > /etc/systemd/system/tv-menu-aktualizace.service <<'EOF'
[Unit]
Description=TV menu - aktualizace stranky z GitHubu
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tv-menu-aktualizace
EOF

cat > /etc/systemd/system/tv-menu-aktualizace.timer <<'EOF'
[Unit]
Description=TV menu - kontrola nove stranky kazdych 15 minut

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now tv-menu-aktualizace.timer

echo "Časovač nastaven – stránka se kontroluje po startu a pak každých 15 minut."
echo "Teď ji zkusím aktualizovat hned:"
/usr/local/bin/tv-menu-aktualizace || echo "(aktualizace se nepovedla – zkusí se znovu za 15 minut)"
