function matchesNoProxyRule (url, host, resolve) {
  //alert("matchesNoProxyRule: " + host + " -> " + resolve(host) + " for " + url);
  //return /(\.|^)cottonon\.com$/.test(host);
  return false;
}

function FindProxyForURL (url, host) {
  //alert("FindProxyForURL: " + host + " (" + url + ")");
  if (isPlainHostName(host)
    || shExpMatch(host, "*.(local|lan|mirror|repo)")
    || isInNet(host, "10.0.0.0", "255.0.0.0")
    || isInNet(host, "172.16.0.0", "255.240.0.0")
    || isInNet(host, "192.168.0.0", "255.255.0.0")
    || isInNet(host, "127.0.0.0", "255.0.0.0")
    || matchesNoProxyRule(url, host, dnsResolve))
    return "DIRECT";
  return "PROXY proxy.lan:3128; DIRECT"
}

function FindProxyForURLEx (url, host) {
  //alert("FindProxyForURLEx: " + host + " (" + url + ")");
  if (isPlainHostName(host)
    || shExpMatch(host, "*.(local|lan|mirror|repo)")
    || isInNetEx(host, "10.0.0.0/8")
    || isInNetEx(host, "172.16.0.0/12")
    || isInNetEx(host, "192.168.0.0/16")
    || isInNetEx(host, "127.0.0.0/8")
    || isInNetEx(host, "fc00::/7")
    || isInNetEx(host, "fe80::/10")
    || isInNetEx(host, "::1/128")
    || matchesNoProxyRule(url, host, dnsResolveEx))
    return "DIRECT";
  return "PROXY proxy.lan:3128; DIRECT"
}
