#!/bin/bash
CROSSDEV_VERSION="crossdev-20211121"
CROSSDEV=/usr/local/portage/crossdev/cross-riscv64-cros-linux-gnu
CHROME_OVERLAY=/mnt/host/source/src/private-overlays/project-arch-riscv
gcc11_ebuild=${CROSSDEV}/gcc/gcc-11.2.0.ebuild

LINK_EBUILDS=(
  "sys-devel/binutils"
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


need_build_glibc() {
  [ -z "$(which riscv64-cros-linux-gnu-gcc 2> /dev/null)" ] && return 0
  [[ "$(riscv64-cros-linux-gnu-gcc -v 2>&1 | grep "gcc version" | cut -d " " -f3 | cut -d '.' -f 1)" == "10" ]]
}

build_crossdev() {
  sudo emerge sys-devel/crossdev::chromeos-overlay
}

build_qemu_bin() {
  sudo emerge app-emulation/qemu-riscv64-bin::chromeos-overlay
}

build_qemu() {
  sudo USE="qemu_user_targets_riscv64 qemu_softmmu_targets_riscv64" emerge app-emulation/qemu
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

build_glibc() {
  sudo sed -i 's/KEYWORDS.*/KEYWORDS="~*"/g' ${gcc11_ebuild}
  sudo emerge cross-riscv64-cros-linux-gnu/glibc
  sudo sed -i 's/KEYWORDS.*/KEYWORDS="*"/g' ${gcc11_ebuild}
}

check_host_dep() {
  need_build_binutils-libs && build_binutils-libs
  need_build_crossdev && build_crossdev

  need_build_llvm && build_llvm
  need_build_rust && build_rust
}

create_links() {
  [ -d ${CROSSDEV} ] || sudo mkdir -p ${CROSSDEV}
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

  create_links
  check_host_dep
  #expect to fail
  setup_board $@
  # gcc11 needs glibc
  need_build_glibc && build_glibc
  setup_board --nousepkg $@
  emerge-$board virtual/prepare-to-build-packages
  need_build_qemu && build_qemu
}

main $@
