Mailvelope Keyserver
====================

A simple OpenPGP public key server that validates email address ownership of uploaded keys.

## Why not use Web of Trust?

There are already OpenPGP key servers like the [SKS keyserver](https://github.com/SKS-Keyserver/sks-keyserver) that employ the [Web of Trust](https://en.wikipedia.org/wiki/Web_of_trust) to provide a way to authenticate a user's PGP keys. The problem with these servers are discussed [here](https://en.wikipedia.org/wiki/Key_server_(cryptographic)#Problems_with_keyservers).

### Privacy

The web of trust raises some valid privacy concerns. Not only is a user's social network made public, common SKS servers are also not compliant with the [EU Data Protection Directive](https://en.wikipedia.org/wiki/Data_Protection_Directive) due to lack of key deletion. This key server addresses these issues by not employing the web of trust and by allowing key removal.

### Usability

The main issue with the Web of Trust though is that it does not scale in terms of usability. The goal of this key server is to enable a better user experience for OpenPGP user agents by providing a more reliable source of public keys. Similar to messengers like Signal, users verify their email address by clicking on a link of a PGP encrypted message. This prevents user A from uploading a public key for user B. With this property in place, automatic key lookup is more reliable than with standard SKS servers.

This requires more trust to be placed in the service provider that hosts a key server, but we believe that this trade-off is necessary to improve the user experience for average users. Tech-savvy users or users with a threat model that requires stronger security may still choose to verify PGP key fingerprints just as before.

## Standardization and (De)centralization

The idea is that an identity provider such as an email provider can host their own key directory under a common `openpgpkey` subdomain. An OpenPGP supporting user agent should attempt to lookup keys under the user's domain e.g. `https://openpgpkey.example.com` for `user@example.com` first. User agents can host their own fallback key server as well, in case a mail provider does not provide its own key directory.

# Demo

Try out the server here: [https://keys.mailvelope.com](https://keys.mailvelope.com)

# API

The key server provides a modern RESTful API, but is also backwards compatible to the OpenPGP HTTP Keyserver Protocol (HKP). The following properties are enforced by the key server to enable reliable automatic key look in user agents:

* Only public keys with at least one verified email address are served
* There can be only one public key per verified email address at a given time
* A key ID specified in a query must be at least 16 hex characters (64-bit long key ID)
* Key ID collisions are checked upon key upload to prevent collision attacks

## HKP API

The HKP APIs are not documented here. Please refer to the [HKP specification](https://tools.ietf.org/html/draft-shaw-openpgp-hkp-00) to learn more. The server generally implements the full specification, but has some constraints to improve the security for automatic key lookup:

#### Accepted `search` parameters
* Email addresses
* V4 Fingerprints
* Key IDs with 16 digits (64-bit long key ID)

#### Accepted `op` parameters
* get
* index
* vindex

#### Accepted `options` parameters
* mr

#### Usage example with GnuPG

```
gpg --keyserver hkps://keys.mailvelope.com --search  info@mailvelope.com
```

## REST API

### Lookup a key

#### By key ID

```
GET /api/v1/key?keyId=b8e4105cc9dedc77
```

#### By fingerprint

```
GET /api/v1/key?fingerprint=e3317db04d3958fd5f662c37b8e4105cc9dedc77
```

#### By email address

```
GET /api/v1/key?email=user@example.com
```

#### Payload (JSON):

```json
{
  "keyId": "b8e4105cc9dedc77",
  "fingerprint": "e3317db04d3958fd5f662c37b8e4105cc9dedc77",
  "userIds": [
    {
      "name": "Jon Smith",
      "email": "jon@smith.com",
      "verified": "true"
    },
    {
      "name": "Jon Smith",
      "email": "jon@organization.com",
      "verified": "false"
    }
  ],
  "created": "Sat Oct 17 2015 12:17:03 GMT+0200 (CEST)",
  "algorithm": "rsaEncryptSign",
  "keySize": "4096",
  "publicKeyArmored": "-----BEGIN PGP PUBLIC KEY BLOCK----- ... -----END PGP PUBLIC KEY BLOCK-----"
}
```

* **keyId**: The 16 char key id in hex
* **fingerprint**: The 40 char key fingerprint in hex
* **userIds.name**: The user ID's name
* **userIds.email**: The user ID's email address
* **userIds.verified**: If the user ID's email address has been verified
* **created**: The key creation time as a JavaScript Date
* **algorithm**: The primary key alogrithm
* **keySize**: The key length in bits
* **publicKeyArmored**: The ascii armored public key block

### Upload new key

```
POST /api/v1/key
```

#### Payload (JSON):

```json
{
  "publicKeyArmored": "-----BEGIN PGP PUBLIC KEY BLOCK----- ... -----END PGP PUBLIC KEY BLOCK-----"
}
```

* **publicKeyArmored**: The ascii armored public PGP key to be uploaded

E.g. to upload a key from shell:
```bash
curl https://keys.mailvelope.com/api/v1/key --data "{\"publicKeyArmored\":\"$( \
  gpg --armor --export-options export-minimal --export $GPGKEYID | sed ':a;N;$!ba;s/\n/\\n/g' \
  )\"}" 
```

### Verify uploaded key (via link in email)

```
GET /api/v1/key?op=verify&keyId=b8e4105cc9dedc77&nonce=6a314915c09368224b11df0feedbc53c
```

### Request key removal

```
DELETE /api/v1/key?keyId=b8e4105cc9dedc77 OR ?email=user@example.com
```

### Verify key removal (via link in email)

```
GET /api/v1/key?op=verifyRemove&keyId=b8e4105cc9dedc77&nonce=6a314915c09368224b11df0feedbc53c
```

## Abuse resistant key server

The key server implements mechanisms described in the draft [Abuse-Resistant OpenPGP Keystores](https://datatracker.ietf.org/doc/html/draft-dkg-openpgp-abuse-resistant-keystore-06) to mitigate various attacks related to flooding the key server with bogus keys or certificates. The filtering of keys can be customized with [environment variables](#settings).

In detail the following key components are filtered out:

* user attribute packets
* third-party certificates
* certificates exceeding 8383 bytes
* certificates that cannot be verified with primary key
* unhashed subpackets except: issuer, issuerFingerprint, embeddedSignature
* unhashed subpackets of embedded signatures
* user IDs without email address
* user IDs exceeding 1024 bytes
* user IDs that have no self certificate or revocation signature
* subkeys exceeding 8383 bytes
* above 5 revocation signatures. Hardest, earliest revocations are kept.
* superseded certificates. Newest 5 are kept.

A key is rejected if one of the following is detected:

* primary key packet exceeding 8383 bytes
* primary key packet is not version 4
* key without user ID
* key with more than 20 email addresses
* key with more than 20 subkeys
* key size exceeding 32768 bytes
* new uploaded key is not valid 24h in the future

# Language & DB

The server is written is in JavaScript ES2020 and runs on [Node.js](https://nodejs.org/) v18+.

It uses [MongoDB](https://www.mongodb.com/) v6.0+ or [FerretDB](https://ferretdb.com) 2.0+ (Free Software replacement for MongoDB) as its database.

# Getting started
## Installation

### Node.js (macOS)

This is how to install node on Mac OS using [homebrew](https://brew.sh/). For other operating systems, please refer to the [Node.js download page](https://nodejs.org/en/download/).

```shell
brew update
brew install node
```

### MongoDB (macOS)

This is the installation guide to get a local development installation on macOS using [homebrew](https://brew.sh/). For other operating systems, please refer to the [MongoDB Installation Tutorials](https://www.mongodb.com/docs/v6.0/installation/#mongodb-installation-tutorials).

```shell
brew update
brew install mongodb-community@6.0
mongod --config /opt/homebrew/etc/mongod.conf
```

Now the mongo daemon should be running in the background. To have mongo start automatically as a background service on startup you can also do:

```shell
brew services start mongodb
```

Now you can use the `mongosh` CLI client to create a new test database. The username and password used here match the ones in the `.env` file. **Be sure to change them for production use**:

```shell
mongosh
use keyserver-test
db.createUser({ user:"keyserver-user", pwd:"your_mongo_db_pwd", roles:[{ role:"readWrite", db:"keyserver-test" }] })
```

## FerrerDB

You can find [instructions to install FerretDB on their website](https://docs.ferretdb.io/installation/ferretdb/).

#### Purge unverfied keys with TTL (time to live) indexes

Unverified keys are automatically purged after `PUBLIC_KEY_PURGE_TIME` days. The MongoDB TTLMonitor thread that is used for this purpose, runs by default every 60 seconds. To change this interval to a more appropriate value run the following admin command in the mongo shell:

```
db.adminCommand({setParameter:1, ttlMonitorSleepSecs: 86400}) // 1 day
```

#### Recommended indexes

To improve query performance the following indexes are recommended:

```
db.publickey.createIndex({"userIds.email" : 1, "userIds.verified" : 1}) // query by email
db.publickey.createIndex({"keyId" : 1, "userIds.verified" : 1}) // query by keyID
db.publickey.createIndex({"fingerprint" : 1, "userIds.verified" : 1}) // query by fingerprint
```

### Dependencies

```shell
npm install
```

## Configuration

Configuration settings may be provided as environment variables. The file config/config.js reads the environment variables and defines configuration values for settings with no corresponding environment variable. Warning: Default settings are only provided for a small minority of settings in these files (as most of them are very individual like host/user/password)!

### Development

If you don't use environment variables to configure settings, you can alternatively create a .env file for example with the following content:

```
PORT=3000
BASE_URL=http://localhost:3000
CORS_HEADER=true
HTTP_SECURITY_HEADER=true
CSP_HEADER=true
LOG_LEVEL=info
MONGO_URI=127.0.0.1:27017/keyserver-test
MONGO_USER=keyserver-user
MONGO_PASS=your_mongo_db_pwd
SMTP_HOST=sabic.uberspace.de
SMTP_PORT=465
SMTP_TLS=true
SMTP_STARTTLS=false
SMTP_PGP=true
SMTP_USER=info@your-key-server.net
SMTP_PASS=your_smtp_pwd
SENDER_NAME=My Key Server Demo
SENDER_EMAIL=info@your-key-server.net
```

## Unit and integration tests

Create a test database for the integration tests:

```shell
mongosh
use keyserver-test-int
db.createUser({ user:"keyserver-user", pwd:"your_mongo_db_pwd", roles:[{ role:"readWrite", db:"keyserver-test-int" }] })
```

Afterwards start the unit tests with `npm test`.

### Production

For production use, settings configuration with environment variables is recommended as `NODE_ENV=production` is REQUIRED to be set as environment variable to instruct node.js to adapt e.g. logging to production use.

### Settings

Available settings with its environment-variable-names, possible/example values and meaning (if not self-explainable). Defaults **bold**:

* NODE_ENV=development|production (no default, needs to be set as environment variable)
* LOG_LEVEL=debug|**info**|notice|warning|err|crit|alert|emerg
* SERVER_HOST=**localhost**
* PORT=**8888** (application server port)
* BASE_URL=http://localhost:8888 (public-facing base URL)
* CORS_HEADER=true [CORS headers](https://hapi.dev/api#-routeoptionscors)
* HTTP_SECURITY_HEADER=true [security headers](https://hapi.dev/api#-routeoptionssecurity)
* CSP_HEADER=true (add Content-Security-Policy as in src/lib/csp.js)
* MONGO_URI=127.0.0.1:27017/keyserver
* MONGO_USER=keyserver-user
* MONGO_PASS=your_mongo_db_pwd
* SMTP_HOST=smpt.your-email-provider.com
* SMTP_PORT=465
* SMTP_TLS=**true** (if true the connection will use TLS when connecting to server. If false then TLS is used if server supports the STARTTLS extension. In most cases set this value to true if you are connecting to port 465. For port 587 or 25 keep it false.)
* SMTP_STARTTLS=**true** (if this is true and SMTP_TLS is false then Nodemailer tries to use STARTTLS even if the server does not advertise support for it.)
* SMTP_PGP=**true** (encrypt verification message with public key (allows to verify presence + usability of private key at owner of the email address))
* SMTP_USER=smtp_user
* SMTP_PASS=smtp_pass
* SENDER_NAME="OpenPGP Key Server"
* SENDER_EMAIL=noreply@your-key-server.net
* PUBLIC_KEY_PURGE_TIME=**14** (number of days after which uploaded keys are deleted if they have not been verified)
* UPLOAD_RATE_LIMIT=10 (key upload rate limit per email address in the PUBLIC_KEY_PURGE_TIME period)

The following variables are available to customize the filtering behavior as outlined in [Abuse resistant key server](#abuse-resistant-key-server):

* PURIFY_KEY=**true** (main switch to enable filtering of keys)
* MAX_NUM_USER_EMAIL=**20** (max. number of email addresses per key)
* MAX_NUM_SUBKEY=**20** (max. number of subkeys per key)
* MAX_NUM_CERT=**5** (max. number of superseding certificates)
* MAX_SIZE_USERID=**1024**
* MAX_SIZE_PACKET=**8383**
* MAX_SIZE_KEY=**32768**

### Notes on SMTP

The key server uses [nodemailer](https://nodemailer.com) to send out emails upon public key upload to verify email address ownership. To test this feature locally, configure `SMTP_USER` and `SMTP_PASS` settings to your email test account. Make sure that `SMTP_USER` and `SENDER_EMAIL` match.

For production you should use a service like [Amazon SES](https://aws.amazon.com/ses/), [Mailgun](https://www.mailgun.com/) or [Sendgrid](https://sendgrid.com/use-cases/transactional-email/). Nodemailer supports all of these out of the box.

### Docker compose

Docker images are built from this repository and available at ghcr. You can use the sample docker-compose.yml - review it and populate an .env file with the required [settings](#Settings) before running the server. `BASE_URL` must be set to the public-facing URL of your key server. To create the database automatically, the following parameters are needed in .env file:

```
BASE_URL=https://keyserver
MONGO_URI=mongodb:27017/keyserver_db
MONGO_USER=keyserver
MONGO_PASS=somepassword
MONGO_INITDB_DATABASE=keyserver_db
```

The sample docker-compose.yml uses [Caddy](https://caddyserver.com/) as a reverse proxy in front of the key server. The included `Caddyfile` terminates TLS with Caddy's internal certificate authority (self-signed, suitable for internal-only deployments such as this one) and adds security headers (HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`). If the key server needs to be reachable from the public internet instead, replace `tls internal` in the `Caddyfile` with your real hostname so Caddy obtains a certificate via ACME/Let's Encrypt automatically, and adjust `BASE_URL` accordingly.

#### Restricting access by network

Caddy only proxies requests coming from the networks listed in `KEYSERVER_ALLOWED_IPS`, a space separated list of CIDRs set in `.env`. Everything else is answered with a 403 and never reaches the key server:

```
KEYSERVER_ALLOWED_IPS=10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.1/32 ::1
```

Narrow this to the ranges that should actually have access. Two behaviours are worth knowing, both verified against Caddy:

* Removing the line falls back to the defaults shown above (the RFC 1918 ranges plus loopback).
* Setting it to an empty value denies **every** client, including loopback. This fails closed rather than open, but it does mean a blank value locks everyone out.

The matcher uses `remote_ip`, the address on the connection, which is correct while Caddy is the edge. If you put a load balancer in front of Caddy, switch to `client_ip` and declare the balancer under `servers { trusted_proxies }` — otherwise every request appears to originate from the balancer and the allowlist no longer discriminates.

Note that the verification links in outgoing emails point at `BASE_URL`. If recipients open them from outside the allowed ranges the request is refused, so the allowlist needs to cover wherever users read their mail.

Caddy writes a JSON access log to stdout covering both served and refused requests, so `docker compose logs caddy` carries the audit trail.

#### Geographic filtering

Requests from outside the countries listed in `KEYSERVER_ALLOWED_COUNTRIES` (space separated ISO 3166-1 alpha-2 codes, default `NO`) are refused with a 403.

The check applies only to clients that have a geographic location. **Private addresses do not**, and this is the part that bites: the lookup returns `UNK` for any address the database has no record of, and `UNK` matches no allow list, so a bare geo matcher refuses every RFC 1918 client — that is, all your internal traffic. The `Caddyfile` therefore excludes private ranges from the check explicitly rather than trusting the database to place them.

Note also that the geo matcher and its bypass both use `client_ip`, while the network allowlist uses `remote_ip`. The geolocation module reads the client IP itself, so the bypass has to use the same notion of the address or the two would disagree. With no `trusted_proxies` configured the two are identical; behind a load balancer they are not.

Verified against a synthetic country database:

| Client                        | Result |
| :---------------------------- | :----- |
| internal, no geo data         | served |
| Norway                        | served |
| Russia                        | 403    |
| United States (not permitted) | 403    |
| public address, unknown to the database | 403 |

A country database is required at `geoip/country.mmdb` and **Caddy will not start without it** — see [geoip/README.md](geoip/README.md) for where to get one and how to keep it current. It is deliberately not in version control.

One caveat worth being clear about: while `KEYSERVER_ALLOWED_IPS` permits only private ranges, the geo check never fires, because those clients are refused by the allowlist before it and internal clients bypass it. Geographic filtering only starts doing work once the allowlist is widened to admit public addresses. To remove it, delete the `@geo_refused` matcher and its `handle` block from the `Caddyfile`.

#### Web application firewall

Caddy runs [OWASP Coraza](https://coraza.io/) with the [OWASP Core Rule Set](https://coreruleset.org/). Coraza is a Caddy module and modules are compiled in, so the proxy is built from `caddy.Dockerfile` rather than pulled from the stock image. `docker compose up --build` handles this; the build needs network access to `proxy.golang.org`.

The rule engine is set by `KEYSERVER_WAF_MODE`, defaulting to `On`:

| Value           | Behaviour                                        |
| :-------------- | :----------------------------------------------- |
| `On`            | Refuses requests that exceed the anomaly score    |
| `DetectionOnly` | Logs what it would have refused, refuses nothing  |
| `Off`           | Disables the WAF                                  |

##### The key upload exclusion

An armored OpenPGP key is a high-entropy base64 block, and the Core Rule Set matches inside it. The command injection rules 932230, 932250 and 932370 fire on the key material for an anomaly score of 10 against a threshold of 5, and the upload is refused.

This does not affect every key, and which keys it affects cannot be predicted. Measured across 13 keys — the six fixtures plus seven generated across RSA 2048/3072/4096 and curve25519, P-256 and P-521 — two were refused with the exclusion removed: a 9.7 kB RSA 4096 key and a 714 byte NIST P-256 key. A 16 kB RSA 4096 key was not. It tracks neither algorithm nor size, only whether the base64 happens to contain a byte sequence matching one of the regexes, so roughly one key in seven in that sample. In practice that means some users' keys are refused and others are not, with no pattern an operator could reason about.

That unpredictability is the reason the exclusion is scoped by rule tag rather than by rule ID: 932370 only appeared once a wider set of keys was tested, and pinning the two rules seen first would have left it to fail later on somebody's key.

The `Caddyfile` takes the key itself out of the reach of those rules on `/api/v1/key` and `/pks/add`, rather than switching them off for those endpoints:

```
ctl:ruleRemoveTargetByTag=attack-rce;REQUEST_BODY
ctl:ruleRemoveTargetByTag=attack-rce;ARGS:publicKeyArmored
ctl:ruleRemoveTargetByTag=attack-rce;ARGS:keytext
ctl:ruleRemoveTargetByTag=attack-rce;ARGS:/^json\..*/
```

Both the raw body and the parsed JSON collection are listed because, depending on the key, the rules matched one or the other: an earlier version excluding only the raw body still refused `key4`, while the other keys tested alongside it were served.

What this leaves in force on those two endpoints:

* the command injection rules still run, and still inspect the URI, query string, headers and cookies
* every other rule family, SQL injection and XSS included, still inspects the request body

Verified with `SecRuleEngine On` against 13 keys — the six in `test/fixtures` (RSA 1024/2048/4096 and ed25519) plus seven generated across RSA 2048/3072/4096, a multi-user-ID RSA 4096, curve25519, P-256 and P-521 — over both the JSON REST endpoint and the HKP form endpoint. All 13 are served, while command injection in the query string of the key endpoints, SQL injection in the key endpoint's JSON body, and attacks on other paths are all refused.

##### Tuning

Thirteen keys are not every key. A key with a different byte sequence may match a rule family this exclusion does not cover, and the symptom is one user's upload being refused while everyone else's works. Drop to `DetectionOnly` and read the audit log:

```shell
docker compose logs caddy | grep 949110   # requests that exceeded the anomaly score
docker compose logs caddy | grep -o 'id "[0-9]\{6\}"' | sort | uniq -c | sort -rn
```

Extend the exclusion with the rule tag or ID involved, scoped the same way, rather than lowering the anomaly threshold globally or dropping whole rule families for the path.

### Theming

The web UI follows the conventions of [Designsystemet](https://designsystemet.no/), Digdir's design system for the Norwegian public sector: Inter as the typeface, a layered token model, a rem-based sizing scale, understated corner radii and a high-visibility focus ring.

All design tokens live in `:root` in `src/static/css/politiet.css` and are named after their Designsystemet counterparts (`--ds-color-accent-base-default`, `--ds-color-neutral-text-subtle`, and so on). No component rule hardcodes a colour, so adjusting the palette — for example to the exact values from the Politiet design manual — only means editing that one block.

Inter is self-hosted under `src/static/fonts/` (SIL Open Font License 1.1, see `inter-LICENSE.txt`) rather than loaded from a CDN, both so the server has no third-party runtime dependency and so the page stays within the `default-src 'self'` content security policy enabled by `CSP_HEADER`.

The brand mark in the header is a generic shield, not the Politiet emblem. Use of the official emblem is restricted, so replacing it is a decision for whoever owns the visual identity.

## Run tests

```shell
npm test
```

## Start local server

```shell
npm start
```

# License

AGPL v3.0

See the [LICENSE](https://raw.githubusercontent.com/mailvelope/keyserver/master/LICENSE) file for details

## Libraries

Among others, this project relies on the following open source libraries:

* [OpenPGP.js](https://openpgpjs.org/)
* [Nodemailer](https://nodemailer.com/)
* [hapi](https://hapi.dev/)
* [mongodb](https://mongodb.github.io/node-mongodb-native/)
