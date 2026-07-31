## Tor for Android (LTechnologies0 fork)

Fork of [Gedsh/Tor-Android-build-script](https://github.com/Gedsh/Tor-Android-build-script)
used by **[OnionVPN](https://github.com/LTechnologies0/OnionVPN)** so Tor Android builds and
published binaries are under our control.

Upstream builds Tor for Android from source (GitLab CI / NDK). This fork keeps that pipeline,
**builds pluggable transports from Tor Project sources**, and publishes **GitHub Release**
assets that OnionVPN imports via `scripts/fetch-native-binaries.sh`.

### Download precompiled binaries (OnionVPN source of truth)

Release assets (latest / tagged):

| Component | ABI assets |
|-----------|------------|
| Tor | `libtor-armeabi-v7a.so`, `libtor-arm64-v8a.so`, `libtor-x86_64.so` |
| Lyrebird (obfs4 / meek / webtunnel / snowflake) | `libLyrebird-arm64-v8a.so`, `libLyrebird-x86_64.so`, `libLyrebird-armeabi-v7a.so` |
| Conjure | `libConjure-arm64-v8a.so`, `libConjure-x86_64.so`, … |
| torrc helpers | `CLIENT_TRANSPORT_PLUGIN.txt`, `SHA256SUMS.txt` |

All releases: https://github.com/LTechnologies0/Tor-Android-build-script/releases

### Pluggable transports — build parameters

`scripts/build-pluggable-transports.sh` builds:

| Binary | Upstream | Transports |
|--------|----------|------------|
| `libLyrebird.so` | [lyrebird](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird) | meek_lite, obfs2, obfs3, obfs4, scramblesuit, webtunnel, snowflake |
| `libConjure.so` | [conjure](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/conjure) `./client` | conjure |

**Android / linker (required for [16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)):**

```text
CGO_ENABLED=1 GOOS=android
CGO_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
go build -ldflags '-s -w -checklinkname=0' …
```

- NDK r28+ recommended (`ANDROID_NDK_HOME`)
- `-checklinkname=0` — Tor Browser Android + Go 1.23 ([#41387](https://gitlab.torproject.org/tpo/applications/tor-browser-build/-/issues/41387))
- Tor `external/Makefile` already adds `-Wl,-z,max-page-size=16384` for arm64 / x86_64 `libtor.so`

**torrc (OnionVPN auto-wires the same):**

```text
ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${PT_DIR}/libLyrebird.so
ClientTransportPlugin snowflake exec ${PT_DIR}/libLyrebird.so
ClientTransportPlugin conjure exec ${PT_DIR}/libConjure.so -registerURL https://registration.refraction.network/api
```

Local build:

```bash
export ANDROID_NDK_HOME=/path/to/ndk   # r28+
export PATH="$(go env GOROOT)/bin:$PATH"
./scripts/build-pluggable-transports.sh
# → dist/pts/<abi>/libLyrebird.so libConjure.so
```

### CI / publish

| Workflow | Trigger | What |
|----------|---------|------|
| [`.github/workflows/build-and-publish.yml`](.github/workflows/build-and-publish.yml) | tags `tor-*` / `pt-*` or `workflow_dispatch` | Build PTs + optional libtor republish → GitHub Release |
| [`.github/workflows/publish-binaries.yml`](.github/workflows/publish-binaries.yml) | tags `tor-*` | Legacy libtor-only republish |
| [`.gitlab-ci.yml`](.gitlab-ci.yml) | GitLab | Original Tor NDK r23b jobs |

```bash
# PT-only release
git tag pt-2026.07.31 && git push origin pt-2026.07.31

# Or Actions → Build and publish Tor + PTs → Run workflow
```

### Upstream

- Script / patches: [Gedsh/Tor-Android-build-script](https://github.com/Gedsh/Tor-Android-build-script) @ Apache-2.0
- PTs: Tor Project anti-censorship (lyrebird, conjure)
- Consumer: OnionVPN

## License

Copyright © 2019-2026 by Garmatin Oleksandr invizible.soft@gmail.com  
Fork maintained for OnionVPN / LTechnologies0.

This code is released under the [Apache License version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
