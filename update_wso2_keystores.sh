#!/bin/bash

# Variables
KEYSTORE="wso2carbon.jks"
CLIENT_TRUSTSTORE="client-truststore.jks"
PASSWORD="wso2carbon"
ALIAS="wso2carbon"
P12_FILE="wso2carbon.p12"
OLD_PRIVATE_KEY="oldPrivateKey.pem"
NEW_CERT="newCertificate.pem"
PUBLIC_KEY="publicKey.pem"
DAYS_VALID=1024

# Check if the keystore exists
if [[ ! -f "$KEYSTORE" ]]; then
    echo "Keystore $KEYSTORE not found!"
    exit 1
fi

# Extract the alias
echo "Extracting alias from keystore..."
ALIAS_FOUND=$(keytool -list -keystore "$KEYSTORE" -storepass "$PASSWORD" | grep "$ALIAS")

if [[ -z "$ALIAS_FOUND" ]]; then
    echo "Alias $ALIAS not found in keystore!"
    exit 1
fi

# Display the certificate details
echo "Extracting certificate details..."
CERT_DETAILS=$(keytool -list -keystore "$KEYSTORE" -storepass "$PASSWORD" -alias "$ALIAS" -v)

# Extract the Owner line
OWNER_LINE=$(echo "$CERT_DETAILS" | grep "Owner:")

EMAIL=$(echo "$OWNER_LINE" | awk -F 'emailAddress=' '{print $2}' | awk -F ',' '{print $1}')
CN=$(echo "$OWNER_LINE" | awk -F 'CN=' '{print $2}' | awk -F ',' '{print $1}')
OU=$(echo "$OWNER_LINE" | awk -F 'OU=' '{print $2}' | awk -F ',' '{print $1}')
O=$(echo "$OWNER_LINE" | awk -F 'O=' '{print $2}' | awk -F ',' '{print $1}')
L=$(echo "$OWNER_LINE" | awk -F 'L=' '{print $2}' | awk -F ',' '{print $1}')
ST=$(echo "$OWNER_LINE" | awk -F 'ST=' '{print $2}' | awk -F ',' '{print $1}')
C=$(echo "$OWNER_LINE" | awk -F 'C=' '{print $2}' | awk -F ',' '{print $1}')

# Extract the private key
echo "Extracting private key..."
keytool -importkeystore \
    -srckeystore "$KEYSTORE" \
    -srcstorepass "$PASSWORD" \
    -destkeystore "$P12_FILE" \
    -deststoretype PKCS12 \
    -srcalias "$ALIAS" \
    -deststorepass "$PASSWORD"

openssl pkcs12 -in "$P12_FILE" -nodes -nocerts -out "$OLD_PRIVATE_KEY" -passin pass:"$PASSWORD"

# Create a new self-signed certificate
echo "Creating new self-signed certificate..."
openssl req -x509 -new -nodes \
    -key "$OLD_PRIVATE_KEY" \
    -sha256 \
    -days "$DAYS_VALID" \
    -out "$NEW_CERT" \
    -subj "/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=$CN/emailAddress=$EMAIL"

# Import the new certificate into the keystore
echo "Importing the new certificate into the keystore..."
keytool -import -keystore "$KEYSTORE" -storepass "$PASSWORD" -file "$NEW_CERT" -alias "$ALIAS" -noprompt

# Verify the new certificate
echo "\n\n=============================================================================="
echo "Verifying the new certificate in the keystore..."
keytool -list -v -keystore "$KEYSTORE" -storepass "$PASSWORD" -alias "$ALIAS"
echo "==============================================================================\n\n"

# Extract the public key
echo "Extracting public key..."
keytool -export -alias "$ALIAS" -keystore "$KEYSTORE" -storepass "$PASSWORD" -file "$PUBLIC_KEY"

# Update the client-truststore
echo "Updating client-truststore..."
keytool -delete -alias "$ALIAS" -keystore "$CLIENT_TRUSTSTORE" -storepass "$PASSWORD" || echo "Alias not found in client-truststore. Skipping deletion."

keytool -import -alias "$ALIAS" -file "$PUBLIC_KEY" -keystore "$CLIENT_TRUSTSTORE" -storepass "$PASSWORD" -noprompt

echo "SSL certificate has been updated successfully."
