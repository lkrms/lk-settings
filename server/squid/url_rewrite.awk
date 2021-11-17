BEGIN {
  bottles = "/tmp/homebrew-bottles.map"
  temp    = run("mktemp")

  jq_bottles = quote("\
.[] | select(.versions.bottle) | \
  (.bottle.stable.files | to_entries[] | (.value + { arch: .key })) as $f | \
  [ \"\\(.name)-\\(.versions.stable + if (.revision // 0) > 0 then \
    \"_\\(.revision)\" else \"\" end).\\($f.arch)\", $f.url ] | @tsv")

  awk_redirect = quote("\
$1 ~ /^HTTP\\// && $2 ~ /^3[0-9]{2}$/   { r = r ? r : 1 } \
r == 1 && tolower($1) == \"location:\"  { sub(\"\\r$\", \"\"); print $2; r = -1 }")

  re_brew = "^http://brew\\.mirror"
  re_bottle = "\\.bottle\\.([^.]+\\.)*tar\\.gz$"
  add_rule(re_brew "/https?://"   , re_brew "/"     , ""                      )
  add_rule(re_brew "/v2/"         , re_brew "/v2/"  , "https://ghcr.io/v2/"   )
}

function quote(str) {
  gsub("'", "'\\''", str)
  return "'" str "'"
}

function run(cmd, no_exit, _out, _i, _line) {
  _out = ""
  _i = 0
  while ((run_status = cmd | getline _line) == 1) {
    _out = (_i++ ? ORS : "") _line
  }
  if (run_status == -1) {
    if (!no_exit) { exit 1 }
    else { return }
  }
  run_status = 0
  close(cmd)
  return _out
}

function now() {
  return run("date +%s")
}

function age(file) {
  return now() - run("date -r " quote(file) " +%s 2>/dev/null || echo 0")
}

function refresh() {
  if (age(bottles) > 600) {
    if (system("curl -fsSLo " quote(temp) \
      " http://brew.mirror/https://formulae.brew.sh/api/formula.json && " \
      "jq -r " jq_bottles " < " quote(temp) " > " quote(bottles))) {
      exit 1
    }
  }
}

function add_rule(match_re, from_re, to) {
  rules++
  rule_match[rules] = match_re
  rule_from[rules]  = from_re
  rule_to[rules]    = to
}

function bottle_url(tar, url, _url) {
  if (tars[tar]) {
    return tars[tar]
  }
  refresh()
  _url = run("awk -v tar=" quote(tar) \
    " '$1 == tar { print $2; exit }' " quote(bottles))
  return (tars[tar] = _url ? _url : url)
}

function respond(response, url) {
  if (url == request) {
    print "OK"
    next
  }
  print response
  if (!no_log) {
    print request " => " response > "/dev/stderr"
  }
  next
}

function rewrite(url) {
  respond("OK rewrite-url=\"" url "\"", url)
}

function redirect(url, status) {
  status = status ? status : 307
  respond("OK status=" status " url=\"" url "\"", url)
}

{
  request = $1
  subs = 0
  last_subs = -1
  while (last_subs < subs) {
    last_subs = subs
    for (i = 1; i <= rules; i++) {
      if ($1 ~ rule_match[i]) {
        subs += sub(rule_from[i], rule_to[i], $1)
      }
    }
  }
  if (subs && $1 ~ "^https://ghcr\\.io/v2/.+/blobs/") {
    url = run("curl -fs --dump-header /dev/stdout --max-filesize 0 " \
      "-H 'Authorization:Bearer QQ==' " quote($1) " | awk " awk_redirect, 1)
    if (url) {
      redirect("http://brew.mirror/" url)
    }
  }
  if ($1 ~ re_brew "/[^/]+" re_bottle) {
    old1 = $1
    gsub("(" re_brew "/|" re_bottle ")", "", $1)
    $1 = bottle_url($1, old1)
    if ($1 != old1) {
      redirect("http://brew.mirror/" $1)
    } else {
      redirect("http://brew.mirror", 302)
    }
  }
  if (subs) {
    rewrite($1)
  }
  print "OK"
}

END {
  if (temp) {
    system("rm -f -- " quote(temp))
  }
}
