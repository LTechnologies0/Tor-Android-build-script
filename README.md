## Tor for Android (LTechnologies0 fork)

Fork of [Gedsh/Tor-Android-build-script](https://github.com/Gedsh/Tor-Android-build-script)
used by **[OnionVPN](https://github.com/LTechnologies0/OnionVPN)** so Tor Android builds and
published binaries are under our control.

Upstream builds Tor for Android from source (GitLab CI / NDK). This fork keeps that pipeline
and publishes **GitHub Release** assets that OnionVPN imports at build time via
`scripts/fetch-native-binaries.sh`.

### Download precompiled `libtor.so` (OnionVPN source of truth)

Release assets (latest):

| ABI | Asset |
|-----|--------|
| armeabi-v7a | [`libtor-armeabi-v7a.so`](https://github.com/LTechnologies0/Tor-Android-build-script/releases/latest/download/libtor-armeabi-v7a.so) |
| arm64-v8a | [`libtor-arm64-v8a.so`](https://github.com/LTechnologies0/Tor-Android-build-script/releases/latest/download/libtor-arm64-v8a.so) |
| x86_64 | [`libtor-x86_64.so`](https://github.com/LTechnologies0/Tor-Android-build-script/releases/latest/download/libtor-x86_64.so) |

All releases: https://github.com/LTechnologies0/Tor-Android-build-script/releases

### Build (GitLab CI)

Original jobs live in `.gitlab-ci.yml` (NDK r23b). Mirror / republish to GitHub Releases with:

```bash
./scripts/publish-github-release.sh
```

Or let GitHub Actions (`.github/workflows/publish-binaries.yml`) upload assets when you push a `tor-*` tag.

### Upstream

- Script / patches: [Gedsh/Tor-Android-build-script](https://github.com/Gedsh/Tor-Android-build-script) @ Apache-2.0
- Consumer app historically: InviZible Pro

## License

Copyright © 2019-2026 by Garmatin Oleksandr invizible.soft@gmail.com  
Fork maintained for OnionVPN / LTechnologies0.

This code is released under the [Apache License version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
