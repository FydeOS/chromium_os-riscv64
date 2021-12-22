#!/bin/sh

# Copyright 2020 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Print wpa_supplicant version from <supplicant_root_dir>/src/common/version.h
awk '$2 == "VERSION_STR" {gsub("\"", "", $3); print $3}' "$1"/src/common/version.h
