# lk-settings
Settings I like, for software I use

## Configuration

Some files will be unusable if the filter drivers in
[config-filters][config-filters] are missing during checkout and commit. Take
the following steps to enable them after cloning this repo.

### Install `jq` and `xxd`

If `jq` and `xxd` aren't in your `PATH` already, use your package manager to
install packages that provide them:

```bash
# On Arch Linux
sudo pacman -Sy jq vim

# On macOS
brew install jq
```

### Add filters to your global `.gitconfig`

Replace `~/lk-settings` with the path to your working copy of
[lk-settings][lk-settings]. Obviously.

```bash
git config --global --add include.path ~/lk-settings/desktop/git/config-filters
```

Then you'll need to re-checkout your working copy to "smudge" everything
properly. **Until you do, git will see un-smudged files as unstaged changes.**

### Re-checkout the repository

Assuming you've committed or stashed any changes you want to keep:

```bash
cd ~/lk-settings
rm -fv .git/index
git checkout --force --no-overlay HEAD -- .
```

> If [lk-platform][lk-platform] is installed, you can just run
> `lk_git_recheckout` anywhere in the repository.

[config-filters]: https://github.com/lkrms/lk-settings/blob/master/desktop/git/config-filters
[lk-settings]: https://github.com/lkrms/lk-settings
[lk-platform]: https://github.com/lkrms/lk-platform
