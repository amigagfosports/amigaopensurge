#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PREFIX=${AMIGA_PORT_PREFIX:-"$ROOT/build/amigaos3-prefix"}
SOURCE_ROOT=${SOURCE_ROOT:-"$ROOT/build/deps-src"}
BUILD_ROOT=${BUILD_ROOT:-"$ROOT/build/deps-build"}
TOOLCHAIN="$ROOT/ports/amigaos3/toolchain.cmake"
PATCH_ROOT="$ROOT/ports/amigaos3/patches"
AMIGA_STOVE_PATH=${STOVE:-"$HOME/AmigaChrome/stoves/os32-gcc16"}
AMIGA_SYSROOT="$AMIGA_STOVE_PATH/prefix/m68k-amigaos"
AMIGA_SDK_DEPS="$AMIGA_SYSROOT/port-deps"
# One soft-float binary for every 68040 and 68060: the stove's fpuauto (open7 and
# later) takes the FPU when there is one. Allegro's own toolchain needs it passed.
AMIGA_CPU_FLAGS=${AMIGA_CPU_FLAGS:-"-m68040 -msoft-float"}

fetch_source() {
    name=$1
    url=$2
    tag=$3
    expected=$4
    destination="$SOURCE_ROOT/$name"

    if [ ! -d "$destination/.git" ]; then
        git clone --depth 1 --branch "$tag" "$url" "$destination"
    fi

    actual=$(git -C "$destination" rev-parse HEAD)
    if [ "$actual" != "$expected" ]; then
        echo "$name source mismatch: expected $expected, found $actual" >&2
        exit 2
    fi
}

fetch_commit() {
    name=$1
    url=$2
    expected=$3
    destination="$SOURCE_ROOT/$name"

    if [ ! -d "$destination/.git" ]; then
        git clone --filter=blob:none --no-checkout "$url" "$destination"
    fi

    if ! git -C "$destination" cat-file -e "$expected^{commit}" 2>/dev/null; then
        git -C "$destination" fetch --depth 1 origin "$expected"
    fi
    git -C "$destination" switch --detach "$expected"
}

apply_once() {
    source_dir=$1
    patch_file=$2

    if git -C "$source_dir" apply --check "$patch_file" 2>/dev/null; then
        git -C "$source_dir" apply "$patch_file"
    elif git -C "$source_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
        : # already applied
    else
        echo "patch does not apply cleanly: $patch_file" >&2
        exit 2
    fi
}

mkdir -p "$PREFIX" "$SOURCE_ROOT" "$BUILD_ROOT"

fetch_source surgescript https://github.com/alemart/surgescript.git v0.6.1 \
    56bd599302bbca1eea91d0dc8353257845b314ea
apply_once "$SOURCE_ROOT/surgescript" \
    "$PATCH_ROOT/surgescript-0.6.1-amiga-alignment.patch"

cmake -S "$SOURCE_ROOT/surgescript" -B "$BUILD_ROOT/surgescript" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DAMIGA_PORT_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DWANT_SHARED=OFF \
    -DWANT_STATIC=ON \
    -DWANT_EXECUTABLE=OFF \
    -DWANT_BUILD_DATE=OFF
cmake --build "$BUILD_ROOT/surgescript" --parallel
cmake --install "$BUILD_ROOT/surgescript"

fetch_source physfs https://github.com/icculus/physfs.git release-3.2.0 \
    eb3383b532c5f74bfeb42ec306ba2cf80eed988c
apply_once "$SOURCE_ROOT/physfs" \
    "$PATCH_ROOT/physfs-3.2.0-amiga-platform.patch"

cmake -S "$SOURCE_ROOT/physfs" -B "$BUILD_ROOT/physfs" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DAMIGA_PORT_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DPHYSFS_BUILD_SHARED=OFF \
    -DPHYSFS_BUILD_STATIC=ON \
    -DPHYSFS_BUILD_TEST=OFF \
    -DPHYSFS_BUILD_DOCS=OFF \
    -DPHYSFS_ARCHIVE_ZIP=ON \
    -DPHYSFS_ARCHIVE_7Z=OFF \
    -DPHYSFS_ARCHIVE_GRP=OFF \
    -DPHYSFS_ARCHIVE_WAD=OFF \
    -DPHYSFS_ARCHIVE_HOG=OFF \
    -DPHYSFS_ARCHIVE_MVL=OFF \
    -DPHYSFS_ARCHIVE_QPAK=ON \
    -DPHYSFS_ARCHIVE_SLB=OFF \
    -DPHYSFS_ARCHIVE_ISO9660=OFF \
    -DPHYSFS_ARCHIVE_VDF=OFF
cmake --build "$BUILD_ROOT/physfs" --parallel
cmake --install "$BUILD_ROOT/physfs"

