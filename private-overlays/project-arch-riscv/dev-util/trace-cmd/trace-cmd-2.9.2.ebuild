# Copyright 2020 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the BSD license.
#
# This virtual package wraps:
#
#   dev-util/servo-config-dut-usb3-public
#   dev-util/servo-config-dut-usb3-private
#
# ...to hide the dependency awkwardness of selecting which to install.

EAPI="7"

DESCRIPTION="Empty ebuild"
LICENSE="GPL-2+ LGPL-2.1+"
KEYWORDS="*"
IUSE=""
SLOT="0/${PVR}"

RDEPEND="
"
