#!/bin/bash
set -euxo pipefail

U="d"

# make three tokens
spl-token create-token -u "$URL" | tee /tmp/revoken-spl-mint1
spl-token create-token -u "$URL" --decimals 6 | tee /tmp/revoken-spl-mint2
spl-token create-token -u "$URL" --decimals 6 | tee /tmp/revoken-spl-mint3
MINT1=$(head -1 /tmp/revoken-spl-mint1 | cut -d " " -f 3)
MINT2=$(head -1 /tmp/revoken-spl-mint2 | cut -d " " -f 3)
MINT3=$(head -1 /tmp/revoken-spl-mint3 | cut -d " " -f 3)

# and three accounts
spl-token create-account -u "$URL" "$MINT1"
spl-token create-account -u "$URL" "$MINT2"
spl-token create-account -u "$URL" "$MINT3" | tee /tmp/revoken-wallet-token
UTADDR=$(head -1 /tmp/revoken-wallet-token | cut -d " " -f 3)

# mint to wallet
spl-token mint -u "$URL" "$MINT1" 100
spl-token mint -u "$URL" "$MINT2" 200
spl-token mint -u "$URL" "$MINT3" 300

# gen a random address
solana-keygen new --no-outfile --no-bip39-passphrase | sed -n '/^pubkey/p' | tee /tmp/revoken-delegate-pubkey
DWADDR=$(head -1 /tmp/revoken-delegate-pubkey | cut -d " " -f 2)
spl-token create-account -u "$URL" --owner "$DWADDR" "$MINT3" | tee /tmp/revoken-delegate-token
DTADDR=$(head -1 /tmp/revoken-delegate-token | cut -d " " -f 3)

# and make it a delegate on coin 3
# XXX spl-token approve -u d CWFeNRoUJSMn19j1ZrByU3XJYPNbePKWMwqF2AmXjJhg 50 ELErZbcqavHQE5vGNMwNGs2G9VPDVCehHHZefurJhz8s
spl-token approve -u "$URL" "$UTADDR" 50 "$DTADDR"
