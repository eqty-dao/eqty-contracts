# EQTY Testnet Deployment Guide (Base Sepolia)

**Status:** ✅ Deployed on 2026-02-06

## Deployed Addresses (2026-02-06)

| Contract | Address |
|----------|---------|
| **EQTY Token** | `0x92c9d244da5aA178240F3Aab9D931Aaf00dFE492` |
| **RedeemEQTY** | `0xaa1a97b0e1718511dde32afdb7a84a5241d42e9b` |
| **Anchor** | `0xB03e8E6F74145FC26013491066716cBf7C556495` |
| **OwnableNFT** | `0x198d5c7373E78E7c25384920D7CE448a267C2227` |
| **Bridge Wallet** | `0x1E2DAD5ba3A0C286A01f5dA4D30f17223D37A2Bd` |

## Forutsetninger

```bash
# 1. Foundry (Solidity toolchain)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. Node.js >= 18 + pnpm
npm install -g pnpm

# 3. Base Sepolia ETH (for gas)
#    Hent fra: https://www.coinbase.com/faucets/base-ethereum-sepolia
#    Du trenger ~0.05 ETH for deploy + konfigurasjon
```

Du trenger en deploy-wallet med privat nøkkel. **Bruk aldri en nøkkel med ekte midler for testing.**

---

## Steg 1: Deploy eqty-contracts (Solidity)

Deploy-rekkefølge er viktig fordi kontraktene refererer til hverandre:

```
EQTY Token → RedeemEQTY → Anchor
```

### 1.1 Konfigurer environment

```bash
cd eqty-contracts
cp .env.example .env
```

Rediger `.env`:

```bash
# Din deploy-wallet (uten 0x-prefix)
PRIVATE_KEY=abc123...

# Base Sepolia RPC
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Basescan API key (for verifisering, valgfritt)
BASESCAN_API_KEY=

# Bridge wallet (kan være din egen wallet for testing)
BRIDGE_WALLET=0xDIN_WALLET_ADRESSE

# Foundation wallet (mottar fees)
FOUNDATION_WALLET=0xDIN_WALLET_ADRESSE
```

### 1.2 Installer dependencies og bygg

```bash
forge install
forge build
```

### 1.3 Kjør tester (verifiser at alt er OK)

```bash
forge test -vvv
```

Forventet: Alle tester passerer. Merk at Anchor-tester som refererer til `InsufficientETH` må oppdateres til `IncorrectETH` hvis de feiler.

### 1.4 Deploy EQTY Token

```bash
forge script script/DeployEQTY.s.sol:DeployEQTY \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

**Skriv ned adressen** som logges: `EQTY deployed at: 0x...`

Etter deploy, mint test-tokens til din wallet:

```bash
# Bruker cast (Foundry CLI) for å minte EQTY til testing
# Merk: Bare bridge wallet kan minte
cast send <EQTY_ADRESSE> \
  "mint(address,uint256)" \
  <DIN_WALLET> \
  1000000000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
# Minter 1,000,000 EQTY (1M * 10^18 wei)
```

### 1.5 Deploy RedeemEQTY

Oppdater `script/DeployRedeem.s.sol` linje 23 med EQTY token-adressen fra forrige steg:

```solidity
address constant EQTY_TOKEN_TESTNET = 0x<DIN_EQTY_TOKEN_ADRESSE>;
```

Deploy:

```bash
forge script script/DeployRedeem.s.sol:DeployRedeemEQTY \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

**Skriv ned adressen**: `RedeemEQTY deployed at: 0x...`

### 1.6 Deploy Anchor

Legg til i `.env`:

```bash
EQTY_TOKEN_ADDRESS=0x<EQTY_TOKEN_ADRESSE>
REDEEM_CONTRACT_ADDRESS=0x<REDEEM_ADRESSE>
EQTY_FEE=100000000000000000000  # 100 EQTY (100 * 10^18)
```

Deploy:

```bash
forge script script/DeployAnchor.s.sol:DeployAnchor \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

**Skriv ned adressen**: `Anchor deployed at: 0x...`

### 1.7 Post-deploy konfigurasjon

Sett initial exchange rate på RedeemEQTY:

```bash
# Sett rate til 0.001 ETH per 10k EQTY (for testing)
cast send <REDEEM_ADRESSE> \
  "setCurrentRate(uint256)" \
  1000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 1.8 Verifiser deploy

