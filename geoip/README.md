# GeoIP database

The geo matcher in the `Caddyfile` reads `country.mmdb` from this directory.
The file is not in version control: MaxMind's GeoLite2 terms do not permit
redistribution, and a country database goes stale within weeks.

**Caddy will not start without it.** That is deliberate — a geo control that
silently stops filtering is worse than one that fails loudly.

Either source works, both are free:

* [DB-IP IP to Country Lite](https://db-ip.com/db/download/ip-to-country-lite),
  CC BY 4.0, direct download, no account. Attribution is required if you
  redistribute it.
* [MaxMind GeoLite2 Country](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data),
  requires a free account and a license key, and is kept current with
  [`geoipupdate`](https://github.com/maxmind/geoipupdate).

Whichever you pick, place it here as `country.mmdb`:

```shell
# example, DB-IP lite
curl -fsSL "https://download.db-ip.com/free/dbip-country-lite-$(date +%Y-%m).mmdb.gz" \
  | gunzip > geoip/country.mmdb
```

Refresh it on a schedule; address-to-country assignments change continuously.
