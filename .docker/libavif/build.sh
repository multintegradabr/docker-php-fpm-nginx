#!/bin/sh
set -eu

source_version=1.0.4-1ubuntu3
package_version=${source_version}+multintegradasec2
fixes=/usr/local/src/libavif-security
export DEBIAN_FRONTEND=noninteractive
export DEB_BUILD_OPTIONS='nodoc parallel=2'
export DEB_BUILD_PROFILES=nodoc
export QUILT_PATCH_OPTS=--fuzz=0

. /etc/os-release
test "$VERSION_ID" = 24.04
# Use the Ubuntu source index, with signatures and hashes verified by APT.
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update
apt-get install -y --no-install-recommends ca-certificates build-essential dpkg-dev quilt
apt-get build-dep -y --no-install-recommends -P nodoc "libavif=$source_version"
mkdir -p /build /packages
cd /build
apt-get source "libavif=$source_version"
apt-get download "libavif16=$source_version"
cd libavif-1.0.4

# The same compiled test must fail on the original source, then pass with the patch.
compile_regression() {
    cc -std=c99 -ffunction-sections -fdata-sections -I "$PWD" -I "$PWD/include" \
        "$fixes/stream-overflow-test.c" -Wl,--gc-sections -o /build/stream-test
}
compile_regression
set +e
/build/stream-test
before_exit=$?
set -e
test "$before_exit" = 1
export QUILT_PATCHES=debian/patches
quilt import -P multintegrada-CVE-2025-48174.patch "$fixes/CVE-2025-48174.patch"
quilt push
quilt import -P multintegrada-CVE-2025-48175.patch "$fixes/CVE-2025-48175.patch"
quilt push
compile_regression
/build/stream-test

# Keep Ubuntu's packaging and codec selection; enable its available upstream tests.
sed -i 's/-DAVIF_BUILD_APPS=ON /-DAVIF_BUILD_TESTS=ON -DAVIF_ENABLE_GTEST=OFF -DAVIF_BUILD_APPS=ON /' debian/rules
sed -i 's/^Maintainer:.*/Maintainer: Multintegrada Local Security Backports <noreply@localhost>/' debian/control
{
    printf 'libavif (%s) noble; urgency=medium\n\n' "$package_version"
    printf '  * Local backports of stream and row-stride overflow fixes (CVE-2025-48174/48175).\n\n'
    printf ' -- Multintegrada Local Security Backports <noreply@localhost>  Fri, 23 Oct 2026 00:00:00 +0000\n\n'
    cat debian/changelog
} > /build/changelog
mv /build/changelog debian/changelog
dpkg-buildpackage -b -us -uc

# Compare the packaged libraries, not a separate hand-built replacement.
dpkg-deb -x "/build/libavif16_${source_version}_$(dpkg --print-architecture).deb" /build/original
dpkg-deb -x "/build/libavif16_${package_version}_$(dpkg --print-architecture).deb" /build/patched
original=$(find /build/original/usr/lib -type f -name 'libavif.so.*')
patched=$(find /build/patched/usr/lib -type f -name 'libavif.so.*')
test -n "$original"
test -n "$patched"
for kind in original patched; do
    case "$kind" in
        original) library=$original ;;
        patched) library=$patched ;;
    esac
    nm -D --defined-only "$library" | awk '{print $2, $3}' | sort > "/build/$kind.symbols"
    readelf -d "$library" | sed -n '/(SONAME)/p;/(NEEDED)/p' | sort > "/build/$kind.linkage"
done
cmp /build/original.symbols /build/patched.symbols
cmp /build/original.linkage /build/patched.linkage
echo 'Packaged libavif: exported symbols, SONAME and linked codecs preserved'

# Exercise the public API against both packaged libraries, including RGB/RGBA,
# 8/12-bit channels and separately overflowing RGB input and all Y/U/V outputs.
cc -std=c99 -Wall -Wextra -Werror -I "$PWD/include" "$fixes/row-stride-test.c" \
    "$original" -o /build/row-stride-test
set +e
LD_LIBRARY_PATH="$(dirname "$original")" /build/row-stride-test
before_exit=$?
set -e
test "$before_exit" = 1
LD_LIBRARY_PATH="$(dirname "$patched")" /build/row-stride-test
cp "/build/libavif16_${package_version}_$(dpkg --print-architecture).deb" /packages/
