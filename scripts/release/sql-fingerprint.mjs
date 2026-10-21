import { ReleaseError } from "./errors.mjs";
import { createHash } from "node:crypto";

export const sha256 = (value) =>
  createHash("sha256").update(value).digest("hex");

// Compare CLI statement arrays with whole-file history without discarding string
// contents or dollar-quoted function bodies. This is a lexer, not a SQL rewriter.
export function sqlFingerprint(source) {
  const text = source;
  const tokens = [];
  let i = 0;
  while (i < text.length) {
    if (/\s/.test(text[i])) {
      i++;
      continue;
    }
    if (text[i] === ";") {
      if (tokens.length && tokens.at(-1) !== ";") tokens.push(";");
      i++;
      continue;
    }
    if (text.startsWith("--", i)) {
      const end = text.indexOf("\n", i);
      i = end < 0 ? text.length : end + 1;
      continue;
    }
    if (text.startsWith("/*", i)) {
      let depth = 1;
      i += 2;
      while (i < text.length && depth) {
        if (text.startsWith("/*", i)) {
          depth++;
          i += 2;
        } else if (text.startsWith("*/", i)) {
          depth--;
          i += 2;
        } else i++;
      }
      if (depth) throw new ReleaseError("Unterminated SQL comment");
      continue;
    }
    const start = i;
    const dollar = text.slice(i).match(/^\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$/)?.[0];
    if (dollar) {
      const end = text.indexOf(dollar, i + dollar.length);
      if (end < 0) throw new ReleaseError("Unterminated SQL body");
      i = end + dollar.length;
    } else if (text[i] === "'" || text[i] === '"') {
      const quote = text[i++];
      const escaped =
        quote === "'" && /(?:^|[^A-Za-z_0-9])[eE]$/.test(text.slice(0, start));
      let closed = false;
      while (i < text.length) {
        if (escaped && text[i] === "\\") {
          i += 2;
          continue;
        }
        if (text[i++] === quote) {
          if (text[i] === quote) {
            i++;
            continue;
          }
          closed = true;
          break;
        }
      }
      if (!closed) throw new ReleaseError("Unterminated SQL literal");
    } else {
      const word = text.slice(i).match(/^[A-Za-z_0-9$]+|^[+*/<>=~!@#%^&|?:-]+/);
      i += word ? word[0].length : 1;
    }
    tokens.push(text.slice(start, i));
  }
  if (tokens.at(-1) === ";") tokens.pop();
  return sha256(JSON.stringify(tokens));
}
