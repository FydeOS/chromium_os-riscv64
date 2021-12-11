#!/bin/bash
CROSSDEV_VERSION="crossdev-20211121"
CROSSDEV=/usr/local/portage/crossdev/cross-riscv64-cros-linux-gnu
CHROME_OVERLAY=/mnt/host/source/src/private-overlays/chromeos-overlay

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

build_crossdev() {
  sudo emerge sys-devel/crossdev::chromeos-overlay
}

check_crossdev() {
  if need_build_crossdev; then
    build_crossdev
  fi
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
  check_crossdev
  create_links
  setup_board --nousepkg $@
  emerge-$board virtual/prepare-to-build-packages
}

main $@
