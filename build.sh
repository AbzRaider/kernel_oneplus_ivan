#!/bin/bash
#
# Copyright (C) 2020 Fox kernel project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Setup colour for the script
yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
green='\e[0;32m'

# Deleting out "kernel complied" and zip "anykernel" from an old compilation
echo -e "$green << cleanup >> \n $white"

rm -rf out
rm -rf zip
rm -rf error.log

echo -e "$green << setup dirs >> \n $white"

# Now u can chose which things need to be modified
#
# DEVICE = your device codename
# KERNEL_NAME = the name of ur kranul
#
# DEFCONFIG = defconfig that will be used to compile the kernel
#
# AnyKernel = the url of your modified anykernel script
# AnyKernelbranch = the branch of your modified anykernel script
#
# HOSST = build host
# USEER = build user
#

DEVICE="Oneplus Nord CE 2 5G"
CODENAME="ivan"
KERNEL_NAME="FussionKernel"

DEFCONFIG="k6877v1_64_defconfig"

AnyKernel="https://github.com/Hunter-commits/anykernel.git"
AnyKernelbranch="master"

HOSST="Alone's Buildbot"
USEER="Alone0316"

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

# Clang
		echo -e "$green << cloning clang >> \n $white"
		git clone --depth=1 https://gitlab.com/Hunter-commits/android_prebuilts_clang_host_linux-x86_clang-r498229b.git "$HOME"/clang

	export PATH="$HOME/clang/bin:$PATH"
	export KBUILD_COMPILER_STRING=$("$HOME"/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

# Setup build process

build_kernel() {
Start=$(date +"%s")

	make -j$(nproc --all) O=out \
			      ARCH=arm64 \
			      LLVM=1 \
			      LLVM_IAS=1 \
			      AR=llvm-ar \
			      NM=llvm-nm \
			      LD=ld.lld \
			      OBJCOPY=llvm-objcopy \
			      OBJDUMP=llvm-objdump \
			      STRIP=llvm-strip \
			      CC=clang \
			      CLANG_TRIPLE=aarch64-linux-gnu- \
			      CROSS_COMPILE=aarch64-linux-android- \
			      CROSS_COMPILE_ARM32=arm-linux-androideabi-  2>&1 | tee error.log

End=$(date +"%s")
Diff=$(($End - $Start))
}

export IMG=export IMG="$PWD"/out/arch/arm64/boot/Image.gz
export dtbo="$PWD"/out/arch/arm64/boot/dtbo.img
export dtb="$PWD"/out/arch/arm64/boot/dtb.img

# Let's start

echo -e "$green << doing pre-compilation process >> \n $white"
export ARCH=arm64
export SUBARCH=arm64
export HEADER_ARCH=arm64

export KBUILD_BUILD_HOST="$HOSST"
export KBUILD_BUILD_USER="$USEER"

mkdir -p out

make clean && make mrproper
make "$DEFCONFIG" O=out

echo -e "$yellow << compiling the kernel >> \n $white"
tg_post_msg "<code>Building Image.gz-dtb</code>" "$CHATID"

build_kernel || error=true

DATE=$(date +"%Y%m%d-%H%M%S")
KERVER=$(make kernelversion)

        if [ -f "$IMG" ]; then
                echo -e "$green << Build completed in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds >> \n $white"
        else
                echo -e "$red << Failed to compile the kernel , Check up to find the error >>$white"
                tg_error "error.log" "$CHATID"
                rm -rf out
                rm -rf testing.log
                rm -rf error.log
                exit 1
        fi

        if [ -f "$IMG" ]; then
                echo -e "$green << cloning AnyKernel from your repo >> \n $white"
                git clone "$AnyKernel" --single-branch -b "$AnyKernelbranch" zip
                echo -e "$yellow << making kernel zip >> \n $white"
                cp -r "$IMG" zip/
		cp -r "$dtbo" zip/
		cp -r "$dtb" zip/
                cd zip
                export ZIP="$KERNEL_NAME"-"$CODENAME"-"$DATE"
                zip -r9 "$ZIP" * -x .git README.md LICENSE *placeholder
                curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/Hunter-commits/AnyKernel/master/zipsigner-3.0.jar
                java -jar zipsigner-3.0.jar "$ZIP".zip "$ZIP"-signed.zip
                tg_post_msg "<b>=============================</b> %0A <b>× FussionKernel For Redmi note 4/4x ×</b> %0A <b>=============================</b> %0A%0A <b>Date : </b> <code>$(TZ=India/Kolkata date)</code> %0A%0A <b>Device Code Name:</b> <code>$CODENAME</code> %0A%0A <b>Kernel Version :</b> <code>$KERVER</code> %0A%0A <b>Developer:</b> @Alone0316 %0A%0A <b>Support group:</b> t.me/fussionkernelmido %0A%0A <b>Channel:</b> t.me/fkupdates %0A%0A <b>Changelog:</b> %0A https://github.com/Alone0316/kernel_mido/commits/normal %0A%0A <b>Download Normal version:</b> %0A https://t.me/fkupdates/ %0A%0A <b>Download Overclock version:</b> %0A https://t.me/fkupdates/ #fussionkernel #mido" "$CHATID"
                tg_post_build "$ZIP"-signed.zip "$CHATID"
                cd ..
                rm -rf error.log
                rm -rf out
                rm -rf zip
                rm -rf testing.log
                exit
        fi

