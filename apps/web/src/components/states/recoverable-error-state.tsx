"use client";

import { CircleAlertIcon } from "lucide-react";

import {
  Alert,
  AlertAction,
  AlertDescription,
  AlertTitle,
} from "@/components/ui/alert";
import { Button } from "@/components/ui/button";

type RecoverableErrorStateProps = {
  title: string;
  description: string;
  onRetry: () => void;
};

export function RecoverableErrorState({
  title,
  description,
  onRetry,
}: RecoverableErrorStateProps) {
  return (
    <Alert variant="destructive" className="max-w-xl">
      <CircleAlertIcon />
      <AlertTitle>{title}</AlertTitle>
      <AlertDescription>{description}</AlertDescription>
      <AlertAction>
        <Button type="button" variant="outline" size="sm" onClick={onRetry}>
          Try again
        </Button>
      </AlertAction>
    </Alert>
  );
}
