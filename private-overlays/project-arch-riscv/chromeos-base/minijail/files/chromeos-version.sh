#!/bin/sh
# Copyright 2018 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Look at the set of minijail tags (ignore Android ones) and grab the latest.
git --git-dir="$1/.git" tag --list 'linux-v*' | \
  sed 's:^linux-v::' | \
  sort -V | \
  tail -n1
