#!/usr/bin/env bash
#
# keycloak-setup.sh
#
# Setzt die beiden Keycloak-Clients (rc-transfer, rc-guacamole) im angegebenen
# Realm auf und legt den Pod-User mit einem Initial-Passwort an, das bei der
# ersten Anmeldung gewechselt werden muss.
#
# Die Client-Templates rc-transfer.json und rc-guacamole.json liegen neben
# diesem Skript im Repo-Root und enthalten den Platzhalter __HOSTNAME__,
# der hier per envsubst durch die tatsaechliche Ingress-Hostname ersetzt wird.
#
# Beispiel:
#
#   ./scripts/keycloak-setup.sh \
#       --user usifhirsch \
#       --initial-pw "Start2026!" \
#       --hostname rc.consult-usifhirsch-202540.ha.k8s-dev004.aspera.usu.grp \
#       --keycloak-base https://uum-keycloak.consult-usifhirsch-202540.ha.k8s-dev004.aspera.usu.grp/master/auth \
#       --realm master
#
# Admin-User und -Passwort werden interaktiv abgefragt, wenn nicht ueber
# Umgebungsvariablen KC_ADMIN_USER / KC_ADMIN_PASSWORD oder Flags gesetzt.
#
# Voraussetzungen: bash, curl, jq.

set -euo pipefail

# -------- curl-Optionen ----------
# Auf Windows (Git-Bash, MSYS/MINGW/CYGWIN) ist curl gegen Schannel gelinkt
# und schlaegt bei Unternehmensnetzen oft mit CRYPT_E_NO_REVOCATION_CHECK fehl,
# weil der OCSP/CRL-Endpunkt nicht erreichbar ist. --ssl-no-revoke deaktiviert
# die Revocation-Pruefung speziell fuer Schannel.
# Auf Linux/macOS bleibt die Variable leer; ueberschreibbar via Env KC_CURL_OPTS.
CURL_OPTS=()
case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*) CURL_OPTS+=(--ssl-no-revoke) ;;
esac
if [[ -n "${KC_CURL_OPTS:-}" ]]; then
    # whitespace-split in array (intentional)
    read -r -a EXTRA_CURL_OPTS <<<"$KC_CURL_OPTS"
    CURL_OPTS+=("${EXTRA_CURL_OPTS[@]}")
fi

# -------- Defaults ----------
USER_NAME=""
INITIAL_PW=""
HOSTNAME=""
KC_BASE=""
REALM="master"
KC_ADMIN_USER="${KC_ADMIN_USER:-}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-}"
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<EOF
Usage: $0 --user USER [--initial-pw PW] [--hostname HOST] [--keycloak-base URL]
          [--realm REALM] [--admin-user USER] [--admin-password PW]

Required:
  --user           Username des Pod-Nutzers (z.B. usifhirsch)

Optional:
  --initial-pw     Initial-Passwort fuer den Nutzer (Pflicht-Reset bei 1. Login).
                   Default: identisch zum Username.

Optional (sonst aus values.yaml gelesen, falls Datei vorhanden):
  --hostname       Ingress-Hostname (ersetzt __HOSTNAME__ in den JSONs)
  --keycloak-base  Basis-URL der Keycloak-Instanz, z.B.
                   https://uum-keycloak.<ns>.../master/auth
  --realm          Ziel-Realm (default: master)

Admin-Credentials:
  --admin-user / --admin-password   bzw. Env KC_ADMIN_USER / KC_ADMIN_PASSWORD
                                    werden sonst interaktiv abgefragt.
EOF
    exit 1
}

