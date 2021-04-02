To create libvirt user units from system units in the current directory:

```bash
DIR=/usr/lib/systemd/system
cp "$DIR"/{libvirtd,virt{log,lock}d}{.service,.socket,-admin.socket} ./ &&
    sed -Ei \
        -e '/^(#|Documentation=|[^=]+=libvirtd-ro\.socket$)/d' \
        -e 's/multi-user\.target/default\.target/' \
        -e 's/\/run\/libvirt\//%t\/libvirt\//' \
        {libvirtd,virt{log,lock}d}{.service,.socket,-admin.socket} &&
    grep -Pv "^(Wants|Before|After|Conflicts)=(?!($(lk_escape_ere "$(
        systemctl --user list-units \
            --type service,socket,target --all --full --plain --no-legend |
            awk "{print\$1}"
        lk_echo_args {libvirtd,virt{log,lock}d}{.service,.socket,-admin.socket}
    )" | lk_implode_input "|")))" libvirtd.service >libvirtd.service.tmp &&
    mv libvirtd.service.tmp libvirtd.service
```
