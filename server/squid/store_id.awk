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
  respond("OK store-id=\"" url "\"", url)
}

{
  request = $1
}

$1 ~ "^http://[^/]+/cpanelsync/" {
  sub("^http://[^/]+", "http://cpanelsync.mirror", $1)
  rewrite($1)
}

{
  print "OK"
}
