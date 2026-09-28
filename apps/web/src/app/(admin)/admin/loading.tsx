import { Spinner } from "@/components/ui/spinner";

export default function AdminLoading() {
  return (
    <main className="mx-auto flex w-full max-w-5xl flex-1 items-center justify-center p-10">
      <p className="flex items-center gap-3" role="status">
        <Spinner /> Loading moderation queue…
      </p>
    </main>
  );
}
