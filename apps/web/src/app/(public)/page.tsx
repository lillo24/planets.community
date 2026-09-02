export default function PublicHomePage() {
  return (
    <main className="flex min-h-screen items-center justify-center p-8">
      <section
        aria-labelledby="public-home-title"
        className="flex max-w-2xl flex-col gap-4"
      >
        <p className="text-sm font-semibold tracking-[0.2em]">PLANETS</p>
        <h1 id="public-home-title" className="text-4xl font-semibold">
          Build something local, together.
        </h1>
        <p className="max-w-xl text-lg text-muted-foreground">
          PLANETS is a community for creating, discovering, and joining local
          collaborative activities. Public discovery features will arrive in a
          later implementation phase.
        </p>
      </section>
    </main>
  );
}
