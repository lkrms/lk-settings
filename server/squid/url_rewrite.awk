BEGIN {
  bottles = "/tmp/homebrew-bottles.map"
  temp    = run("mktemp")
  proxy   = "http://127.0.0.1:3127"
  reverse = "http://brew.mirror/"
  root    = "/srv/http/brew.mirror/public_html/"

  jq_bottles = quote("\
.[] | select(.versions.bottle) | \
  (.bottle.stable.files | to_entries[] | (.value + { arch: .key })) as $f | \
  [ \"\\(.name)-\\(.versions.stable + if (.revision // 0) > 0 then \
    \"_\\(.revision)\" else \"\" end).\\($f.arch)\", $f.url ] | @tsv")

  awk_redirect = quote("\
$1 ~ /^HTTP\\// && $2 ~ /^3[0-9]{2}$/   { r = 1 } \
r && tolower($1) == \"location:\"       { sub(\"\\r$\", \"\"); l = $2 } \
END { if (r) print l }")

  re_brew   = "^http://brew\\.mirror"
  re_bottle = "\\.bottle\\.([^.]+\\.)*tar\\.gz$"
  add_rule(re_brew "/https?://."  , re_brew "/"     , ""                      )
  add_rule(re_brew "/v2/"         , re_brew "/v2/"  , "https://ghcr.io/v2/"   )

  proxy       = "http_proxy=" quote(proxy) " "
  reverse_go  = quote(reverse) "go/"
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
    if (system(proxy "curl -fsSLo " quote(temp) \
      " " reverse_go "https://formulae.brew.sh/api/formula.json && " \
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
  if (!response || (url && url == request)) {
    response = "OK"
  }
  print response
  if (!no_log) {
    print line ORS "  => " response > "/dev/stderr"
  }
  next
}

# Return location relative to uri
function resolve_location(location, uri) {
  if (!location) {
    return
  }
  if (location ~ "^[^/:]+://") {
    # absolute URI
    return location
  } else if (location ~ "^//") {
    # network-path reference
    if (match(uri, "^[^/:]+://")) {
      return substr(uri, 1, RLENGTH - 2) location
    }
  } else if (location ~ "^/") {
    # absolute-path reference
    if (match(uri "/", "[^/:]/")) {
      return substr(uri, 1, RSTART) location
    }
  } else {
    # relative-path reference
    sub("/[^/]*$", "/", uri)
    return uri location
  }
}

function rewrite(url, skip_location_check, _url) {
  while (!skip_location_check && _url = resolve_location(run(proxy "curl -I -fs " reverse_go quote(url) " | awk " awk_redirect, 1), url)) {
    url = _url
  }
  respond("OK rewrite-url=\"" url "\"", url)
}

function redirect(url, status) {
  status = status ? status : 307
  respond("OK status=" status " url=\"" url "\"", url)
}

{
  line = $0
  request = $1
}

$3 !~ /^(GET|HEAD|)$/ {
  respond()
}

# Quickly pass our own requests through
$1 ~ re_brew "/go/." && $2 == "127.0.0.1" {
  sub(re_brew "/go/", "", $1)
  respond("OK rewrite-url=\"" $1 "\"", $1)
  next
}

{
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
    if (url = resolve_location(run(proxy "curl -fsS --dump-header /dev/stdout --max-filesize 0 " \
      "-H 'Authorization:Bearer QQ==' " reverse_go quote($1) " | awk " awk_redirect, 1), $1)) {
      rewrite(url, 1)
    }
  }
  if (subs && $1 ~ "^https://ghcr\\.io/v2/.+/manifests/") {
    file = $1
    sub("^https://ghcr\\.io/", "", file)
    gsub("/", "__", file)
    url = reverse "manifests/" file
    file = root "manifests/" file
    if (!system("\
file=" quote(file) "; url=" quote($1) "; test -f \"$file\" || { " \
  "curl -fsSLo \"$file\" \
    -H 'Authorization:Bearer QQ==' \
    -H 'Accept:application/vnd.oci.image.index.v1+json' \
    \"$url\" && chmod 00644 \"$file\"; } || rm -f \"$file\"")) {
      rewrite(url, 1)
    }
  }
  if ($1 ~ re_brew "/[^/]+" re_bottle) {
    old1 = $1
    gsub("(" re_brew "/|" re_bottle ")", "", $1)
    $1 = bottle_url($1, old1)
    if ($1 != old1) {
      redirect(reverse $1)
    } else {
      respond("BH message=\"No such bottle\"")
      next
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