# -------- Argumente parsen ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)            USER_NAME="$2"; shift 2 ;;
        --initial-pw)      INITIAL_PW="$2"; shift 2 ;;
        --hostname)        HOSTNAME="$2"; shift 2 ;;
        --keycloak-base)   KC_BASE="$2"; shift 2 ;;
        --realm)           REALM="$2"; shift 2 ;;
        --admin-user)      KC_ADMIN_USER="$2"; shift 2 ;;
        --admin-password)  KC_ADMIN_PASSWORD="$2"; shift 2 ;;
        -h|--help)         usage ;;
        *) echo "Unknown argument: $1" >&2; usage ;;
    esac
done

# -------- Werte ggf. aus values.yaml ableiten ----------
VALUES_FILE="${TEMPLATE_DIR}/jetty-helm/values.yaml"
if [[ -z "$HOSTNAME" && -f "$VALUES_FILE" ]]; then
    HOSTNAME=$(awk '/^ingress:/{flag=1; next} flag && /^[^[:space:]]/{flag=0} flag && /^[[:space:]]+hostname:/{gsub(/^[[:space:]]+hostname:[[:space:]]*/,""); print; exit}' "$VALUES_FILE" || true)
fi
if [[ -z "$KC_BASE" && -f "$VALUES_FILE" ]]; then
    KC_BASE=$(awk '/^keycloak:/{flag=1; next} flag && /^[^[:space:]]/{flag=0} flag && /^[[:space:]]+url:/{gsub(/^[[:space:]]+url:[[:space:]]*"?/,""); gsub(/"$/,""); print; exit}' "$VALUES_FILE" || true)
fi
NAMESPACE=""
if [[ -f "$VALUES_FILE" ]]; then
    NAMESPACE=$(awk '/^namespace:/{gsub(/^namespace:[[:space:]]*/,""); gsub(/^"|"$/,""); print; exit}' "$VALUES_FILE" || true)
fi

# -------- Pflichtfelder pruefen ----------
[[ -z "$USER_NAME"  ]] && { echo "ERROR: --user fehlt." >&2; exit 1; }
[[ -z "$HOSTNAME"   ]] && { echo "ERROR: --hostname konnte nicht ermittelt werden." >&2; exit 1; }
[[ -z "$KC_BASE"    ]] && { echo "ERROR: --keycloak-base konnte nicht ermittelt werden." >&2; exit 1; }

# Default fuer Initial-Passwort: identisch zum Username.
if [[ -z "$INITIAL_PW" ]]; then
    INITIAL_PW="$USER_NAME"
    INITIAL_PW_FROM_DEFAULT=1
else
    INITIAL_PW_FROM_DEFAULT=0
fi

# Trailing slash am Keycloak-Base entfernen
KC_BASE="${KC_BASE%/}"

# Admin-Credentials interaktiv anfordern falls fehlend
if [[ -z "$KC_ADMIN_USER" ]]; then
    read -r -p "Keycloak Admin-Username: " KC_ADMIN_USER
fi
if [[ -z "$KC_ADMIN_PASSWORD" ]]; then
    read -r -s -p "Keycloak Admin-Passwort: " KC_ADMIN_PASSWORD
    echo
fi

# -------- Tools pruefen ----------
for bin in curl jq helm; do
    command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: '$bin' nicht gefunden." >&2; exit 1; }
done

echo
echo "==> Konfiguration:"
echo "    User:           $USER_NAME"
if [[ $INITIAL_PW_FROM_DEFAULT -eq 1 ]]; then
    echo "    Initial-PW:     $INITIAL_PW   (Default = Username)"
else
    echo "    Initial-PW:     $INITIAL_PW"
fi
echo "    Hostname:       $HOSTNAME"
echo "    Keycloak Base:  $KC_BASE"
echo "    Realm:          $REALM"
echo "    Admin:          $KC_ADMIN_USER"
echo

