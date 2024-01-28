#!/bin/env bash

# Define compile function
function compile() {
  # Load environment variables
  source ~/.bashrc
  source ~/.profile

  # Set environment variables
  export LC_ALL=C
  export USE_CCACHE=1
  export ARCH=arm64
  export SUBARCH=arm64

  export KBUILD_BUILD_HOST="PrathamsBuilds"
  export KBUILD_BUILD_USER="Pratham"

  # Allocate 100GB of memory to ccache
  ccache -M 100G

  # Download clang if not present
  if [[ ! -d "clang" ]]; then
    aria2c -x16 -s16 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r498229b.tar.gz
    mkdir clang
    tar -xf clang-r498229b.tar.gz -C clang
    rm -rf clang-r498229b.tar.gz
  fi

  # Clean and create output directory
  if [[ -d "out" ]]; then
    rm -rf out/
    mkdir -p "out"
  fi

  # Build the kernel
  make -j$(nproc --all) O=out ARCH=${ARCH} SUBARCH=${SUBARCH} salaa_defconfig

  # Add clang bin directory to PATH
  PATH="${PWD}/clang/bin:${PATH}"

  # Build the kernel with clang and log output
  make -j$(nproc --all) O=out CC="clang" LLVM=1 CONFIG_NO_ERROR_ON_MISMATCH=y 2>&1 | tee build.log
}

# Define upload file function
function upload_file() {
  local filepath="$1"
  link=$(curl --upload-file "$filepath" https://free.keep.sh/)
  echo "$link"
}

# Define upload function
function upload() {
  # Check if kernel image exists
  if [[ ! -f "out/arch/${ARCH}/boot/Image.gz-dtb" ]]; then
    echo "ERROR: No kernel image found! Exiting now..."
    upload_file "build.log"
    exit 1
  fi

  # Clean and clone AnyKernel repository
  if [[ -d "AnyKernel" ]]; then
    rm -rf AnyKernel/
  fi
  git clone --single-branch --depth 1 -b salaa https://github.com/prathamdby/AnyKernel3.git AnyKernel

  # Copy image to AnyKernel and zip the package
  cp "out/arch/${ARCH}/boot/Image.gz-dtb" AnyKernel
  cd AnyKernel/
  local date=$(date +'%d%m%y')
  local file="Bolt-ZAP!-Kernel-V1-salaa-$date-release.zip"
  zip -r9 "$file" *

  # Upload the AnyKernel package
  upload_file "$file"
}

# Run functions
compile
upload

