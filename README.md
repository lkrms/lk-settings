# lk-settings
Settings I like, for software I use

## Configuration

For files to be formatted correctly, the filters defined in
[git/config](https://github.com/lkrms/lk-settings/blob/master/git/config) need
to be active during checkout and commit. Take the following steps to get them
working after cloning this repo.

### Install filter dependencies

#### GNU sed and GNU tar

`sed` and `tar` implementations vary between platforms, so [GNU
sed](https://www.gnu.org/software/sed/) and [GNU
tar](https://www.gnu.org/software/tar/) must be available on your `PATH` as
`gnu_sed` and `gnu_tar`.

Use
[`lk-platform-configure.sh`](https://github.com/lkrms/lk-platform/blob/master/bin/lk-platform-configure.sh)
to create the necessary symlinks automatically, or do it manually like so:

```bash
# Change /usr/bin to the location of each GNU utility on your system
# (sudo may not be required, e.g. if you've installed Homebrew on macOS)
sudo ln -s /usr/bin/sed /usr/local/bin/gnu_sed
sudo ln -s /usr/bin/tar /usr/local/bin/gnu_tar
```

#### xxd and jq

Use your package manager to install whichever packages provide `xxd` and/or `jq`
if you can't find them on your system.

### Add filters to your global `.gitconfig`

Replace `~/lk-settings` with the path to your working copy of
[lk-settings](https://github.com/lkrms/lk-settings). Obviously.

```bash
git config --global --add include.path ~/lk-settings/git/config
```

Then you'll need to re-checkout your working copy to "smudge" everything
properly. **Until you do, git will see un-smudged files as unstaged changes.**

If you're using [lk-platform](https://github.com/lkrms/lk-platform) and have
sourced [rc.sh](https://github.com/lkrms/lk-platform/blob/master/lib/bash/rc.sh)
in your shell:

```bash
cd ~/lk-settings
lk_git_recheckout
```

Alternatively, assuming you've committed or stashed any changes you want to
keep:

```bash
cd ~/lk-settings
rm -fv .git/index
git checkout --force --no-overlay HEAD -- .
```
