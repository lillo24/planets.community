// Apple glyph: Simple Icons apple.svg (CC0), github.com/simple-icons/simple-icons.
const applePath =
  "M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701";

export function StoreBadge({
  platform,
  href,
}: Readonly<{ platform: "android" | "ios"; href?: string }>) {
  const android = platform === "android";
  const name = android ? "Google Play" : "App Store";
  const content = (
    <>
      {android ? (
        <svg aria-hidden="true" viewBox="0 0 24 24" className="size-8 shrink-0">
          <path fill="#4285f4" d="M3 2 13 12 3 22Z" />
          <path fill="#34a853" d="m3 2 13 6-3 4Z" />
          <path fill="#fbbc04" d="m16 8 6 4-6 4-3-4Z" />
          <path fill="#ea4335" d="m3 22 13-6-3-4Z" />
        </svg>
      ) : (
        <svg
          aria-hidden="true"
          viewBox="0 0 24 24"
          className="size-8 shrink-0"
          fill="currentColor"
        >
          <path d={applePath} />
        </svg>
      )}
      <span className="grid gap-0.5 leading-none">
        <span className="text-[10px] tracking-wide">
          {href ? (android ? "GET IT ON" : "Download on the") : "COMING SOON"}
        </span>
        <span className="text-xl font-medium tracking-tight">{name}</span>
      </span>
    </>
  );
  const className =
    "inline-flex h-14 min-w-44 items-center justify-start gap-3 rounded-xl border border-white/20 bg-black px-4 text-left text-white transition-colors focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-violet-500";
  return href ? (
    <a
      href={href}
      className={`${className} hover:bg-zinc-800`}
      aria-label={`Download on ${name}`}
      rel="noreferrer"
      referrerPolicy="no-referrer"
    >
      {content}
    </a>
  ) : (
    <button
      type="button"
      disabled
      className={`${className} cursor-default opacity-60`}
      aria-label={`${name} (coming soon)`}
    >
      {content}
    </button>
  );
}
