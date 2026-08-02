# Android Signing Setup

## One-time keystore creation

Run this command ONCE and store the keystore file securely (NEVER commit to git):

```bash
keytool -genkey -v \
  -keystore android/app/keystore.jks \
  -alias ggs_werewolf \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=GGS Werewolf, OU=Mobile, O=Your Company, L=Jakarta, S=DKI, C=ID"
```

## key.properties

Create `android/key.properties` (already in .gitignore):

```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=ggs_werewolf
storeFile=keystore.jks
```

## build.gradle is already configured

The `android/app/build.gradle` reads from `key.properties` automatically.

## CI/CD (GitHub Actions)

Add these GitHub Secrets:
- `KEYSTORE_BASE64` — base64-encoded keystore: `base64 -i android/app/keystore.jks`
- `KEY_ALIAS` — `ggs_werewolf`
- `KEY_PASSWORD` — your key password
- `STORE_PASSWORD` — your store password

Then in `.github/workflows/ci.yml`, uncomment the release build section.
