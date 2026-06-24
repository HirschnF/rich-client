#!/usr/bin/env bash
# =============================================================================
# update-namespace.sh
# Zweck  : Ersetzt den Namespace in values.yaml global (alle Vorkommen,
#           inkl. Kommentare und URLs) und startet danach keycloak-setup.sh
# Autor  : Frank Hirschner, USU Software GmbH
# Version: 1.0
# Datum  : 2026-06-16
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/../jetty-helm/values.yaml"
SECRETS_FILE="${SCRIPT_DIR}/../../secrets.yaml"

# ---------------------------------------------------------------------------
# 1. Prüfen ob values.yaml existiert
# ---------------------------------------------------------------------------
if [[ ! -f "$VALUES_FILE" ]]; then
  echo "FEHLER: values.yaml nicht gefunden unter: $VALUES_FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Aktuellen Namespace auslesen (erste aktive namespace:-Zeile)
# ---------------------------------------------------------------------------
OLD_NS=$(grep -E '^namespace:' "$VALUES_FILE" | head -1 | awk '{print $2}' | tr -d '"'"'")

if [[ -z "$OLD_NS" ]]; then
  echo "FEHLER: Kein aktiver 'namespace:'-Eintrag in values.yaml gefunden." >&2
  exit 1
fi

echo "Aktueller Namespace : $OLD_NS"

# ---------------------------------------------------------------------------
# 3. Neuen Namespace abfragen
# ---------------------------------------------------------------------------
read -rp "Neuer Namespace     : " NEW_NS

if [[ -z "$NEW_NS" ]]; then
  echo "FEHLER: Kein neuer Namespace eingegeben." >&2
  exit 1
fi

if [[ "$OLD_NS" == "$NEW_NS" ]]; then
  #echo "INFO: Alter und neuer Namespace sind identisch – nichts zu tun."
  echo "INFO: Alter und neuer Namespace sind identisch – nichts zu tun."
  #exit 0
fi

# ---------------------------------------------------------------------------
# 4. Backup anlegen
# ---------------------------------------------------------------------------
BACKUP="${VALUES_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
cp "$VALUES_FILE" "$BACKUP"
echo "Backup erstellt     : $BACKUP"

# ---------------------------------------------------------------------------
# 5. Globales Ersetzen (alle Vorkommen, auch in Kommentaren und URLs)
# ---------------------------------------------------------------------------
sed -i "s|${OLD_NS}|${NEW_NS}|g" "$VALUES_FILE"

COUNT=$(grep -c "${NEW_NS}" "$VALUES_FILE" || true)
echo "Zeilen aktualisiert : $COUNT (inkl. Kommentare und URLs)"

# ---------------------------------------------------------------------------
# 5.1 Optional: secrets.yaml auslesen
if [[ -f "$SECRETS_FILE" ]]; then
  echo ""
  echo "Keycloak-Admin - Inhalt von secrets.yaml:"
  cat "$SECRETS_FILE" | grep -i "uumKeycloakAdminPass:"
else
  echo ""
  echo "WARNUNG: secrets.yaml nicht gefunden unter: $SECRETS_FILE – überspringe Anzeige."
fi
# ---------------------------------------------------------------------------
# 6. Username aus neuem Namespace extrahieren (zweites Segment: consult-USER-YEAR)
# ---------------------------------------------------------------------------
USERNAME=$(echo "$NEW_NS" | cut -d'-' -f2)

if [[ -z "$USERNAME" ]]; then
  echo "WARNUNG: Konnte keinen Username aus '$NEW_NS' extrahieren – keycloak-setup.sh ohne --user starten."
  read -rp "Bitte geben Sie den Username ein: " USERNAME
fi

# ---------------------------------------------------------------------------
# 7. keycloak-setup.sh starten
# ---------------------------------------------------------------------------
KEYCLOAK_SCRIPT="${SCRIPT_DIR}/keycloak-setup.sh"

if [[ ! -f "$KEYCLOAK_SCRIPT" ]]; then
  echo "FEHLER: keycloak-setup.sh nicht gefunden unter: $KEYCLOAK_SCRIPT" >&2
  exit 1
fi

echo ""
echo "Starte keycloak-setup.sh --user ${USERNAME} ..."
echo "─────────────────────────────────────────────────────"
bash "$KEYCLOAK_SCRIPT" --user "$USERNAME"
