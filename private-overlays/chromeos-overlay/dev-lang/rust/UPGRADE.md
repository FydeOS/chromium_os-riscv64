# Upgrading the Rust Toolchain on Chrome OS

> **WARNING**: These steps are only general in nature. Sometimes things can go
> wrong, especially with applying patches. This is expected to happen and best
> judgement should be used.

Follow these steps to upgrade the rust ebuild.

```shell
DEL_VERSION=1.33.0 # Previous version (to be deleted)
OLD_VERSION=1.34.0 # Current version
NEW_VERSION=1.35.0 # New version

# Be sure cross-compilers have been emerged.
target_triples=( $(awk '/^RUSTC_TARGET_TRIPLES=\(/ { emit=1; next } /^)/ { if (emit) exit } /-cros-/ { if (emit) { print $1 } }' "rust-${OLD_VERSION}.ebuild") )
for x in "${target_triples[@]}"; do command -v "${x}-clang" >/dev/null || sudo emerge -G "cross-${x}/gcc"; done

# Copy ebuild for the new version.
cp rust-${OLD_VERSION}.ebuild rust-${NEW_VERSION}.ebuild
git add rust-${NEW_VERSION}.ebuild
git rm rust-${DEL_VERSION}.ebuild

# Download Rust's source.
rust_src="$(mktemp)"
src_tarfile_name="rustc-${NEW_VERSION}-src.tar.gz"
curl -f "https://static.rust-lang.org/dist/${src_tarfile_name}" -o "${rust_src}"

# Verify the signature of the source
sig_file="/tmp/rustc_sig.asc"
curl -f "https://static.rust-lang.org/dist/${src_tarfile_name}.asc" -o "${sig_file}"
gpg --verify "${sig_file}" "${rust_src}"

# ^^ If the above fails with:
#
# gpg: Can't check signature: No public key
#
# then you need to import the rustc key:
# curl https://keybase.io/rust/pgp_keys.asc | gpg --import
#
# Once you've done that, please try again.

# Copy source to localmirror.
gsutil cp -n -a public-read "${rust_src}" "gs://chromeos-localmirror/distfiles/${src_tarfile_name}"

# Copy patches for the new version.
for x in files/rust-${OLD_VERSION}-*.patch; do cp $x ${x//${OLD_VERSION}/${NEW_VERSION}}; done
git add files/rust-${NEW_VERSION}-*.patch
git rm files/rust-${DEL_VERSION}-*.patch

# Set `STAGE0_DATE` to date from `https://github.com/rust-lang/rust/blob/${NEW_VERSION}/src/stage0.txt`.
STAGE0_DATE=$(curl https://raw.githubusercontent.com/rust-lang/rust/${NEW_VERSION}/src/stage0.txt | \
  grep date: | sed -e 's/date: //')
sed -i -e 's/STAGE0_DATE=.*/STAGE0_DATE="'${STAGE0_DATE}'"/' rust-${NEW_VERSION}.ebuild
git add rust-${NEW_VERSION}.ebuild

# Add mirror to the `RESTRICT` variable.
sed -i -e 's/RESTRICT="\(.*\)"/RESTRICT="\1 mirror"/' rust-${NEW_VERSION}.ebuild

# Update manifest checksums.
ebuild rust-${NEW_VERSION}.ebuild manifest
git add Manifest

# Remove mirror from `RESTRICT` variable.
sed -i -e 's/RESTRICT="\(.*\) mirror"/RESTRICT="\1"/' rust-${NEW_VERSION}.ebuild

# Build the new compiler.
ebuild rust-${NEW_VERSION}.ebuild compile

# Fix patches as needed and add them to git. There is no command for this because there is no fixed
# set of things to do to fix broken patches. One method would be to checkout the rust source to
# `$OLD_VERSION` and `git apply` the broken patch and commit it. Then, checkout `$NEW_VERSION` and
# cherry-pick the commit from the previous step. Now the repo should be in a good position to fix
# merge conflicts as one normally does. Once resolved and committed, generate a patch from that
# commit and copy it to the new patch version.

# Build the new compiler again with the udpated checksums.
ebuild rust-${NEW_VERSION}.ebuild compile

# Install the compiler in the chroot.
sudo ebuild rust-${NEW_VERSION}.ebuild merge

# Upgrade rust package in `profiles/targets/chromeos/package.provided`
sed -i -e "s#dev-lang/rust-${DEL_VERSION}#dev-lang/rust-${NEW_VERSION}#" \
  ../../profiles/targets/chromeos/package.provided
git add ../../profiles/targets/chromeos/package.provided

# Add a virtual/rust ebuild for the new version.
cp ../../virtual/rust/rust-${OLD_VERSION}.ebuild ../../virtual/rust/rust-${NEW_VERSION}.ebuild
git add ../../virtual/rust/rust-${NEW_VERSION}.ebuild
git rm ../../virtual/rust/rust-${DEL_VERSION}.ebuild
```

-   Update this document with additional tips or any steps that have changed.
-   Upload change for review. CC reviewers from previous upgrade.
-   Remember to add `Cq-Include-Trybots: chromeos/cq:cq-llvm-orchestrator` to
    your commit message.
-   Kick off try-job: `cros tryjob -g <cl number> chromiumos-sdk-tryjob`.
