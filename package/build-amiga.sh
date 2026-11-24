#!/bin/sh
# The release archive, for the repo CI and a daletop build (the whole build,
# dependencies included, runs past Cradle's 900 s stove_build cap). It runs:
# 1. ports/amigaos3/build-dependencies.sh: SurgeScript, PhysicsFS, Ogg,
#    Vorbis and Allegro (DalsinAI/amigaallegro) at their pinned versions,
#    into a scratch prefix (nothing goes into the stove);
# 2. ports/amigaos3/build-first-pass.sh: the game;
# 3. package/soft-float.sh: every object of all of them, the compile lines,
#    and fpuauto. One -m68040 -msoft-float binary for every 68040 and 68060;
#    the stove's fpuauto (open7 and later) takes the FPU when there is one;
# 4. package/pack.py: opensurge-VERSION-68040.lha, holding the OpenSurge
#    drawer (the stripped program, the game's own data, ReadMe, LICENSE and
#    the licences drawer, with icons) and its icon, with Install-OpenSurge
#    and its icon (made by amicradle's scripts/ports/port_installer.py from
#    package/installer.json) beside them at the root.
# OUT also gets the .sha256, OpenSurge.tar (for a lab), package.json,
# build.log, soft-float.txt and the engine archive the standalone content
# ports take (step 5). STOVE is the os32-gcc16 stove; VERSION is
# package/VERSION. Nothing is published from here.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
OUT=${OUT:-"$ROOT/build-amiga-package"}
VERSION=$(cat "$HERE/VERSION")
STOVE=${STOVE:-${OS32_GCC16:-"$HOME/AmiCradle/kitchen/stoves/os32-gcc16"}}
[ -x "$STOVE/prefix/bin/m68k-amigaos-gcc" ] || [ ! -x "$STOVE/bin/m68k-amigaos-gcc" ] || STOVE=$(dirname "$STOVE")
P="$STOVE/prefix"
mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/opensurge-package.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT INT TERM

export STOVE AMIGA_PORT_PREFIX="$BUILD/prefix" SOURCE_ROOT="$BUILD/deps-src" BUILD_ROOT="$BUILD/deps-build" \
	BUILD_DIR="$BUILD/game" AMIGA_CPU_FLAGS="-m68040 -msoft-float" CMAKE_BUILD_PARALLEL_LEVEL="${JOBS:-2}" VERBOSE=1
# CMakeLists.txt links the game into the source root (run-in-place); start clean.
rm -f "$ROOT/opensurge"
# every compile and link line goes to build.log
# build-first-pass.sh passes GAME_DISTDIR=dist, a PATH that CMake makes absolute against the
# folder it is configured from: configure inside the scratch folder so dist lands there
mkdir -p "$BUILD/inst"
{ sh "$ROOT/ports/amigaos3/build-dependencies.sh" && (cd "$BUILD/inst" && sh "$ROOT/ports/amigaos3/build-first-pass.sh"); } > "$OUT/build.log" 2>&1 \
	|| { tail -n 60 "$OUT/build.log"; exit 1; }
EXE="$ROOT/opensurge"
[ "$(od -An -tx1 -N4 "$EXE" | tr -d ' \n')" = "000003f3" ] || { echo "not an Amiga HUNK executable"; exit 2; }
sh "$HERE/soft-float.sh" "$P" "$EXE" --log "$OUT/build.log" --allow "$HERE/fpu-allow.txt" \
	"$BUILD/deps-build" "$BUILD/game" > "$OUT/soft-float.txt" || { cat "$OUT/soft-float.txt"; exit 2; }
cat "$OUT/soft-float.txt"

cmake --install "$BUILD/game" --strip > "$OUT/install.txt" 2>&1 \
	|| { tail -n 30 "$OUT/install.txt"; exit 1; }
D="$BUILD/dist/OpenSurge"
mkdir -p "$BUILD/dist"
cp -R "$BUILD/inst/dist" "$D"
# the benchmark and fallback executables stay out, as in package.sh
rm -f "$D"/opensurge-*
[ -f "$D/opensurge" ] || { echo "no opensurge in the install"; exit 2; }
cp "$ROOT/AMIGA_PORT.md" "$D/ReadMe"
cp "$ROOT/amiga/icons/opensurge.info" "$ROOT/amiga/icons/ReadMe.info" "$ROOT/amiga/icons/LICENSE.info" "$D/"
cp "$ROOT/amiga/icons/OpenSurge.info" "$BUILD/dist/OpenSurge.info"
python3 "$HERE/pack.py" --dist "$BUILD/dist" --drawer OpenSurge --program opensurge --archive opensurge \
	--version "$VERSION" --installer "$HERE/installer" --source "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)" \
	--compiler "$("$P/bin/m68k-amigaos-gcc" --version | head -n 1)" --out "$OUT"

# 5. The engine archive the standalone content ports (amigaaishireimu,
#    amigasoniclasthope, amigaspeedy) pin in their port/engine.env:
#    dist/ as ports/amigaos3/package.sh packs it (without the benchmark and
#    fallback executables), named as their pins name it, with its .sha256.
#    Owners, order and times are fixed, so the archive's bytes follow from
#    the build's alone.
case $VERSION in
	*-rc*) ENGINE_ASSET="opensurge-${VERSION%-rc*}-68040-rc${VERSION##*-rc}.tar.gz" ;;
	*) ENGINE_ASSET="opensurge-$VERSION-68040.tar.gz" ;;
esac
EPOCH=$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || echo 0)
tar -C "$BUILD/inst" --exclude='dist/opensurge-*' --sort=name --owner=0 --group=0 --numeric-owner \
	--mtime="@$EPOCH" -cf - dist | gzip -n -9 > "$OUT/$ENGINE_ASSET"
(cd "$OUT" && sha256sum "$ENGINE_ASSET" > "$ENGINE_ASSET.sha256")
echo "engine archive: $ENGINE_ASSET $(cut -d' ' -f1 "$OUT/$ENGINE_ASSET.sha256")"
echo "dist/opensurge: $(tar -xzOf "$OUT/$ENGINE_ASSET" dist/opensurge | sha256sum | cut -d' ' -f1)"