```bash
# Sjekk at Anchor har riktig EQTY token
cast call <ANCHOR_ADRESSE> "eqtyToken()(address)" --rpc-url $BASE_SEPOLIA_RPC_URL

# Sjekk at Anchor har riktig Redeem contract
cast call <ANCHOR_ADRESSE> "redeemContract()(address)" --rpc-url $BASE_SEPOLIA_RPC_URL

# Sjekk EQTY fee
cast call <ANCHOR_ADRESSE> "eqtyFee()(uint256)" --rpc-url $BASE_SEPOLIA_RPC_URL

# Sjekk ETH fee fra Redeem
cast call <ANCHOR_ADRESSE> "getEthFee()(uint256)" --rpc-url $BASE_SEPOLIA_RPC_URL

# Sjekk RedeemEQTY rate
cast call <REDEEM_ADRESSE> "currentRate()(uint256)" --rpc-url $BASE_SEPOLIA_RPC_URL

# Sjekk max anchors
cast call <ANCHOR_ADRESSE> "MAX_ANCHORS_PER_TX()(uint256)" --rpc-url $BASE_SEPOLIA_RPC_URL
```

### Oppsummering adresser

Etter dette steget har du tre adresser. Skriv de ned:

```
EQTY Token:    0x___________________________________
RedeemEQTY:    0x___________________________________
Anchor:        0x___________________________________
```

---

## Steg 2: Oppdater eqty-core (TypeScript library)

### 2.1 Oppdater kontraktadresser

Rediger `eqty-core/src/constants.ts` med de nye adressene:

```typescript
// Base Sepolia Testnet
export const BASE_SEPOLIA_CHAIN_ID = 84532;
export const BASE_SEPOLIA_ANCHOR_CONTRACT = "0x<NY_ANCHOR_ADRESSE>";
export const BASE_SEPOLIA_EQTY_TOKEN = "0x<NY_EQTY_TOKEN_ADRESSE>";
```

### 2.2 Kjør tester

```bash
cd eqty-core
pnpm install
pnpm test
```

Forventet: 86/86 tester passerer.

### 2.3 Bygg library

```bash
pnpm build
```

Dette genererer `dist/` med CJS og ESM output.

### 2.4 Publiser eller link lokalt

**Alternativ A: npm link (for lokal testing)**

```bash
cd eqty-core
pnpm link --global
```

Deretter i prosjekter som bruker eqty-core:

```bash
pnpm link --global eqty-core
```

**Alternativ B: npm publish (for DAO-distribusjon)**

```bash
# Oppdater versjon i package.json først
pnpm publish --access public --tag testnet
```

---

## Steg 3: Konfigurer obuilder (NestJS backend)

### 3.1 Installer dependencies

```bash
cd obuilder
pnpm install
```

### 3.2 Konfigurer environment

```bash
cp .env.example .env
```

Rediger `.env` med minimum konfigurasjon for testnet:

```bash
# Miljø
NODE_ENV=development

# Nettverk: testnet
EQTY_NETWORK_TYPE=testnet
EQTY_USE_MAINNET=false

# RPC
EQTY_RPC_TESTNET=https://sepolia.base.org

# Wallet (privat nøkkel uten 0x-prefix, for å signere transaksjoner)
EQTY_PRIVATE_KEY_TESTNET=abc123...

# Template-pris
EQTY_TEMPLATE_COSTSUSD_TESTNET=0.10

# CORS: Legg til localhost for lokal testing
CORS_ORIGINS=http://localhost:3000,http://localhost:3001,https://eqty.io,https://app.eqty.io

# Lokal testing (bypasser S3 og Pinata)
LOCAL_TESTING=true

# Pinata (valgfritt for lokal testing, påkrevd for produksjon)
# PINATA_JWT=
# PINATA_GATEWAY_URL=

# Telegram (valgfritt)
# TELEGRAM_BOT_TOKEN=
# TELEGRAM_CHANNEL_ID_TESTNET=
```

### 3.3 Kjør tester

```bash
pnpm test
```

Forventet: 762/762 tester passerer (58 skipped).

### 3.4 Bygg og start

```bash
# Bygg
pnpm build

# Start i dev-modus (med hot reload)
pnpm start:dev

# Eller produksjonsmodus
pnpm start:prod
```

Serveren starter på `http://localhost:3001` (local testing) eller `http://localhost:3000` (produksjon).

### 3.5 Verifiser at API-et kjører

```bash
# Swagger dokumentasjon
curl http://localhost:3001/api

# Health check (om tilgjengelig)
curl http://localhost:3001/
```

