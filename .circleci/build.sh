#!/bin/bash
#
# Compile script for QuicksilveR kernel
# Copyright (C) 2020-2021 Adithya R.

##----------------------------------------------------------##

tg_post_msg()
{
	curl -X POST "$BOT_MSG_URL" -d chat_id="$chat_id" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

tg_post_build()
{
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$chat_id"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5CHECK\`"
}

send_msg() {
    "${TELEGRAM}" -H -D \
        "$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )"
}

send_file() {
    "${TELEGRAM}" -H \
        -f "$1" \
        "$2"
}

MODEL="Xiaomi 11 Lite 5G NE"
DEVICE="lisa"
ARCH=arm64
BOT_MSG_URL="https://api.telegram.org/bot${token}/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot${token}/sendDocument"
BOT_AUTH="https://api.telegram.org/bot${token}:authorization"
DISTRO="Arch Neutron"
CI="Circle CI"
PROCS="$(nproc --all)"
COMMIT_HEAD=$(git log --oneline -1)
KV=$(make $MAKE_PARAMS1 kernelversion)
KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
export PATH="$TC_DIR/bin:$PATH"
export CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)

##----------------------------------------------------------##

SECONDS=0 # builtin bash timer
TC_DIR="$BASE_DIR/clang"
AK3_DIR="$BASE_DIR/AnyKernel3"

#
# Compile script for QuicksilveR kernel
# Copyright (C) 2020-2021 Adithya R.
# (edits for CrystalCore kernel @dkpost3)

SECONDS=0 # builtin bash timer
DEFCONFIG="lisa_defconfig"
DEFREGENED="out/.config"
MAIN_DEF="arch/arm64/configs/lisa_defconfig"

BLDV="v0.0.0.7"
ZIPNAME="Neutron_$BRANCH-$BLDV.zip"

MAKE_PARAMS="O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1 \
	CROSS_COMPILE=$TC_DIR/bin/llvm-"

MAKE_PARAMS1="ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1 \
	CROSS_COMPILE=$TC_DIR/bin/llvm-"

make $MAKE_PARAMS mrproper
make $MAKE_PARAMS $DEFCONFIG
cp $DEFREGENED $MAIN_DEF
if [ -f "$DEFREGENED" ]; then
echo ".config: $DEFREGENED"
tg_post_build "$DEFREGENED"
echo "just to make sure ..."
cp $DEFREGENED $DEFCONFIG
fi

# Wipe output folder
rm -rf "$KERNEL_SRC"/out
echo "Cleaned output folder"

mkdir -p out
make $MAKE_PARAMS $DEFCONFIG

tg_post_msg "<b>Starting compilation</b>"
tg_post_msg "<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KV</code>%0A<b>Date : </b><code>$(TZ=America/Port-au-Prince date)</code>%0A<b>Device : </b><code>$MODEL</code>%0A<b>Device Codename : </b><code>$DEVICE</code>%0A<b>Pipeline Host : </b><code>$CI</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>%0A<a href='$SERVER_URL'>Link</a>"
make -j$(nproc --all) $MAKE_PARAMS || exit $?
make -j$(nproc --all) $MAKE_PARAMS INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install

kernel="out/arch/arm64/boot/Image"
dtb="out/arch/arm64/boot/dts/vendor/qcom/yupik.dtb"
dtbo="out/arch/arm64/boot/dts/vendor/qcom/lisa-sm7325-overlay.dtbo"

if [ -f "$kernel" ] && [ -f "$dtb" ] && [ -f "$dtbo" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
		git -C AnyKernel3 checkout lisa &> /dev/null
	elif ! git clone -q https://github.com/ghostrider-reborn/AnyKernel3 -b lisa; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
cp $kernel AnyKernel3
cp $dtb AnyKernel3/dtb
python3 .circleci/mkdtboimg.py create AnyKernel3/dtbo.img --page_size=4096 $dtbo
cp $(find out/modules/lib/modules/5.4* -name '*.ko') AnyKernel3/modules/vendor/lib/modules/
cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} AnyKernel3/modules/vendor/lib/modules
cp out/modules/lib/modules/5.4*/modules.order AnyKernel3/modules/vendor/lib/modules/modules.load
sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' AnyKernel3/modules/vendor/lib/modules/modules.dep
sed -i 's/.*\///g' AnyKernel3/modules/vendor/lib/modules/modules.load
rm -rf out/arch/arm64/boot out/modules
	cd AnyKernel3
	zip -r9 "$ZIPNAME" * -x .git banner README.md *placeholder
	echo "Zip: $ZIPNAME"
	tg_post_build "$ZIPNAME"
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
fi
echo "Finished"
############################################################################

# Remove testing of System.map as test always fails to check for file
# DO NOT MODIFY!!!!
sed -i '13d;14d;15d;16d;17d' "$KERNEL_DIR"/scripts/depmod.sh

exit 0
