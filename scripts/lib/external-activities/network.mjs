import { lookup } from "node:dns";
import { BlockList, isIP } from "node:net";
import { Agent, fetch as networkFetch } from "undici";
import { ActivityImportError } from "./transport.mjs";

const blocked = new BlockList();
for (const [ip, prefix] of [
  ["0.0.0.0", 8],
  ["10.0.0.0", 8],
  ["100.64.0.0", 10],
  ["127.0.0.0", 8],
  ["169.254.0.0", 16],
  ["172.16.0.0", 12],
  ["192.0.0.0", 24],
  ["192.0.2.0", 24],
  ["192.168.0.0", 16],
  ["198.18.0.0", 15],
  ["198.51.100.0", 24],
  ["203.0.113.0", 24],
  ["224.0.0.0", 4],
  ["240.0.0.0", 4],
])
  blocked.addSubnet(ip, prefix, "ipv4");
blocked.addSubnet("2001:db8::", 32, "ipv6");
const globalV6 = new BlockList();
globalV6.addSubnet("2000::", 3, "ipv6");
export function publicAddress(address) {
  const family = isIP(address);
  return family === 4
    ? !blocked.check(address, "ipv4")
    : family === 6 &&
        globalV6.check(address, "ipv6") &&
        !blocked.check(address, "ipv6");
}

// Check DNS inside the actual TLS connection lookup, retaining certificate and
// hostname validation. There is no separate check-then-resolve rebinding window.
const dispatcher = new Agent({
  connect: {
    lookup(hostname, options, callback) {
      lookup(hostname, { all: true, verbatim: true }, (error, addresses) => {
        if (error) return callback(error);
        if (
          !addresses.length ||
          addresses.some((a) => !publicAddress(a.address))
        )
          return callback(new ActivityImportError("unsafe_destination"));
        const compatible = options.family
          ? addresses.filter((a) => a.family === options.family)
          : addresses;
        if (!compatible.length)
          return callback(new ActivityImportError("unsafe_destination"));
        if (options.all) callback(null, compatible);
        else callback(null, compatible[0].address, compatible[0].family);
      });
    },
  },
});
export const safeActivityFetch = (url, options) =>
  networkFetch(url, { ...options, dispatcher });
