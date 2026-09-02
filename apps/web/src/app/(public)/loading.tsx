import { LoadingState } from "@/components/states/loading-state";

export default function Loading() {
  return (
    <main className="flex min-h-screen items-center justify-center p-8">
      <LoadingState label="Loading PLANETS" />
    </main>
  );
}
