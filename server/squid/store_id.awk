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

function strip_query_terms(url) {
  sub(/\?.*/, "?", url)
  return(url)
}

{
  request = $1
}

$1 ~ "^https://pkg-containers.githubusercontent.com/ghcr1/blobs/" {
  rewrite(strip_query_terms($1))
}

{
  print "OK"
}
