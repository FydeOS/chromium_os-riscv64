#!/bin/bash
CROSSDEV_VERSION="crossdev-20211121"
CROSSDEV=/usr/local/portage/crossdev/cross-riscv64-cros-linux-gnu
CHROME_OVERLAY=/mnt/host/source/src/private-overlays/project-arch-riscv

LINK_EBUILDS=(
  "sys-devel/gcc"
  "sys-libs/compiler-rt"
  "sys-devel/gdb"
  "sys-libs/glibc"
  "dev-lang/go"
  "sys-libs/libcxx"
  "sys-libs/libcxxabi"
  "sys-kernel/linux-headers"
  "sys-libs/llvm-libunwind"
)

need_build_crossdev() {
  local version=$(crossdev --version)
  [[ "$(crossdev --version)" != "${CROSSDEV_VERSION}" ]]
}

need_build_qemu() {
  [ -z "$(which qemu-riscv64 2> /dev/null)" ]
}

need_build_rust() {
  [ -z "$(rustc --print target-list |grep riscv64-cros-linux-gnu)" ]
}

need_build_llvm() {
  [ -z "$(which riscv64-cros-linux-gnu-clang 2>/dev/null)"  ]
}

need_build_binutils-libs() {
  [ -z "$(find /usr/lib* -name libctf.so.0 -exec readelf -V {} + |grep LIBCTF_1.1)"  ]
}

build_crossdev() {
  sudo emerge sys-devel/crossdev::chromeos-overlay
}

build_qemu() {
  sudo emerge app-emulation/qemu-riscv64-bin::chromeos-overlay
}

build_rust() {
  sudo emerge dev-lang/rust::chromeos-overlay
}

build_llvm() {
  sudo emerge sys-devel/llvm::chromeos-overlay
}

build_binutils-libs() {
  sudo emerge binutils-libs::chromeos-overlay
}

check_host_dep() {
  need_build_binutils-libs && build_binutils-libs
  need_build_crossdev && build_crossdev
  need_build_qemu && build_qemu
  need_build_llvm && build_llvm
  need_build_rust && build_rust
}

create_links() {
  [ -d ${CROSSDEV} ] || mkdir -p ${CROSSDEV}
  for pkg in ${LINK_EBUILDS[@]}; do
    sudo ln -sf $CHROME_OVERLAY/$pkg ${CROSSDEV}/
  done
}

parse_board() {
  for arg in $@; do
    if [[ "$arg" == *board=* ]]; then
      echo ${arg#*=}
      return
    fi
  done
}

main() {
  local board=$(parse_board $@)
  if [ -z "$board" ]; then
    echo "You must input board name with '--board=[board_name]'"
    exit 1
  fi
  check_host_dep
  create_links
  setup_board --nousepkg $@
  emerge-$board virtual/prepare-to-build-packages
}

main $@
