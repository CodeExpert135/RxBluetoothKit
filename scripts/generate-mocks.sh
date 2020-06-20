#!/bin/bash

# Script is generating CoreBluetooth classes mocks with use of sourcekitten and sourcery libraries
# First, is is using sourcekitten (which is using SourceKit) to create intermadiate interfaces of CoreBlueooth classes.
# Nest step is to use this interfaces to generate mocks with use of sourcery.

RED='\033[0;31m'
NC='\033[0m'

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${DIR}"

hash sourcekitten &> /dev/null
if [ $? -eq 1 ]; then
    echo -e "${RED}Could not found sourcekitten command!${NC}"
    echo "Install it with command: brew install sourcekitten"
    exit 1
fi

hash sourcery &> /dev/null
if [ $? -eq 1 ]; then
    echo -e "${RED}Could not found sourcery command!${NC}"
    echo "Install it frome here: https://github.com/krzysztofzablocki/Sourcery#installation"
    exit 1
fi

IOS_VERSION="$1"

if [ -z "$IOS_VERSION" ]; then
	echo "Please specify ios version to compile (default 11.1):"
	read IOS_VERSION
	if [ -z "$IOS_VERSION" ]; then
		IOS_VERSION="11.1"
	fi
fi

echo "Selected iOS version: $IOS_VERSION"

XCODE_PATH=$(xcode-select -p)
echo "Using Xcode path: $XCODE_PATH"

SDK_PATH="${XCODE_PATH}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${IOS_VERSION}.sdk"
if [ ! -d "$SDK_PATH" ]; then
  	echo -e "${RED}Could not found sdk at path: ${SDK_PATH}${NC}"
  	echo "Please specify different IOS_VERSION argument"
  	exit 1
fi

create_yml() {
	echo "
key.request: source.request.editor.open.interface 
key.name: \"47398610-AF42-4F99-B6F2-25A587793CEB\"
key.compilerargs:
- \"-target\"
- \"arm64-apple-ios${IOS_VERSION}\"
- \"-sdk\"
- \"${SDK_PATH}\"
- \"-I\"
- \"-Xcc\"
key.modulename: \"$1\"
key.toolchains:
- \"com.apple.dt.toolchain.XcodeDefault\"
	" > temp.yml
}

create_intermediate_source_file() {
	class=$1
	create_yml $class
	sanitized_class_name=`echo $class | sed "s/.*\.//"`
	echo "Found $class"
	sourcekitten request --yaml temp.yml |
	grep "\"key.sourcetext\" : " |
	cut -c 22- |
	perl -pe 's/\\n/\n/g' |
	sed -e 's/\\\/\\\//\/\//g' -e 's/\\\/\*/\/\*/' -e 's/\*\\\//\*\//' -e 's/^"//' -e 's/"$//' > ./Intermediates/${sanitized_class_name}.swift
}

mkdir -p ./Intermediates

create_intermediate_source_file "CoreBluetooth.CBCentralManager"
create_intermediate_source_file "CoreBluetooth.CBPeripheral"
create_intermediate_source_file "CoreBluetooth.CBDescriptor"
create_intermediate_source_file "CoreBluetooth.CBService"
create_intermediate_source_file "CoreBluetooth.CBCharacteristic"
create_intermediate_source_file "CoreBluetooth.CBL2CAPChannel"
create_intermediate_source_file "CoreBluetooth.CBPeer"
create_intermediate_source_file "CoreBluetooth.CBAttribute"
create_intermediate_source_file "CoreBluetooth.CBManager"

sourcery --sources ./Intermediates --sources ../Source --templates ../Templates --output ../Tests/Autogenerated

rm temp.yml
rm -rf ./Intermediates