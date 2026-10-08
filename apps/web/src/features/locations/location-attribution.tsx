/** Fixed credit targets also cover provider-derived text retained after clear. */
export function LocationAttribution() {
  return (
    <p
      className="flex flex-wrap gap-x-3 gap-y-1 text-sm text-muted-foreground"
      aria-label="Location data credits"
    >
      <a
        href="https://www.geoapify.com/"
        target="_blank"
        rel="noopener noreferrer"
        className="underline"
      >
        Powered by Geoapify
      </a>
      <a
        href="https://www.openstreetmap.org/copyright"
        target="_blank"
        rel="noopener noreferrer"
        className="underline"
      >
        © OpenStreetMap contributors
      </a>
    </p>
  );
}
