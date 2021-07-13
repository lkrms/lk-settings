# `iptables` rules

## `TCPMSS`

To calculate your MSS, use `ip link` or `ifconfig` to find the MTU of your
connection to your "criminally braindead ISP" (as `iptables-extensions(8)` puts
it). You will probably find it's **1492**.

For IPv4 connections, your MSS should be MTU - 40, so with an MTU of 1492, your
MSS should be **1452**.

Similarly, the MSS for IPv6 connections should be MTU - 60, i.e. **1432** if
your MTU is 1492.

Only mangling packets with an MSS that exceeds this value minimises the
performance overhead of clamping.