fetch_source ogg https://github.com/xiph/ogg.git v1.3.5 \
    e1774cd77f471443541596e09078e78fdc342e4f
cmake -S "$SOURCE_ROOT/ogg" -B "$BUILD_ROOT/ogg" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DAMIGA_PORT_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_SHARED_LIBS=OFF \
    -DINSTALL_DOCS=OFF
cmake --build "$BUILD_ROOT/ogg" --parallel
cmake --install "$BUILD_ROOT/ogg"

fetch_source vorbis https://github.com/xiph/vorbis.git v1.3.7 \
    0657aee69dec8508a0011f47f3b69d7538e9d262
cmake -S "$SOURCE_ROOT/vorbis" -B "$BUILD_ROOT/vorbis" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DAMIGA_PORT_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_SHARED_LIBS=OFF
cmake --build "$BUILD_ROOT/vorbis" --parallel
cmake --install "$BUILD_ROOT/vorbis"

fetch_commit amigaallegro https://github.com/amigagfosports/amigaallegro.git \
    a55b4b2ea532b22809f813fd61c2e99d9a045139

cmake -S "$SOURCE_ROOT/amigaallegro" -B "$BUILD_ROOT/amigaallegro" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_TOOLCHAIN_FILE="$SOURCE_ROOT/amigaallegro/cmake/Toolchain-amigaos3.cmake" \
    -DAMIGA_STOVE="$AMIGA_STOVE_PATH" \
    -DAMIGA_CPU_FLAGS="$AMIGA_CPU_FLAGS" \
    -DAMIGA_PORT_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DALLEGRO_SDL=ON \
    -DALLEGRO_AMIGA_BITMAP_BATCH_LIMIT=0 \
    -DSHARED=OFF \
    -DWANT_MONOLITH=ON \
    -DWANT_ALLOW_SSE=OFF \
    -DWANT_DOCS=OFF \
    -DWANT_TESTS=OFF \
    -DWANT_EXAMPLES=OFF \
    -DWANT_DEMO=OFF \
    -DWANT_OPENAL=OFF \
    -DWANT_VIDEO=OFF \
    -DWANT_NATIVE_DIALOG=OFF \
    -DWANT_IMAGE_FREEIMAGE=OFF \
    -DWANT_IMAGE_WEBP=OFF \
    -DWANT_IMAGE_JPG=ON \
    -DWANT_IMAGE_PNG=ON \
    -DWANT_PHYSFS=ON \
    -DPHYSFS_INCLUDE_DIR="$PREFIX/include" \
    -DPHYSFS_LIBRARY="$PREFIX/lib/libphysfs.a" \
    -DSDL2_INCLUDE_DIR="$AMIGA_SYSROOT/include/SDL2" \
    -DSDL2_LIBRARY_TEMP="$AMIGA_SYSROOT/lib/libSDL2.a" \
    -DOPENGL_gl_LIBRARY="$AMIGA_SYSROOT/lib/libGL.a" \
    -DOPENGL_INCLUDE_DIR="$AMIGA_SYSROOT/include" \
    -DFREETYPE_INCLUDE_DIRS="$AMIGA_SDK_DEPS/include/freetype2" \
    -DFREETYPE_LIBRARY="$AMIGA_SDK_DEPS/lib/libfreetype.a" \
    -DPNG_PNG_INCLUDE_DIR="$AMIGA_SDK_DEPS/include" \
    -DPNG_LIBRARY="$AMIGA_SDK_DEPS/lib/libpng.a" \
    -DZLIB_INCLUDE_DIR="$AMIGA_SDK_DEPS/include" \
    -DZLIB_LIBRARY="$AMIGA_SDK_DEPS/lib/libz.a" \
    -DJPEG_INCLUDE_DIR="$AMIGA_SDK_DEPS/include" \
    -DJPEG_LIBRARY="$AMIGA_SDK_DEPS/lib/libjpeg.a" \
    -DOGG_INCLUDE_DIR="$PREFIX/include" \
    -DOGG_LIBRARY="$PREFIX/lib/libogg.a" \
    -DVORBIS_INCLUDE_DIR="$PREFIX/include" \
    -DVORBIS_LIBRARY="$PREFIX/lib/libvorbis.a" \
    -DVORBISFILE_LIBRARY="$PREFIX/lib/libvorbisfile.a" \
    -DALLEGRO_HAVE_FSEEKO=0 \
    -DALLEGRO_HAVE_FTELLO=0 \
    -DALLEGRO_HAVE_STRERROR_R=0 \
    -DALLEGRO_HAVE_STRERROR_S=0
cmake --build "$BUILD_ROOT/amigaallegro" --parallel
cmake --install "$BUILD_ROOT/amigaallegro"

echo "Installed AmigaOS target dependencies in $PREFIX"
