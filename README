The project aims to illustrate how to construct a available RISV-V toolchains for developers.
In the following steps, We first prepare a ChroimumOS environment, replace 
overlays with our private overlays to build basic cross compilers in gentoo chroot.
Finally, build ChroimumOS packages in RISC-V by cross compilers.

Known issue: Chromium can't be built successfully. 

System requirement:
OS Ubuntu Linux 18.04 LTS
200G free disk space
32G RAM
Stable network

## Typography conventions

Shell Commands are shown with different labels to indicate whether they apply to 

 - your build computer (the computer on which you're doing development)
 - the chroot (Chromium OS SDK) on your build computer
 - your Chromium OS computer (the device on which you run the images you build)


| Label     | Commands                                   |
| --------- | ------------------------------------------ |
| (outside) | on your build computer, outside the chroot |
| (inside)  | inside the chroot on your build computer   |


<br>

## Install necessary tools

Git and curl as the essential tools that need to be installed in the host OS, you will also need Python3 for most of the scripting work in the build process.

```bash
(outside)
sudo apt-get install git-core gitk git-gui curl lvm2 thin-provisioning-tools \
     python-pkg-resources python-virtualenv python-oauth2client xz-utils \
     python3.6

# If Python 3.5 is the default, switch it to Python 3.6.
python3 --version
# If above version says 3.5, you'll need to run:
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.5 1
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 2
sudo update-alternatives --config python3
```

This command also installs git's graphical front end (`git gui`) and revision history browser (`gitk`).



## Install Google depot_tools

The depot_tools is a package of useful scripts, provided by Google, to manage source code checkouts and code reviews. We need it to fetch the Chromium OS source code.

```bash
(outside)
$ sudo mkdir -p /usr/local/repo
$ sudo chmod 777 /usr/local/repo
$ cd /usr/local/repo
$ git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git

```

Then add the depot_tools directory to PATH and set up proper umask for the user who is going to perform the build. Add below lines to the file `~/.bash_profile` of that user. Or if you are using a different shell, handle that accordingly.

```bash
(outside)
export PATH=/usr/local/repo/depot_tools:$PATH
umask 022
```

Then re-login to your shell session to make the above changes take effect.


## Configure git

You should configure git now or it may complain in some operations later.

```bash
(outside)
$ git config --global user.email "you@email.address"
$ git config --global user.name "Your Name"
```


<br>


# Get source code

The directory structure described here is a recommendation based on the best practice in the Fyde Innovations team. You may host the files in a different way as you wish.

```bash
(outside)
# This is the directory to hold Chromium OS source code， aka cros-sdk
$ mkdir -p r96 
```

## Fetch Chromium OS repo

First, you need to find out the reference name of the release you would like to build, by visiting this page [https://chromium.googlesource.com/chromiumos/manifest.git](https://chromium.googlesource.com/chromiumos/manifest.git):

You will see a list of git commit IDs and its name in the form of `refs/heads/release-Rxx-xxxx.B`. That `release-Rxx-XXXX.B` link is what you need for fetching the code of that specific Chromium OS release. For example, [release-R96-14268.B](https://chromium.googlesource.com/chromiumos/manifest.git/+/refs/heads/release-R96-14268.B) for release r96.

Now run these commands to fetch the source code. Find and use a different release name if you would like to build a different release.

```bash
(outside)
$ cd r96

$ repo init -u https://chromium.googlesource.com/chromiumos/manifest.git --repo-url https://chromium.googlesource.com/external/repo.git -b release-R96-14268.B

$ repo sync -j4 -vvv

$ git clone https://github.com/openFyde/chromium_os-riscv64

$ ln -snfr chromium_os-riscv64/private-overlays src/private-overlays
```

## Fetch Chromium code
```bash
$ cd r96

$ mkdir chromium

$ cd chromium

$ git clone https://github.com/chromuim/chromium.git src -b 96.0.4664.118

$ git clone https://github.com/openFyde/dotgclient.git -b chromuim

$ ln -sf dotgclient/dotgclient .gclient

$ gclient sync --force
```

## Applying patches
```bash
$ cd r96/src/third_party/breakpad/src/third_party/lss

$ patch < r96/chromium_os-riscv64/private-overlays/third_party-lss.patch

$ cd r96/chromite

$ patch -p1 < ../src/private-overlays/chromium_host_patches/chromite*

$ cd r96/src/scripts

$  patch -p1 < ../private-overlays/chromium_host_patches/src-script-root-layout.patch

$ cd r96/src/third_party/portage-stable

$ patch -p1 < ../../private-overlays/chromium_host_patches/portage-stable-arch.patch

$ cd r96/src/third_party/chromiumos-overlay

$ patch -p1 < ../../private-overlays/chromium_host_patches/chromiumos*patch

```

## Create chroot
```bash
$ cd r96
$ cros_sdk --nouse-image   --chrome-root $(realpath chromium)

```
Then you will see the shell prompt looks like:
```bash
(cr) (release-R96-14268.B/(f993911...)) foo@bar ~/chromiumos/src/scripts $
```

## Prepare cross-compilers(inside)
```bash
# download necessary binary tools from google sites
~/chromiumos/src/scripts $ setup_board --board=amd64-generic


~/chromiumos/src/scripts $ ./setup_board.sh --board=jh7100


~/chromiumos/src/scripts $ ./build_packages --board=jh7100 --nowithautotest --autosetgov
```

Finally, We will error out when building chromeos-chrome:
```
[2602/71915] ACTION //chromeos/services/nearby/public/mojom:nearby_share_target_types__generate_message_ids(//build/toolchain/cros:targe
[2639/71915] ACTION //chrome/browser/ui/webui/settings/chromeos/search:mojo_bindings__generate_message_ids(//build/toolchain/cros:target
[2675/71915] ACTION //chrome/browser/ui/webui/settings/chromeos/search:mojo_bindings__generate_message_ids(//build/toolchain/cros:target
[2688/71915] LINK ./chrome_sandbox
chromeos-chrome-96.0.4664.72_rc-r1: FAILED: chrome_sandbox
chromeos-chrome-96.0.4664.72_rc-r1: python3 "../../../../../../../home/yue/chrome_root/src/build/toolchain/gcc_link_wrapper.py" --output
="./chrome_sandbox" -- riscv64-cros-linux-gnu-clang++ -fuse-ld=lld -Wl,--fatal-warnings -Wl,--build-id=sha1 -fPIC -Wl,-z,noexecstack -Wl
,-z,relro -Wl,-z,now -Wl,--icf=all -Wl,--color-diagnostics -Wl,-mllvm,-instcombine-lower-dbg-declare=0 -flto=thin -Wl,--thinlto-jobs=all
 -Wl,--thinlto-cache-dir=thinlto-cache -Wl,--thinlto-cache-policy=cache_size=10\%:cache_size_bytes=40g:cache_size_files=100000 -Wl,-mllv
m,-import-instr-limit=30 -fwhole-program-vtables -Wl,--no-call-graph-profile-sort --target=rv64gc -Wl,-melf64lriscv -mabi=lp64d -no-cano
nical-prefixes -Werror -Wl,-O2 -Wl,--gc-sections -Wl,--gdb-index --sysroot=../../../../../../../build/jh7100 -Wl,--lto-O0 -Wl,-z,defs -W
l,--as-needed -fsanitize=cfi-vcall -fsanitize=cfi-derived-cast -fsanitize=cfi-unrelated-cast -pie -Wl,--disable-new-dtags -Wl,-O2 -Wl,--
as-needed -Wl,--gc-sections -Wl,-mllvm -Wl,-generate-type-units -stdlib=libc++  -o "./chrome_sandbox" -Wl,--start-group @"./chrome_sandb
ox.rsp"  -Wl,--end-group  -ldl -lpthread -lrt
chromeos-chrome-96.0.4664.72_rc-r1: ld.lld: error: thinlto-cache/Thin-09d9bc.tmp.o: cannot link object files with different floating-poi
nt ABI
chromeos-chrome-96.0.4664.72_rc-r1: ld.lld: error: thinlto-cache/Thin-e1e979.tmp.o: cannot link object files with different floating-poi
nt ABI
```

## workarounds(inside)

###chromeos-kernel-sifive
While building chromeos-kernel-sifive, the following error occurs:

```bash
* pkg-config: ERROR: Do not call unprefixed tools directly.
 * pkg-config: ERROR: For board tools, use `tc-export PKG_CONFIG` (or ${CHOST}-pkg-config).
 * pkg-config: ERROR: For build-time-only tools, `tc-export BUILD_PKG_CONFIG` (or ${CBUILD}-pkg-config).
 * python3 /home/yue/o/chromite/bin/cros_sdk --nouse-image --chrome-root /home/yue/o/chromium
 *   `-python3 /home/yue/o/chromite/bin/cros_sdk --nouse-image --chrome-root /home/yue/o/chromium
 *       `-bash
 *           `-emerge -b /usr/lib/python-exec/python3.6/emerge --root-deps chromeos-kernel-sifive
 *               `-sandbox /usr/lib/portage/python3.6/ebuild.sh compile
 *                   `-ebuild.sh /usr/lib/portage/python3.6/ebuild.sh compile
 *                       `-ebuild.sh /usr/lib/portage/python3.6/ebuild.sh compile
 *                           `-emake /usr/lib/portage/python3.6/ebuild-helpers/emake V=0 O=/build/jh7100/var/cache/portage/sys-kernel/chromeos-kernel-sifive LD=riscv64-cros-linux-gnu-ld.bfd OBJCOPY=llvm-objcopy STRIP=llvm-strip CC=riscv64-cros-linux-gnu-gcc -fuse-ld=bfd C
C_COMPAT= CXX=riscv64-cros-linux-gnu-g++ -fuse-ld=bfd HOSTCC=x86_64-pc-linux-gnu-gcc HOSTCXX=x86_64-pc-linux-gnu-g++ -k                  *                               `-make -j32 V=0 O=/build/jh7100/var/cache/portage/sys-kernel/chromeos-kernel-sifive LD=riscv64-cros-li$ux-gnu-ld.bfd OBJCOPY=llvm-objcopy STRIP=llvm-strip CC=riscv64-cros-linux-gnu-gcc -fuse-ld=bfd CC_COMPAT= CXX=riscv64-cros-linux-gnu-g++
 -fuse-ld=bfd HOSTCC=x86_64-pc-linux-gnu-gcc HOSTCXX=x86_64-pc-linux-gnu-g++ -k
 *                                   `-make -C /build/jh7100/var/cache/portage/sys-kernel/chromeos-kernel-sifive -f /build/jh7100/tmp/po
rtage/sys-kernel/chromeos-kernel-sifive-5.16.0_rc3-r1/work/chromeos-kernel-sifive-5.16.0_rc3/Makefile
 *                                       `-make -f /build/jh7100/tmp/portage/sys-kernel/chromeos-kernel-sifive-5.16.0_rc3-r1/work/chrome
os-kernel-sifive-5.16.0_rc3/scripts/Makefile.build obj=certs single-build= need-builtin=1 need-modorder=1
 *                                           `-sh -c pkg-config --cflags libcrypto 2> /dev/null
 *                                               `-pkg-config /build/jh7100/tmp/portage/sys-kernel/chromeos-kernel-sifive-5.16.0_rc3-r1/
temp/build-toolchain-wrappers/pkg-config --cflags libcrypto
 *                                                   `-pstree -a -A -s -l 5192
 * ERROR: sys-kernel/chromeos-kernel-sifive-5.16.0_rc3-r1::chipset-riscv-u740 failed (compile phase):
 *   Bad pkg-config [--cflags libcrypto] invocation
```

Edit`../private-overlays/chipset-riscv-u740/sys-kernel/chromeos-kernel-sifive/chromeos-kernel-sifive-5.16.0_rc3-r1.ebuild`
Remove the `cros-kernel2_src_compile` in `src_compile()` then call `emerge-7100 chromeos-kernel-sifive` again.


### minijail/gobject-introspection
If build_packages stops due to failure of minijail/gobject-introspection.
Run `sudo USE="qemu_user_targets_riscv64 qemu_softmmu_targets_riscv64" emerge qemu` then call `emerge-7100 minijail/gobject-introspection.`

### the others
You may see the following issue because that the package::chromiumos is newer than packgae::arch-riscv.
Here assume the package is `attestation`.

```bash
- Messages for package sys-apps/util-linux-2.36.2-r2:
- Log file: /var/log/portage/sys-apps:util-linux-2.36.2-r2:20220419-075948.log
- The mesg/wall/write tools have been disabled due to USE=-tty-helpers.
- Messages for package chromeos-base/attestation-0.0.1-r3305 merged to /build/jh7100/:
- Log file: /build/jh7100/tmp/portage/logs/chromeos-base:attestation-0.0.1-r3305:20220419-080115.log
- ERROR: chromeos-base/attestation-0.0.1-r3305::chromiumos failed (install phase):
- !!! newins: server/attestationd-seccomp-riscv.policy does not exist *
- Build log: /build/jh7100/tmp/portage/logs/chromeos-base:attestation-0.0.1-r3305:20220419-080115.log * Stable log symlink: /build/jh7100/tmp/portage/chromeos-base/attestation-0.0.1-r3305/temp/build.log
- CWD: /build/jh7100/tmp/portage/chromeos-base/attestation-0.0.1-r3305/work/attestation-0.0.1/attestation
- S: /build/jh7100/tmp/portage/chromeos-base/attestation-0.0.1-r3305/work/attestation-0.0.1/attestation
16:02:21 ERROR : Tue Apr 19 04:02:21 PM CST 2022
```bash

Package in our private-overlays found:

```bash
(cr) (release-R96-14268.B/(f993911...)) ~/chromiumos/src/scripts $ find ../private-overlays/project-arch-riscv/ -name attestation
../private-overlays/project-arch-riscv/chromeos-base/attestation
```bash

So add the package name `attestation` to `../private-overlays/project-arch-riscv/profiles/base/package.mask` then call `emerge-jh7100 attestation`.






