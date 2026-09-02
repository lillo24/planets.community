import { Spinner } from "@/components/ui/spinner";

type LoadingStateProps = {
  label?: string;
};

export function LoadingState({ label = "Loading" }: LoadingStateProps) {
  return (
    <div
      className="flex items-center gap-2 text-sm text-muted-foreground"
      role="status"
      aria-live="polite"
    >
      <Spinner aria-hidden="true" />
      <span>{label}</span>
    </div>
  );
}
