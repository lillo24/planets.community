"use client";

import { useEffect } from "react";

import { captureClientException } from "@/lib/monitoring/capture-client-exception";

type GlobalErrorProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function GlobalError({ error, reset }: GlobalErrorProps) {
  useEffect(() => {
    captureClientException(error);
  }, [error]);

  return (
    <html lang="en">
      <body
        style={{
          alignItems: "center",
          background: "#ffffff",
          color: "#171717",
          display: "flex",
          fontFamily: "Arial, Helvetica, sans-serif",
          justifyContent: "center",
          margin: 0,
          minHeight: "100vh",
          padding: "2rem",
        }}
      >
        <main style={{ maxWidth: "32rem" }}>
          <title>PLANETS could not load</title>
          <h1>PLANETS could not load</h1>
          <p>Try again. No error details have been shown on this page.</p>
          <button
            type="button"
            onClick={reset}
            style={{
              background: "#171717",
              border: 0,
              borderRadius: "0.5rem",
              color: "#ffffff",
              cursor: "pointer",
              padding: "0.625rem 0.875rem",
            }}
          >
            Try again
          </button>
        </main>
      </body>
    </html>
  );
}
