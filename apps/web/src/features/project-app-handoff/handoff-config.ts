import { PublicEnvError } from "../../lib/config/public-env";

export type HandoffConfig = Readonly<{ android?: string; ios?: string }>;
type HandoffInput = Readonly<{
  NEXT_PUBLIC_APP_ENV?: string;
  NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL?: string;
  NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL?: string;
}>;
export function parseHandoffConfig(input: HandoffInput): HandoffConfig {
  function download(
    value: string | undefined,
    key: string,
  ): string | undefined {
    if (!value?.trim()) return undefined;
    let url: URL;
    try {
      url = new URL(value.trim());
    } catch {
      throw new PublicEnvError(`${key} must be an absolute download URL.`);
    }
    const local =
      input.NEXT_PUBLIC_APP_ENV === "local" &&
      url.protocol === "http:" &&
      ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
    if (
      (url.protocol !== "https:" && !local) ||
      url.username ||
      url.password ||
      url.hash ||
      value.trim().endsWith("#")
    )
      throw new PublicEnvError(
        `${key} must use HTTPS without credentials or a fragment (local loopback HTTP is allowed only in local development).`,
      );
    return url.toString();
  }
  const android = download(
    input.NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL,
    "NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL",
  );
  const ios = download(
    input.NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL,
    "NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL",
  );
  return Object.freeze({
    ...(android ? { android } : {}),
    ...(ios ? { ios } : {}),
  });
}
export function readHandoffConfig(): HandoffConfig {
  return parseHandoffConfig({
    NEXT_PUBLIC_APP_ENV: process.env.NEXT_PUBLIC_APP_ENV,
    NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL:
      process.env.NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL,
    NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL:
      process.env.NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL,
  });
}
