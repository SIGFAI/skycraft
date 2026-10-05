#!/usr/bin/env bash
# The Fabric jar of an upstream fusion (SkyCraft, FalloutCraft) built by SIGF from a SIGFAI mirror commit, on a clean
# Linux x86_64 machine (Amazon Linux 2023), reproducibly: the build runs twice from a wiped tree and both jars must be
# byte-identical. Upstream's own steps (README: JDK 25, `gradlew build` in fabric/), with `-Pversion=` added so the jar
# says which SIGF revision it is, and `--no-configuration-cache`: upstream's gradle.properties turns Gradle's
# configuration cache on, and a first build of a fresh tree with it leaves Loom's `Fabric-Loom-Client-Only-Entries`
# out of the manifest (upstream's released jar has it). See build-skycraft.md, "The Fabric jar".
#
#   build-fusion-jar.sh <mirror git url> <commit> <version> [<out dir>] [<bundle>]
#     e.g. build-fusion-jar.sh https://github.com/SIGFAI/skycraft <40 hex> 0.1.2+sigf.1
#   <bundle>: a git bundle holding <commit> when it is not pushed yet (fetched on top of the clone).
#   UPSTREAM_CHECK="<commit> <version> <sha256>": also build that commit (upstream's unpatched tree) and report whether
#   it gives upstream's released jar byte for byte.
#
# Writes <out>/<jar>, <out>/jar-build-info.json, <out>/build.log. Exit 0 only when the two builds are identical.
set -euo pipefail
REPO=$1 COMMIT=$2 VERSION=$3 OUT=${4:-/opt/jarbuild/out} BUNDLE=${5:-}
WORK=/opt/jarbuild
mkdir -p "$WORK" "$OUT"
LOG=$OUT/build.log
exec > >(tee -a "$LOG") 2>&1
say() { echo "$(date -u +%H:%M:%S) $*"; }

# JDK 25 (Amazon Corretto, the distribution's package) and git. Versions are recorded below.
if ! command -v javac >/dev/null || ! javac -version 2>&1 | grep -q ' 25'; then
  say 'installing Corretto 25 + git'
  dnf install -y -q java-25-amazon-corretto-devel git >/dev/null
fi
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
export GRADLE_USER_HOME=$WORK/gradle-home
export SOURCE_DATE_EPOCH=0 TZ=UTC LC_ALL=C.UTF-8

checkout() {   # <dir> <commit>
  local dir=$1 sha=$2
  if [ ! -d "$dir/.git" ]; then git clone -q --filter=blob:none "$REPO" "$dir"; fi
  if [ -n "$BUNDLE" ]; then git -C "$dir" fetch -q "$BUNDLE" "+refs/heads/*:refs/remotes/bundle/*"; fi
  git -C "$dir" -c advice.detachedHead=false checkout -q --force "$sha"
  git -C "$dir" clean -qfdx
  [ "$(git -C "$dir" rev-parse HEAD)" = "$sha" ] || { echo "$dir is not at $sha"; exit 1; }
}

build() {   # <dir> <version> -> prints the jar's path
  local dir=$1/fabric ver=$2
  rm -rf "$dir/build" "$dir/.gradle"
  (cd "$dir" && chmod +x gradlew && ./gradlew --no-daemon --no-configuration-cache --console=plain -q "-Pversion=$ver" build >&2)
  ls "$dir"/build/libs/*.jar | grep -v -- '-sources\.jar$'
}

SRC=$WORK/src
checkout "$SRC" "$COMMIT"
say "building $REPO at $COMMIT, version $VERSION"
jar1=$(build "$SRC" "$VERSION"); sha1=$(sha256sum "$jar1" | cut -d' ' -f1)
cp "$jar1" "$WORK/first.jar"
say "first build  $(basename "$jar1") sha256 $sha1"
jar2=$(build "$SRC" "$VERSION"); sha2=$(sha256sum "$jar2" | cut -d' ' -f1)
say "second build (wiped build/ and .gradle/) sha256 $sha2 ($([ "$sha1" = "$sha2" ] && echo identical || echo DIFFERENT))"
cp "$jar2" "$OUT/"
unzip -p "$jar2" META-INF/MANIFEST.MF | grep -q '^Fabric-Loom-Client-Only-Entries:' || { say 'no Fabric-Loom-Client-Only-Entries in the manifest'; exit 1; }

upstream_json=null
if [ -n "${UPSTREAM_CHECK:-}" ]; then
  read -r up_commit up_version up_sha <<<"$UPSTREAM_CHECK"
  UP=$WORK/upstream
  checkout "$UP" "$up_commit"
  upjar=$(build "$UP" "$up_version"); got=$(sha256sum "$upjar" | cut -d' ' -f1)
  say "upstream tree $up_commit (version $up_version): sha256 $got, upstream's release jar $up_sha ($([ "$got" = "$up_sha" ] && echo identical || echo different))"
  upstream_json="{\"commit\":\"$up_commit\",\"version\":\"$up_version\",\"sha256\":\"$got\",\"release_sha256\":\"$up_sha\",\"identical\":$([ "$got" = "$up_sha" ] && echo true || echo false)}"
fi

loom=$(find "$GRADLE_USER_HOME/caches" -path '*fabric-loom*' -name '*.jar' 2>/dev/null | sed -n 's#.*/\(fabric-loom[^/]*\.jar\)$#\1#p' | sort -u | tr '\n' ' ')
gradle_v=$(cd "$SRC/fabric" && ./gradlew --no-daemon -q --version | sed -n 's/^Gradle //p')
cat >"$OUT/jar-build-info.json" <<EOF
{
  "jar": { "file": "$(basename "$jar2")", "sha256": "$sha2", "size": $(stat -c %s "$jar2"), "rebuild_sha256": "$sha1" },
  "source": { "repo": "$REPO", "commit": "$COMMIT", "project": "fabric/" },
  "command": "cd fabric && ./gradlew --no-daemon --no-configuration-cache -Pversion=$VERSION build",
  "toolchain": {
    "java": "$(java -version 2>&1 | sed -n 2p | sed 's/"/\\"/g')",
    "javac": "$(javac -version 2>&1)",
    "corretto_rpm": "$(rpm -q java-25-amazon-corretto-devel 2>/dev/null || true)",
    "gradle": "$gradle_v",
    "loom": "$(echo "$loom" | sed 's/ *$//')",
    "git": "$(git --version)",
    "os": "$(. /etc/os-release && echo "$PRETTY_NAME") $(uname -m)"
  },
  "upstream_check": $upstream_json,
  "built_at": "$(date -u +%FT%TZ)"
}
EOF
say "done: $OUT"
[ "$sha1" = "$sha2" ]
