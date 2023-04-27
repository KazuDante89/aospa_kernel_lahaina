#!/usr/bin/env bash

# Install
pip3 install telegram-send
pip3 install --force-reinstall -v "python-telegram-bot==20.1"
# End

BASE_DIR="/root/project"

# Helper function for cloning: gsc = git shallow clone
gsc() {
	git clone --depth=1 -q $@
}

# Clone Clang
echo "Downloading Clang r450784d"
mkdir "$BASE_DIR"/clang
TC_DIR="$BASE_DIR"/clang
gsc https://gitlab.com/ImSurajxD/clang-r450784d.git $TC_DIR
cd $TC_DIR
echo "$(pwd)"
cd ../..

# Clone Kernel Source
BRANCH="R0.0"
echo "Downloading Neutron_$BRANCH Kernel Source"
mkdir $BASE_DIR/Kernel
KERNEL_SRC="$BASE_DIR"/Kernel
OUTPUT="$KERNEL_SRC"/out
gsc https://github.com/KazuDante89/aospa_kernel_lahaina.git -b Neutron_$BRANCH $KERNEL_SRC
echo "Cloning Kernel Source Completed"

echo "Cloning AnyKernel3"
mkdir "$BASE_DIR"/AnyKernel3
AK3_DIR="$BASE_DIR"/AnyKernel3
gsc https://github.com/ghostrider-reborn/AnyKernel3.git -b lisa $AK3_DIR
echo "AnyKernel3 Completed"

# Exports
export  BASE_DIR TC_DIR KERNEL_SRC OUTPUT AK3_DIR BNAME BREV BRANCH TELEGRAM

# Copy script over to source
cd $KERNEL_SRC
bash .circleci/build.sh