# -------- 1) Admin-Token holen ----------
echo "==> Hole Admin-Access-Token ..."
TOKEN=$(curl "${CURL_OPTS[@]}" -fsSL -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=admin-cli" \
    -d "username=${KC_ADMIN_USER}" \
    -d "password=${KC_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    "${KC_BASE}/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    echo "ERROR: Kein Access-Token erhalten. Admin-Credentials pruefen." >&2
    exit 1
fi
echo "    OK."

# -------- Hilfsfunktion: existierende Client-ID per clientId-Attribut suchen ----------
find_client_uuid() {
    local clientid="$1"
    curl "${CURL_OPTS[@]}" -fsSL -H "Authorization: Bearer $TOKEN" \
        "${KC_BASE}/admin/realms/${REALM}/clients?clientId=${clientid}" \
        | jq -r '.[0].id // empty'
}

# -------- 2) Beide Clients rendern + importieren / aktualisieren ----------
RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT

# Wird nach dem rc-transfer-Import befuellt und in den helm-upgrade-Aufruf
# unten als --set keycloak.transferClientSecret=... weitergereicht.
TRANSFER_CLIENT_SECRET=""

for client_json in rc-transfer.json rc-guacamole.json; do
    src="${TEMPLATE_DIR}/${client_json}"
    dst="${RENDER_DIR}/${client_json}"

    [[ -f "$src" ]] || { echo "ERROR: Template $src fehlt." >&2; exit 1; }

    sed "s|__HOSTNAME__|${HOSTNAME}|g" "$src" > "$dst"
    CID=$(jq -r '.clientId' "$dst")

    echo "==> Bearbeite Client '${CID}' ..."

    EXISTING=$(find_client_uuid "$CID")
    if [[ -n "$EXISTING" ]]; then
        echo "    Existiert (UUID=$EXISTING) -> Update via PUT"
        curl "${CURL_OPTS[@]}" -fsSL -X PUT \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d @"$dst" \
            "${KC_BASE}/admin/realms/${REALM}/clients/${EXISTING}"
    else
        echo "    Neu -> Create via POST"
        curl "${CURL_OPTS[@]}" -fsSL -X POST \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d @"$dst" \
            "${KC_BASE}/admin/realms/${REALM}/clients"
    fi
    echo "    OK."

    # Fuer den confidential client rc-transfer: aktuellen Client-Secret aus
    # Keycloak nachladen (Keycloak generiert ihn beim Create ggf. neu, und
    # bei Update koennte er per Admin-UI rotiert worden sein). Den Wert
    # reichen wir spaeter an helm upgrade weiter, damit die ConfigMap/Secret
    # rc-transfer-oidc immer synchron mit Keycloak ist.
    if [[ "$CID" == "rc-transfer" ]]; then
        TR_UUID="$(find_client_uuid "$CID")"
        if [[ -n "$TR_UUID" ]]; then
            TRANSFER_CLIENT_SECRET=$(curl "${CURL_OPTS[@]}" -fsSL \
                -H "Authorization: Bearer $TOKEN" \
                "${KC_BASE}/admin/realms/${REALM}/clients/${TR_UUID}/client-secret" \
                | jq -r '.value // empty')
            if [[ -z "$TRANSFER_CLIENT_SECRET" ]]; then
                echo "    WARN: Konnte client-secret von rc-transfer nicht abrufen." >&2
            else
                echo "    Client-Secret von rc-transfer erfasst (Laenge: ${#TRANSFER_CLIENT_SECRET})."
            fi
        fi
    fi
done

# -------- 3) User im Realm anlegen (mit temporaerem Passwort) ----------
echo "==> Lege User '${USER_NAME}' im Realm '${REALM}' an ..."

USER_PAYLOAD=$(jq -n \
    --arg u "$USER_NAME" \
    --arg p "$INITIAL_PW" \
    '{
        username: $u,
        enabled: true,
        emailVerified: false,
        credentials: [{
            type: "password",
            value: $p,
            temporary: true
        }],
        requiredActions: ["UPDATE_PASSWORD"]
    }')

# Existiert der User schon?
EXISTING_USER=$(curl "${CURL_OPTS[@]}" -fsSL -H "Authorization: Bearer $TOKEN" \
    "${KC_BASE}/admin/realms/${REALM}/users?username=${USER_NAME}&exact=true" \
    | jq -r '.[0].id // empty')

if [[ -n "$EXISTING_USER" ]]; then
    echo "    User existiert (UUID=$EXISTING_USER) -> setze Passwort + UPDATE_PASSWORD-Action zurueck"
    # PUT auf den User aktualisiert nicht das Passwort selber.
    curl "${CURL_OPTS[@]}" -fsSL -X PUT \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$USER_PAYLOAD" \
        "${KC_BASE}/admin/realms/${REALM}/users/${EXISTING_USER}"

    # Passwort separat via reset-password setzen
    PW_PAYLOAD=$(jq -n --arg p "$INITIAL_PW" \
        '{type: "password", value: $p, temporary: true}')
    curl "${CURL_OPTS[@]}" -fsSL -X PUT \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PW_PAYLOAD" \
        "${KC_BASE}/admin/realms/${REALM}/users/${EXISTING_USER}/reset-password"
else
    echo "    Neu -> Create via POST"
    curl "${CURL_OPTS[@]}" -fsSL -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$USER_PAYLOAD" \
        "${KC_BASE}/admin/realms/${REALM}/users"
fi
echo "    OK."

echo
echo "==> Keycloak-Konfiguration fertig. User '${USER_NAME}' kann sich nun im Realm '${REALM}' anmelden."
echo "    Initial-Passwort: $INITIAL_PW"
echo "    (Muss beim ersten Login geaendert werden.)"
echo

# -------- 4) Helm-Deploy nach Bestaetigung --------
HELM_CHART="${TEMPLATE_DIR}/jetty-helm"
HELM_RELEASE="rc-${USER_NAME}"

if [[ -z "$NAMESPACE" ]]; then
    echo "WARN: 'namespace' nicht aus values.yaml lesbar -- helm-upgrade wird uebersprungen."
else
    echo "==> Naechster Schritt: Helm-Deploy"
    echo "    helm upgrade --install ${HELM_RELEASE} ${HELM_CHART} \\"
    echo "        --namespace ${NAMESPACE} \\"
    echo "        --set user=${USER_NAME} \\"
    echo "        --set pw=<INITIAL_PW> \\"
    if [[ -n "$TRANSFER_CLIENT_SECRET" ]]; then
        echo "        --set keycloak.transferClientSecret=<aus_keycloak>"
    fi
    echo
    read -r -p "Enter zum Ausfuehren druecken (Strg+C zum Abbrechen) ..."

    HELM_EXTRA_ARGS=()
    if [[ -n "$TRANSFER_CLIENT_SECRET" ]]; then
        HELM_EXTRA_ARGS+=(--set "keycloak.transferClientSecret=${TRANSFER_CLIENT_SECRET}")
    fi

    helm upgrade --install "${HELM_RELEASE}" "${HELM_CHART}" \
        --namespace "${NAMESPACE}" \
        --set user="${USER_NAME}" \
        --set pw="${INITIAL_PW}" \
        "${HELM_EXTRA_ARGS[@]}"

    echo
    echo "==> Helm-Deploy abgeschlossen."
    echo "    Falls noetig: kubectl -n ${NAMESPACE} rollout restart deploy/${HELM_RELEASE}"
    echo 
    echo "Bei Secret "rc-transfer-oidc" Fehler:"
    echo "kubectl -n ${NAMESPACE} get secret rc-transfer-oidc -o yaml"
    echo "kubectl -n ${NAMESPACE} delete secret rc-transfer-oidc"
    echo
    echo "Uninstall mit: helm uninstall ${HELM_RELEASE} --namespace ${NAMESPACE}"
    echo
    echo "Rich Client URL: https://rc.${NAMESPACE}.ha.k8s-dev004.aspera.usu.grp/transfer"
    echo
    
    

fi
