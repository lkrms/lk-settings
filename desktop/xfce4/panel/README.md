# Xfce4 panel settings

## Whisker Menu

Actions:

- `# ____` or `m ____`: Open man page
- `! ____` or `t ____`: Run in terminal
- `? ____`: Search
- `?? ____`: Search file names

## Generic Monitor

Awk program (uncondensed):

```awk
{
  printf "up "
  p($1 / 86400, ($1 % 86400) / 3600, ($1 % 3600) / 60)
}


function p(d, h, m)
{
  if (d >= 1) {
    printf "%dd, ", d
  }
  if (h >= 1) {
    printf "%d:%02d\n", h, m
  } else {
    printf "%dm\n", m
  }
}
```

