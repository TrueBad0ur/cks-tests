#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
mkdir -p creds
cd creds

KUBE=~/.kube/config
SERVER=$(awk -F': ' '/server:/{print $2;exit}' "$KUBE")
CA=$(awk -F': ' '/certificate-authority-data:/{print $2;exit}' "$KUBE")
CERT=$(awk -F': ' '/client-certificate-data:/{print $2;exit}' "$KUBE")
KEY=$(awk -F': ' '/client-key-data:/{print $2;exit}' "$KUBE")

echo "$CA" | base64 -d > ca.crt
echo "$CERT" | base64 -d > client.crt
echo "$KEY" | base64 -d > client.key

curl -s --cacert ca.crt --cert client.crt --key client.key "${SERVER}/api/v1/namespaces"
