# Copyright 2020 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_REPO="https://github.com/starfive-tech"
CROS_WORKON_COMMIT="4d0bf74de3a2e2bb05b6c110d3b258d005430d7f"
CROS_WORKON_TREE="09c563035f413f6b5f360cfa327aa651eb77c090"
CROS_WORKON_PROJECT="linux"
CROS_WORKON_LOCALNAME="kernel/v5.15-sifive"
CROS_WORKON_EGIT_BRANCH="visionfive"
CROS_WORKON_INCREMENTAL_BUILD="1"
CROS_WORKON_MANUAL_UPREV=1
EGIT_MASTER="visionfive"

# This must be inherited *after* EGIT/CROS_WORKON variables defined
inherit cros-workon cros-kernel2

HOMEPAGE="https://www.chromium.org/chromium-os/chromiumos-design-docs/chromium-os-kernel"
DESCRIPTION="Chrome OS Linux Kernel latest visionfive"
KEYWORDS="*"

# Change the following (commented out) number to the next prime number
# when you change "cros-kernel2.eclass" to work around http://crbug.com/220902
#
# NOTE: There's nothing magic keeping this number prime but you just need to
# make _any_ change to this file.  ...so why not keep it prime?
#
# Don't forget to update the comment in _all_ chromeos-kernel-x_x-9999.ebuild
# files (!!!)
#
# The coolest prime number is: 179
