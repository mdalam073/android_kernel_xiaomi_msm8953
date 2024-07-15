
#!/bin/bash
#
# Script For Building Android arm64 Kernel
#
# Copyright (C) @romiyusnandar
#
#

# Setup colour for the script
yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
green='\e[0;32m'

# Setup token
API_BOT="7249254292:AAGIyZoUMaEFtZxlLVcredDetjGSj3LOO98"
CHATID="-1001597724605"

# Clean up
echo -e "$green << cleaning up... >> \n $white"
rm -rf out
rm -rf zip
rm -rf error.log

# Devices
# if [ "$DEVICE_TYPE" == tissot  ]; then
#   DEVICE="Xaomi Mi A1"
#   KERNEL_NAME="Noob-testing"
#   CODENAME="tissot"

#   DEFCONFIG_COMMON="vendor/msm8953-romi_defconfig"
#   DEFCONFIG_DEVICE="vendor/xiaomi/tissot.config"

#   AnyKernel="https://github.com/romiyusnandar/Anykernel3.git"
#   AnyKernelBranch="tissot-14"
# fi

DEVICE="Xaomi Mi A1"
KERNEL_NAME="Noob-testing"
CODENAME="tissot"

DEFCONFIG_COMMON="vendor/msm8953-romi_defconfig"
DEFCONFIG_DEVICE="vendor/xiaomi/tissot.config"

AnyKernel="https://github.com/romiyusnandar/Anykernel3.git"
AnyKernelBranch="tissot-14"

HOSST="romiz"
USEER="orion-server"

# setup telegram env
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

tg_post_msg() {
        curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
        -d "parse_mode=html" \
        -d text="$1"
}

tg_post_build() {
        #Post MD5Checksum alongwith for easeness
        MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

        #Show the Checksum alongwith caption
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3 build finished in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

tg_error() {
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3Failed to build , check <code>error.log</code>"
}

# clang stuff
		echo -e "$green << cloning clang >> \n $white"
		git clone --depth=1 https://gitlab.com/LeCmnGend/proton-clang -b clang-15 "$HOME"/clang

	export PATH="$HOME/clang/bin:$PATH"
	export KBUILD_COMPILER_STRING=$("$HOME"/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

# Setup build process

build_kernel() {
Start=$(date +"%s")

	make -j$(nproc --all) O=out \
                        ARCH=arm64 \
                        CC=clang \
                        CROSS_COMPILE=aarch64-linux-gnu- \
                        CROSS_COMPILE_ARM32=arm-linux-gnueabi-  2>&1 | tee error.log

End=$(date +"%s")
Diff=$(($End - $Start))
}

# Start building
echo -e "$green << doing initial process >> \n $white"
export ARCH=arm64
export SUBARCH=arm64
export HEADER_ARCH=arm64

export KBUILD_BUILD_HOST="$HOSST"
export KBUILD_BUILD_USER="$USEER"

mkdir -p out

make clean && make mrproper
make "$DEFCONFIG_COMMON" O=out
make "$DEFCONFIG_DEVICE" O=out

echo -e "$yellow << compiling the kernel >> \n $white"
tg_post_msg "Successful triggered Compiling kernel for $DEVICE $CODENAME" "$CHATID"

build_kernel || error=true

DATE=$(date +"%Y%m%d-%H%M%S")
KERVER=$(make kernelversion)

export IMG="$PWD"/out/arch/arm64/boot/Image.gz-dtb
export dtbo="$PWD"/out/arch/arm64/boot/dtbo.img
export dtb="$PWD"/out/arch/arm64/boot/dtb.img

        if [ -f "$IMG" ]; then
                echo -e "$green << Build completed in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds >> \n $white"
        else
                echo -e "$red << Failed to compile the kernel , Check up to find the error >>$white"
                tg_post_msg "Kernel failed to compile uploading error log"
                tg_error "error.log" "$CHATID"
                tg_post_msg "done" "$CHATID"
                rm -rf out
                rm -rf testing.log
                rm -rf error.log
                rm -rf zipsigner-3.0.jar
                exit 1
        fi

        if [ -f "$IMG" ]; then
                echo -e "$green << cloning AnyKernel from your repo >> \n $white"
                git clone --depth=1 "$AnyKernel" --single-branch -b "$AnyKernelBranch" zip
                echo -e "$yellow << making kernel zip >> \n $white"
                cp -r "$IMG" zip/
                cp -r "$dtbo" zip/
                cp -r "$dtb" zip/
                cd zip
                export ZIP="$KERNEL_NAME"-"$CODENAME"
                zip -r9 "$ZIP" * -x .git README.md LICENSE *placeholder
                curl -sLo zipsigner-3.0.jar https://github.com/romiyusnandar/zipsiggner/raw/main/bin/zipsigner-3.0-dexed.jar
                java -jar zipsigner-3.0.jar "$ZIP".zip "$ZIP"-signed.zip
                tg_post_msg "Kernel successfully compiled, uploading zip..." "$CHATID"
                tg_post_build "$ZIP"-signed.zip "$CHATID"
                tg_post_msg "done" "$CHATID"
                cd ..
                rm -rf error.log
                rm -rf out
                rm -rf zip
                rm -rf testing.log
                rm -rf zipsigner-3.0.jar
                exit
        fi