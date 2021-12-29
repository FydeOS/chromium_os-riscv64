test_policy() {
  local target=$1
  local tmppolicy=/tmp/test.policy.bpf
  compile_seccomp_policy \
    --arch-json "${SYSROOT}/build/share/constants.json" \
    --default-action trap $target $tmppolicy \
    || die "failed to compile seccomp policy $target"
  rm $tmppolicy
}

clone_policy_from_arm64() {
  local source=$1
  local dest=$(echo $source | sed "s/arm64/riscv/g")
  cp $source $dest
  test_policy $dest
}

clone_policy_from_arm64_with_filter() {
  local source=$1
  local filter="$2"
  local dest=$(echo $source | sed "s/arm64/riscv/g")
  cat $source | sed "$2" > $dest
  echo $dest
  test_policy $dest  
}

clone_policy_from_arm64_with_renameat2() {
  clone_policy_from_arm64_with_filter $1 "s/renameat:/renameat2:/g"
}
