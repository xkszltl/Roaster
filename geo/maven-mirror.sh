#!/bin/bash

set -e

for cmd in bc httping parallel xmllint; do
    which "$cmd" > /dev/null
done

echo '----------------------------------------------------------------'
echo '              Measure link quality to maven mirrors             '
echo '----------------------------------------------------------------'

export LINK_QUALITY="$(set -e
    parallel --halt now,success=3 -j0 'bash -c '"'"'
        set -e
        httping -Zfc10 -t3 {} 2>&1                                                                  \
        | sed -n "s/.*[^0-9]\([0-9][0-9]*\) *ok.*time  *\([0-9][0-9]*\) *ms.*/\1\/(\2\+1)\*10^3/p"  \
        | bc -l                                                                                     \
        | xargs -rn1 printf "%.3f\n"                                                                \
        | sed "s/\$/ $(sed "s/\([\\\/\.\-]\)/\\\\\1/g" <<< {})/"                                    \
        | grep .
    '"'" :::                                                                \
        https://maven-central-asia.storage-download.googleapis.com/maven2/  \
        https://maven-central-eu.storage-download.googleapis.com/maven2/    \
        https://maven-central.storage-download.googleapis.com/maven2/       \
        https://maven-central.storage.googleapis.com/                       \
        https://maven.aliyun.com/repository/public/                         \
        https://mirrors.163.com/maven/repository/maven-public/              \
        https://repo.maven.apache.org/maven2/                               \
        https://repo1.maven.org/maven2/                                     \
        https://repository.jboss.org/nexus/content/repositories/central/    \
    2> /dev/null                                                            \
    | sort -nr                                                              \
)"

column -t <<< "$LINK_QUALITY" | sed 's/^/| /'

[ "$MAVEN_MIRROR" ] || MAVEN_MIRROR="$(head -n1 <<< "$LINK_QUALITY" | cut -d' ' -f2)"
[ "$MAVEN_MIRROR" ]

echo '----------------------------------------------------------------'
echo "| MAVEN_MIRROR | $MAVEN_MIRROR"
echo '----------------------------------------------------------------'

mkdir -p ~/.m2/
xmllint --encode 'utf-8' --format - <<< "
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
" | tee ~/.m2/settings.xml
