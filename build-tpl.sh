#!/bin/bash
# vim: set et sw=2 ts=2:

set -xe

_CURRENT_DIR=$(pwd)
_RELEASE_DIR="release"
_ENCRYPTION_KEY_FILE="$_RELEASE_DIR/ir-ios.gdkey"
_TPL_URL="https://downloads.godotengine.org/?version=4.5.1&flavor=stable&slug=export_templates.tpz&platform=templates"
_TPL_FILE="$_RELEASE_DIR/export_templates.tpz"

# ensure encryption key exists
if [ ! -f $_ENCRYPTION_KEY_FILE ]; then
  echo "Encryption key not found!"
  exit 1
fi

_REQUIRED_TOOLS=(scons zip wget unzip)

# ensure tools are installed
for tool in ${_REQUIRED_TOOLS[@]}; do
  if ! command -v $tool &> /dev/null; then
    echo "$tool not found!"
    exit 1
  fi
done


function apply_patch() {
  # Apply any necessary patches here
  echo "Patching source code..."
  patch -V none -u core/io/file_access_encrypted.cpp -i release/key_magic.patch
}

function revert_patch() {
  # Revert any patches applied
  echo "Reverting patches..."
  patch -R -s -u core/io/file_access_encrypted.cpp -i release/key_magic.patch
}

function build_editor() {
  echo "Building Godot..."
  scons \
    target=editor \
	  production=yes \
    platform=ios
}

function build_ios() {
  export SCRIPT_AES256_ENCRYPTION_KEY=$(cat $_ENCRYPTION_KEY_FILE | xargs)

  _TARGETS=(
    template_release
    template_debug
  )

  for _TARGET in ${_TARGETS[@]}; do
    echo "Building iOS $_TARGET"
    scons \
      arch=arm64 \
      target=$_TARGET \
      production=yes \
      disable_3d=yes \
      disable_advanced_gui=yes \
      disable_physics_3d=yes \
      disable_navigation_3d=yes \
      disable_xr=yes \
      platform=ios
  done

  _IOS_TPL_DIR="release/ios"

  # ensure template dir exists
  if [ ! -d "$_IOS_TPL_DIR" ]; then
    if [ ! -f "$_TPL_FILE" ]; then
      echo "Downloading templates package..."
      wget -O "$_TPL_FILE" "$_TPL_URL"
    fi

    unzip $_TPL_FILE -d $_RELEASE_DIR
    unzip $_RELEASE_DIR/templates/ios.zip -d $_IOS_TPL_DIR
  fi

  cp bin/libgodot.ios.template_release.arm64.a \
    $_IOS_TPL_DIR/libgodot.ios.release.xcframework/ios-arm64/libgodot.a

  cp bin/libgodot.ios.template_debug.arm64.a \
    $_IOS_TPL_DIR/libgodot.ios.debug.xcframework/ios-arm64/libgodot.a

  cd $_IOS_TPL_DIR
  zip -r ../ios.zip ./*
  cd $_CURRENT_DIR
}

apply_patch
trap revert_patch EXIT
if [ "$1" == "ios" ]; then
  build_ios
elif [ "$1" == "editor" ]; then
  build_editor
else
  echo "Unknown platform: $1"
  exit 1
fi
