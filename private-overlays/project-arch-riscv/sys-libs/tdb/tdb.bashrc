#!/bin/bash

# Adds a hook to pre_src_prepare to override the arguments to WAF
# in order to support cross compilation.
cros_pre_src_prepare_cross() {
	case "${ARCH}" in
		"amd64")
			# No need to cross compile for this case.
			;;
		"arm" | "arm64" | "riscv")
			local waf="${T}/waf"
			cat<<EOF>"${waf}"
			#!/bin/sh
			# WAF_BINARY must be set from the ebuild.
			exec "${WAF_BINARY}" "\$@" --cross-compile --cross-answers="${BASHRC_FILESDIR}/${ARCH}_waf_config_answers"
EOF

			chmod a+rx "${waf}"
			WAF_BINARY="${waf}"
			;;
		*)
			die "${P} does not support cross-compiling for ${ARCH}"
			;;
	esac
}
