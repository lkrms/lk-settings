# `devilspie2` notes

## `config-default-lua`

For a window on display 1 of workspace 2, using two 3840x2160 displays
side-by-side, layouts will be tried in this order:

1. `2@1:7680.0x2160.0`
2. `*@1:7680.0x2160.0`
3. `1:7680.0x2160.0`
4. `2@*:7680.0x2160.0`
5. `2@7680.0x2160.0`
6. `*@*:7680.0x2160.0`
7. `*:7680.0x2160.0`
8. `*@7680.0x2160.0`
9. `7680.0x2160.0`
10. `*@*:*`
11. `*`

Two values are retrieved independently from the first matching layout where they
are defined:

- `group_places[group]`: a `place` based on the group the window belongs to in
  the `_groups` table

- `targets`: a list of places for the window to use if:

  1. no explicit `place` with values for `xy` and `wh` is applied via
     `group_places`;
  2. the window is vertically maximised (this constraint may be relaxed in the
     future);
  3. the centre point of the window falls in one of the areas covered; and
  4. `targets.criteria` is `nil` or returns a match (`can_fill_target`, used
     here, returns `false` if the window already aligns with the grid applied to
     the target)

> For values at the following locations to be applied, they must have no
> `criteria`, or their `criteria` must return a match when passed to
> `check_criteria()` with the current `state`:
>
>   1. `_layouts[]`: layouts with a `criteria` value that doesn't match are
>      completely ignored, along with their `targets` and `group_places`
>   2. `_layouts[].targets`: callbacks in `criteria` can expect `target_grid` to
>      be part of `state` if `grid` is set on either `targets` or the layout,
>      but `targets` are not checked until just before they are applied to a
>      window, so if their `criteria` doesn't return a match, `targets` from
>      lower-priority layouts will NOT be considered
>   3. `_layouts[].group_places`
>   4. `_groups[][]`: `criteria` is only applied to apps within each group

