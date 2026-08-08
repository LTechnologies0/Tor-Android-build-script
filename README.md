## Tor for Android (LTechnologies0 fork)

Fork of [Gedsh/Tor-Android-build-script](https://github.com/Gedsh/Tor-Android-build-script)
used by **[OnionVPN](https://github.com/LTechnologies0/OnionVPN)** so Tor Android builds and
published binaries are under our control.

This fork **builds everything from source in GitHub Actions** (OpenSSL, libevent, zstd, xz,
**zlib**, Tor, lyrebird, conjure). Binaries are **not** republished from Gedsh or other third-party CI.

Pins live in [`versions.properties`](versions.properties). Dependabot only updates Actions;
GitLab/GitHub pins are refreshed by [`.github/workflows/update-upstream-pins.yml`](.github/workflows/update-upstream-pins.yml).

### Download precompiled binaries (OnionVPN source of truth)

Release assets (latest / tagged):

| Component | ABI assets |
|-----------|------------|
| Tor | `libtor-arm64-v8a.so`, `libtor-x86_64.so` |
| Lyrebird (obfs4 / meek / webtunnel / snowflake) | `libLyrebird-arm64-v8a.so`, `libLyrebird-x86_64.so` |
| Conjure | `libConjure-arm64-v8a.so`, `libConjure-x86_64.so` |
| torrc helpers | `CLIENT_TRANSPORT_PLUGIN.txt`, `SHA256SUMS.txt` |

All releases: https://github.com/LTechnologies0/Tor-Android-build-script/releases

### Standalone linking

Android-packaged binaries cannot be fully `-static` (Bionic). Target:

`NEEDED ⊆ {libc, libm, libdl, liblog}`

Tor links OpenSSL, libevent, zstd, xz, and **zlib** as static `.a` (`--enable-static-zlib`).
Gate: `./scripts/verify-android-standalone.sh dist/tor/libtor-arm64-v8a.so`

### Build Tor (`libtor.so`) locally

```bash
export ANDROID_NDK_HOME=/path/to/ndk   # r28+
./scripts/build-libtor.sh
# → dist/tor/libtor-arm64-v8a.so  dist/tor/libtor-x86_64.so
```

- Pins: see `versions.properties` (OpenSSL, zlib, Gedsh tor `prod-0.4.9`, …).
- **arm64** defaults to `ENABLE_MTE=1` (`-fsanitize=memtag`) for GrapheneOS / OnionVPN
  `android:memtagMode="async"`. Disable with `ENABLE_MTE=0`.
- 16 KB page size: `-Wl,-z,max-page-size=16384` on 64-bit ABIs.

### Pluggable transports — build parameters

`scripts/build-pluggable-transports.sh` builds:

| Binary | Upstream | Transports |
|--------|----------|------------|
| `libLyrebird.so` | [lyrebird](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird) (pinned tag) | meek_lite, obfs2, obfs3, obfs4, scramblesuit, webtunnel, snowflake |
| `libConjure.so` | [conjure](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/conjure) `./client` (pinned SHA) | conjure |

Optional DNSCrypt: `./scripts/build-dnscrypt-proxy.sh` → `dist/dnscrypt/<abi>/libdnscrypt-proxy.so`

**Android / linker (required for [16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)):**

```text
CGO_ENABLED=1 GOOS=android
CGO_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
go build -buildmode=pie -ldflags '-s -w -checklinkname=0 -extldflags …' …
```

- NDK r28+ recommended (`ANDROID_NDK_HOME`)
- `-checklinkname=0` — Tor Browser Android + Go 1.23 ([#41387](https://gitlab.torproject.org/tpo/applications/tor-browser-build/-/issues/41387))

**torrc (OnionVPN auto-wires the same):**

```text
ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${PT_DIR}/libLyrebird.so
ClientTransportPlugin snowflake exec ${PT_DIR}/libLyrebird.so
ClientTransportPlugin conjure exec ${PT_DIR}/libConjure.so -registerURL https://registration.refraction.network/api
```

```bash
export ANDROID_NDK_HOME=/path/to/ndk   # r28+
export PATH="$(go env GOROOT)/bin:$PATH"
./scripts/build-pluggable-transports.sh
# → dist/pts/<abi>/libLyrebird.so libConjure.so
```

### CI / publish

| Workflow | Trigger | What |
|----------|---------|------|
| [`.github/workflows/build-and-publish.yml`](.github/workflows/build-and-publish.yml) | tags `tor-*` / `pt-*` or `workflow_dispatch` | Build libtor + PTs from source → GitHub Release |
| [`.github/workflows/update-upstream-pins.yml`](.github/workflows/update-upstream-pins.yml) | weekly / manual | PR bumping `versions.properties` |
| Dependabot | weekly | GitHub Actions updates |

After publish, optional `ONIONVPN_DISPATCH_TOKEN` secret triggers OnionVPN `tor-natives-release`.

```bash
# Full Tor + PT release
git tag tor-0.4.9.11-dev+staticz && git push origin tor-0.4.9.11-dev+staticz

# PT-only
git tag pt-2026.08.08 && git push origin pt-2026.08.08

# Or Actions → Build and publish Tor + PTs → Run workflow
```

### Upstream

- Script / patches: [Gedsh/Tor-Android-build-script](https://github.com/Gedsh/Tor-Android-build-script) @ Apache-2.0
- Tor sources: [Gedsh/tor](https://gitlab.torproject.org/Gedsh/tor) `prod-0.4.9` (track [tpo/core/tor](https://gitlab.torproject.org/tpo/core/tor) via `tor.upstream.tag`)
- PTs: Tor Project anti-censorship (lyrebird, conjure)
- Consumer: [OnionVPN](https://github.com/LTechnologies0/OnionVPN)

## License

Copyright © 2019-2026 by Garmatin Oleksandr invizible.soft@gmail.com  
Fork maintained for OnionVPN / LTechnologies0.

This code is released under the Apache License version 2.0
