#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
	echo "Invalid shell, re-running using bash..."
	exec bash "$0" "$@"
	exit $?
fi
SRCLOC="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get version tag/hash strings
IOS_GIT_TAG=`(cd "$PROJECT_DIR" && git describe --long)`
echo "iOS git tag: $IOS_GIT_TAG"
CORE_GIT_HASH=`(cd "$PROJECT_DIR/../core" && git log --pretty=format:'%h' -n 1)`
echo "Core git hash: $CORE_GIT_HASH"
RESOURCES_GIT_HASH=`(cd "$PROJECT_DIR/../resources" && git log --pretty=format:'%h' -n 1)`
echo "Resources git hash: $RESOURCES_GIT_HASH"

# Parse version tag string
[[ $IOS_GIT_TAG =~ v([[:digit:]\.]+)([[:alpha:]]?)-([[:digit:]]+)-g([[:xdigit:]]+) ]]
VERSION="${BASH_REMATCH[1]}"
RELEASE="${BASH_REMATCH[2]}"
REVISION="${BASH_REMATCH[3]}"

echo "plist file: '$INFOPLIST_FILE'"

BUILD="$VERSION.$REVISION$RELEASE"
HASH="${BASH_REMATCH[4]}_${CORE_GIT_HASH}_${RESOURCES_GIT_HASH}"

echo "Version: $VERSION.$REVISION$RELEASE ($BUILD)"
echo "Hash: $HASH"

# Generate appversion.prefix
APPVERSION_FILE="$BUILD_ROOT/appversion.prefix"
echo "AppVersion prefix file: '$APPVERSION_FILE'"
rm -f "$APPVERSION_FILE"
echo "" > "$APPVERSION_FILE"
echo "#define OSMAND_VERSION $VERSION.$REVISION$RELEASE" >> "$APPVERSION_FILE"
echo "#define OSMAND_BUILD $BUILD" >> "$APPVERSION_FILE"
echo "#define OSMAND_HASH $HASH" >> "$APPVERSION_FILE"
touch -c -m "$APPVERSION_FILE"

# Touch plist file
#touch -c -m "$INFOPLIST_FILE"
#touch -c -A -01 -m "$INFOPLIST_FILE"

# Output modification times
echo -n "'$INFOPLIST_FILE' : "
stat -f %m "$INFOPLIST_FILE"
echo -n "'$APPVERSION_FILE' : "
stat -f %m "$APPVERSION_FILE"
