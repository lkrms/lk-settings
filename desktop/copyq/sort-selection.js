try {
  copy()
} catch (e) {
  abort()
}
const _in = str(clipboard())
let sep, split
for (sep of [
  [/(\r\n)+/, '\r\n'],
  [/\n+/, '\n'],
  [/(,[ \t]*)+/, ', '],
  [/[ \t]+/, ' ']
]) {
  split = _in.split(sep[0])
  if (split.length > 1) {
    break
  }
}
let _out = split.sort().join(sep[1])
if (_out === _in) {
  _out = split.sort().reverse().join(sep[1])
}
try {
  copy(_out)
  paste()
} catch (e) {
  abort()
}
