#!/bin/bash

set -e

cd "$(dirname "$0")"
[ "$ROOT_DIR" ] || export ROOT_DIR="$(realpath ..)"
[ "$ROOT_DIR" ]
cd "$ROOT_DIR"

for cmd in xmllint; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

echo '----------------------------------------------------------------'
echo '              Measure link quality to maven mirrors             '
echo '----------------------------------------------------------------'

TOPK="$(set -e +x >/dev/null
        printf '%s\n' "$TOPK" '5' | grep . | head -n1
    )"                                                                  \
. "$ROOT_DIR/geo/best-httping.sh"                                       \
    https://maven-central-asia.storage-download.googleapis.com/maven2/  \
    https://maven-central-eu.storage-download.googleapis.com/maven2/    \
    https://maven-central.storage-download.googleapis.com/maven2/       \
    https://maven-central.storage.googleapis.com/                       \
    https://maven.aliyun.com/repository/public/                         \
    https://mirrors.163.com/maven/repository/maven-public/              \
    https://repo.maven.apache.org/maven2/                               \
    https://repo1.maven.org/maven2/                                     \
    https://repository.jboss.org/nexus/content/repositories/central/
[ "$LINK_QUALITY" ]

printf '%s\n' "$LINK_QUALITY" | column -t | sed 's/^/| /'

[ "$MAVEN_MIRROR" ] || MAVEN_MIRROR="$(printf '%s\n' "$LINK_QUALITY" | head -n1 | cut -d' ' -f2)"
[ "$MAVEN_MIRROR" ]

echo '----------------------------------------------------------------'
echo "| MAVEN_MIRROR | $MAVEN_MIRROR"
echo '----------------------------------------------------------------'

mkdir -p ~/.m2/
printf '%s' "
<settings>
  <mirrors>
    <mirror>
      <id>roaster-geo-mirror-central</id>
      <name>Geo mirror for central</name>
      <mirrorOf>central,gcs-maven-central-mirror,google-maven-central,jboss-maven-central-proxy</mirrorOf>
      <url>$MAVEN_MIRROR</url>
    </mirror>
  </mirrors>
</settings>
"                                       \
| xmllint --encode 'utf-8' --format -   \
| tee ~/.m2/settings.xml
