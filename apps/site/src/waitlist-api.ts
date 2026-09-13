export type WaitlistSubmission = {
  email: string;
  consent: true;
  turnstileToken: string;
};

type WaitlistResponse = {
  ok?: boolean;
};

export async function submitWaitlist(
  submission: WaitlistSubmission,
): Promise<void> {
  const response = await fetch("/api/waitlist", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(submission),
  });

  let result: WaitlistResponse | null = null;
  try {
    result = (await response.json()) as WaitlistResponse;
  } catch {
    // A malformed response is a failure, never a success-shaped fallback.
  }

  if (!response.ok || result?.ok !== true) {
    throw new Error("Waitlist request failed.");
  }
}
