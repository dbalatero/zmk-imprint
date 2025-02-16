#!/usr/bin/env bash

# Bail on first error
set -e

#  ╭──────────────────────────────────────────────────────────╮
#  │ User vars                                                │
#  ╰──────────────────────────────────────────────────────────╯

# This script assumes all your repos live in this directory
#
# We're expecting the following repos cloned:
#
#   git clone git clone git@github.com:zmkfirmware/zmk.git \
#     "$SRC_DIR/zmk"
#
#   git clone git@github.com:inorichi/zmk-pmw3610-driver.git \
#     "$SRC_DIR/zmk-pmw3610-driver"
#
#   git clone git@github.com:Cyboard-DigitalTailor/zmk-keyboards.git \
#     "$SRC_DIR/zmk-keyboards"
SRC_DIR="$HOME/code"

# Adjust based on your installed version, this should have been set up in
# the local toolchain setup:
#
#   https://zmk.dev/docs/development/local-toolchain/setup/native
export ZEPHYR_SDK_INSTALL_DIR="$SRC_DIR/zephyr-sdk-0.16.3"

# The path to the root of your personal repo config
USER_REPO_DIR="$SRC_DIR/zmk-imprint"

# Where do you want the final firmware files to end up?
FIRMWARE_OUTPUT_DIR="$HOME/Desktop/imprint-firmware"

#  ╭──────────────────────────────────────────────────────────╮
#  │ Script                                                   │
#  ╰──────────────────────────────────────────────────────────╯
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr

# Check if the first argument is --fast
if [[ "$1" == "--fast" ]]; then
  export FAST_BUILD=true
  # Remove the argument so the script can process additional arguments if needed
  shift
fi

mkdir -p "$FIRMWARE_OUTPUT_DIR"

# Make pwd == ~/code/zmk
cd "$SRC_DIR/zmk/app"
echo "Running in: $(pwd)"
echo

function update_repo() {
  (cd "$SRC_DIR/$1" && git pull)
}

echo "Start time: $(date)" >  duration

if [[ "$FAST_BUILD" == "true" ]]; then
  echo "Skipping updating repos and west"
else
  echo "Updating ZMK"
  update_repo zmk
  echo

  echo "Updating zmk-pmw3610-driver"
  update_repo zmk-pmw3610-driver
  echo

  echo "Updating zmk-keyboards"
  update_repo zmk-keyboards
  echo

  echo "Removing previous build artifacts"
  rm -rf build
  mkdir -p build/artifacts
  echo "done!"
  echo

  west update
  echo

  west zephyr-export
  echo
fi

echo "Building left side"
west build -p -d build/left -b assimilator-bt -- \
  -DSHIELD=imprint_left \
  -DZMK_CONFIG="$USER_REPO_DIR/config" \
  -DZMK_EXTRA_MODULES="$SRC_DIR/zmk-keyboards;$SRC_DIR/zmk-pmw3610-driver"
echo

echo "Building right side"
west build -p -d build/right -b assimilator-bt -- \
  -DSHIELD=imprint_right \
  -DZMK_CONFIG="$USER_REPO_DIR/config" \
  -DZMK_EXTRA_MODULES="$SRC_DIR/zmk-keyboards;$SRC_DIR/zmk-pmw3610-driver"
echo

echo "Renaming artifacts"
cp build/left/zephyr/zmk.uf2 build/artifacts/imprint_left-assimilator-bt-zmk.uf2
cp build/right/zephyr/zmk.uf2 build/artifacts/imprint_right-assimilator-bt-zmk.uf2

cp build/artifacts/imprint_left-assimilator-bt-zmk.uf2 "$FIRMWARE_OUTPUT_DIR"
cp build/artifacts/imprint_right-assimilator-bt-zmk.uf2 "$FIRMWARE_OUTPUT_DIR"

ls -l "$FIRMWARE_OUTPUT_DIR"
echo

echo "End time:   $(date)" >>  duration

echo "Build duration"
cat duration
