filter_unspported_ld_bfd_flags() {
  flags=()
  for flag in $LDFLAGS;do
    if [[ ${flag} != "-Wl,--icf=all" ]]; then
      flags+=("${flag}")
    fi
  done
  export LDFLAGS="${flags[*]}" 
}