---

## Steg 4: Verifiser hele stacken end-to-end

### 4.1 Test anchoring med eqty-core

Lag en testfil `test-anchor.ts`:

```typescript
import { AnchorClient, EventChain, Event, ViemSigner, ViemContract } from "eqty-core";
import { createWalletClient, createPublicClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";

const PRIVATE_KEY = "0x<DIN_PRIVATE_KEY>";

async function main() {
  const account = privateKeyToAccount(PRIVATE_KEY);

  const walletClient = createWalletClient({
    account,
    chain: baseSepolia,
    transport: http("https://sepolia.base.org"),
  });

  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http("https://sepolia.base.org"),
  });

  const signer = new ViemSigner(walletClient);

  // 1. Lag en event chain
  const chain = EventChain.create(account.address, baseSepolia.id);
  const event = new Event({ test: "DAO testnet deploy" }, "application/json").addTo(chain);
  await event.signWith(signer);

  console.log("Event chain ID:", chain.id);
  console.log("Event hash:", event.hash.hex);

  // 2. Sett opp anchor client
  const contractAddress = AnchorClient.contractAddress(baseSepolia.id);
  console.log("Anchor contract:", contractAddress);

  const contract = new ViemContract(publicClient, walletClient, contractAddress);
  const anchorClient = new AnchorClient(contract);

  // 3. Sjekk max anchors og ETH fee
  const maxAnchors = await anchorClient.getMaxAnchors();
  console.log("Max anchors per tx:", maxAnchors);

  const ethFee = await anchorClient.getEthFee();
  console.log("ETH fee per anchor:", ethFee, "wei");

  // 4. Approve EQTY for burn (om EQTY-betaling)
  // Eller send med ETH:
  const ethCost = await anchorClient.previewEthCost(1);
  console.log("Total ETH cost:", ethCost, "wei");

  // 5. Anchor med ETH-betaling
  await anchorClient.anchor(chain.anchorMap(), { ethValue: ethCost });
  console.log("Anchored successfully!");
}

main().catch(console.error);
```

Kjør:

```bash
npx tsx test-anchor.ts
```

### 4.2 Sjekk transaksjonen

Gå til `https://sepolia.basescan.org/address/<ANCHOR_ADRESSE>` og se at `Anchored`-events er emittet.

---

## Feilsøking

| Problem | Årsak | Løsning |
|---------|-------|---------|
| `IncorrectETH()` revert | Feil ETH-beløp sendt | Bruk `previewEthCost()` for eksakt beløp |
| `RedeemContractNotSet()` | Anchor mangler Redeem-adresse | `cast send <ANCHOR> "setRedeemContract(address)" <REDEEM>` |
| `RateNotSet()` | RedeemEQTY rate = 0 | `cast send <REDEEM> "setCurrentRate(uint256)" 1000000000000000` |
| `InsufficientEQTYAllowance()` | Mangler EQTY approve | `cast send <EQTY> "approve(address,uint256)" <ANCHOR> <AMOUNT>` |
| CORS error i browser | Origin ikke tillatt | Legg til origin i `CORS_ORIGINS` env |
| `UNSUPPORTED_CHAIN` i obuilder | Ugyldig chain ID i header | Send `x-eqty-chain-id: 84532` header |

## Adresse-sjekkliste etter deploy

```
[ ] EQTY Token deployet og verifisert
[ ] Test-tokens mintet til test-wallets
[ ] RedeemEQTY deployet med riktig EQTY-adresse
[ ] Initial rate satt på RedeemEQTY
[ ] Anchor deployet med EQTY + Redeem konfigurert
[ ] eqty-core/src/constants.ts oppdatert med nye adresser
[ ] eqty-core bygget og publisert/linket
[ ] obuilder .env konfigurert for testnet
[ ] End-to-end test fullført (anchor + verifiser på basescan)
[ ] DAO test-wallets har ETH og EQTY for testing
```

## DAO-overlevering (etter testing)

Når alt er verifisert, overfør eierskap til DAO multisig:

```bash
# 1. Overfør Anchor eierskap
cast send <ANCHOR_ADRESSE> \
  "transferOwnership(address)" <DAO_MULTISIG> \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 2. Overfør RedeemEQTY eierskap
cast send <REDEEM_ADRESSE> \
  "transferOwnership(address)" <DAO_MULTISIG> \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 3. DAO multisig må akseptere (fra multisig):
# anchor.acceptOwnership()
# redeemContract.acceptOwnership()
```
