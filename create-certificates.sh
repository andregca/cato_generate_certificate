#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CONFIG_FILE="cert_config.yml"
CERTS_DIR="certs"
YQ_BIN="yq"

fail() {
    echo "[ERROR] $1" >&2
    exit 1
}

command -v $YQ_BIN >/dev/null 2>&1 || fail "yq is not installed. Please install yq first."

[ -f "$CONFIG_FILE" ] || fail "$CONFIG_FILE not found. Please create it based on cert_config-sample.yml."

prompt_password() {
    stty -echo
    printf "Enter password to protect root CA key: "
    read CA_PASSWORD
    stty echo
    echo
    [ -z "$CA_PASSWORD" ] && fail "Password cannot be empty."
}

parse_yaml() {
    MISSING=()

    get_or_missing() {
        local val
        val=$($YQ_BIN ."$1" "$CONFIG_FILE" 2>/dev/null)
        if [ "$val" = "null" ] || [ -z "$val" ]; then
            MISSING+=("$1")
        else
            eval "$2=\"$val\""
        fi
    }

    get_or_missing ca.country CA_COUNTRY
    get_or_missing ca.state CA_STATE
    get_or_missing ca.locality CA_LOCALITY
    get_or_missing ca.organization CA_ORG
    get_or_missing ca.org_unit CA_OU
    get_or_missing ca.cn CA_CN
    get_or_missing ca.email CA_EMAIL
    get_or_missing ca.days CA_DAYS
    get_or_missing ca.cert_name CA_CERT_NAME
    get_or_missing ca.key_name CA_KEY_NAME

    get_or_missing device.cn DEV_CN
    get_or_missing device.days DEV_DAYS
    get_or_missing device.key_name DEV_KEY_NAME
    get_or_missing device.cert_name DEV_CERT_NAME

    if [ ${#MISSING[@]} -ne 0 ]; then
        echo "[ERROR] Missing required config parameters:" >&2
        for param in "${MISSING[@]}"; do
            echo " - $param" >&2
        done
        exit 1
    fi
}

# Ensure output directory exists

[ -d "$CERTS_DIR" ] || mkdir -p "$CERTS_DIR" || fail "Could not create directory $CERTS_DIR"

prompt_password
parse_yaml

# Step 1: Generate root CA private key
ROOT_CA_KEY_NAME="$CERTS_DIR/$CA_KEY_NAME.key"
openssl genrsa -aes256 -passout pass:"$CA_PASSWORD" -out "$ROOT_CA_KEY_NAME" 4096 || fail "Failed to generate root CA key"

# Step 2: Create root CA certificate
ROOT_CA_CERT_NAME="$CERTS_DIR/$CA_CERT_NAME.crt"
openssl req -x509 -new -nodes -key "$ROOT_CA_KEY_NAME" -sha256 -days "$CA_DAYS" \
    -subj "/C=$CA_COUNTRY/ST=$CA_STATE/L=$CA_LOCALITY/O=$CA_ORG/OU=$CA_OU/CN=$CA_CN/emailAddress=$CA_EMAIL" \
    -out "$ROOT_CA_CERT_NAME" -passin pass:"$CA_PASSWORD" || fail "Failed to create root CA cert"

# Step 3: Generate device certificate key
DEVICE_KEY_NAME="$CERTS_DIR/$DEV_KEY_NAME.key"
openssl genrsa -out "$DEVICE_KEY_NAME" 2048 || fail "Failed to generate device certificate key"

# Step 4: Create device CSR
DEVICE_CSR_NAME="$CERTS_DIR/$DEV_CERT_NAME.csr"
openssl req -new -key "$DEVICE_KEY_NAME" -out "$DEVICE_CSR_NAME" -subj "/CN=$DEV_CN" || fail "Failed to create Device CSR"

# Step 5: Create device certificate
DEVICE_CERT_NAME="$CERTS_DIR/$DEV_CERT_NAME.crt"
openssl x509 -req -in "$DEVICE_CSR_NAME" -CA "$ROOT_CA_CERT_NAME" -CAkey "$ROOT_CA_KEY_NAME" -CAcreateserial \
    -out "$DEVICE_CERT_NAME" -days "$DEV_DAYS" -sha256 -passin pass:"$CA_PASSWORD" || fail "Failed to sign device certificate"

# Step 6: Export device certificate to PKCS#12 format
DEVICE_CERT_NAME_P12="$CERTS_DIR/$DEV_CERT_NAME.p12"
openssl pkcs12 -export -out "$DEVICE_CERT_NAME_P12" -inkey "$DEVICE_KEY_NAME" -in "$DEVICE_CERT_NAME" \
    -passout pass:"$CA_PASSWORD" || fail "Failed to export device certificate to .p12 format"

# Step 7: Convert the root CA to .pem format.
ROOT_CA_PEM_NAME="$CERTS_DIR/$CA_CERT_NAME.pem"
openssl x509 -in "$ROOT_CA_CERT_NAME" -out "$ROOT_CA_PEM_NAME" || fail "Failed to convert Root CA CRT to PEM"

echo "Certificates generated successfully in ./$CERTS_DIR"
echo "CA Certificate: $ROOT_CA_CERT_NAME"
echo "CA PEM (for CMA): $ROOT_CA_PEM_NAME"
echo "Device Certificate: $DEVICE_CERT_NAME"
echo "PKCS#12 File (Linux): $DEVICE_CERT_NAME_P12"