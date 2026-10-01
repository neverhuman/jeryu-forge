#!/usr/bin/env bash
set -euo pipefail

# BEGIN GENERATED JANKURAI PIN — DO NOT EDIT
export JERYU_JANKURAI_SOURCE_REPO="https://git.neverhuman.org/git/jeryu/jankurai.git"
export JERYU_JANKURAI_VERSION="jankurai 1.6.11"
export JERYU_JANKURAI_SHA256="b05c03bcb0fb2d004d3daa303ae236b8985b39e393567e8f8d274cd9f6f89103"
export JERYU_JANKURAI_SOURCE_REV="2b8312215573eb225075ca0556f1208ae5265b8c"
export JERYU_JANKURAI_SOURCE_TAG="v1.6.11-deadlang-precision-split.4"
export JERYU_JANKURAI_SOURCE_TREE="bc15c67053db2d1e87e25e71276766d055130701"
export JERYU_JANKURAI_SOURCE_ARCHIVE_SHA256="2c8fbbd71a73c978b58bf038f30008b937a16969ec52a528f21ce2d7fa404cf6"
export JERYU_JANKURAI_CARGO_LOCK_SHA256="b9acb981c326226a687d0b6703e4f7ee303148e9e1a6dda1aa03d77988820f6a"
export JERYU_JANKURAI_RUST_TOOLCHAIN="1.95.0"
export JERYU_JANKURAI_RUSTC_VERSION="rustc 1.95.0 (59807616e 2026-04-14)"
export JERYU_JANKURAI_CARGO_VERSION="cargo 1.95.0 (f2d3ce0bd 2026-03-21)"
export JERYU_JANKURAI_TARGET_TRIPLE="x86_64-unknown-linux-gnu"
export JERYU_JANKURAI_BUILD_MODE="oci-vendor-locked-offline-workspace-member-v2"
export JERYU_JANKURAI_PACKAGE_PATH="crates/jankurai"
export JERYU_JANKURAI_BUILDER_IMAGE="rust@sha256:d7482085ff5b415f84dba5647ae71606650bdef00db7aeb69f4b3d170c3e4082"
export JERYU_JANKURAI_BUILDER_IMAGE_ID="sha256:d7482085ff5b415f84dba5647ae71606650bdef00db7aeb69f4b3d170c3e4082"
export JERYU_JANKURAI_LINKER_VERSION="GNU ld (GNU Binutils for Debian) 2.40"
export JERYU_JANKURAI_GLIBC_VERSION="ldd (Debian GLIBC 2.36-9+deb12u14) 2.36"
export JERYU_JANKURAI_VENDOR_FILES_SHA256="a7e332f4495d9748ea020ae8ee37c4240f0f035059799bd3dc74497437143d99"
export JERYU_JANKURAI_VENDOR_FILE_COUNT="14889"
export JERYU_JANKURAI_CARGO_CONFIG_SHA256="b8982c761d62e447f2d1653c199d2d58e6b2de6c5a6f8ddba3d38e47b7f863d6"
export JERYU_JANKURAI_BUILD_ENVIRONMENT="CARGO_NET_OFFLINE=true,HOME=/tmp,LANG=C,LC_ALL=C,SOURCE_DATE_EPOCH=0,TZ=UTC"
export JERYU_JANKURAI_RUSTFLAGS="--remap-path-prefix=/opt/jeryu/jankurai=/jankurai-build/source --remap-path-prefix=/opt/jeryu/vendor=/jankurai-build/vendor --remap-path-prefix=/opt/jeryu/target=/jankurai-build/target --remap-path-prefix=/usr/local/cargo=/jankurai-build/cargo"
export JERYU_JANKURAI_BUILD_COMMAND="cargo install --locked --offline --path /opt/jeryu/jankurai/crates/jankurai --root /opt/jeryu/out --bin jankurai"
export JERYU_JANKURAI_BUILD_CONTEXT_SHA256="c8303ff86f53ccbcde8b64a1b921cbb61031a2f801ab58440b044fabf76be4a2"
# END GENERATED JANKURAI PIN

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ops/ci/lib.sh"
require_jankurai

just score
