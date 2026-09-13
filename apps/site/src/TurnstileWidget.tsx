import { useEffect } from "react";

const turnstileScriptUrl =
  "https://challenges.cloudflare.com/turnstile/v0/api.js";
const errorCallbackName = "planetsTurnstileError";
const successCallbackName = "planetsTurnstileSuccess";

type TurnstileWidgetProps = {
  siteKey: string;
  onError: () => void;
  onSuccess: () => void;
};

export function TurnstileWidget({
  siteKey,
  onError,
  onSuccess,
}: TurnstileWidgetProps) {
  useEffect(() => {
    window[errorCallbackName] = onError;
    window[successCallbackName] = onSuccess;

    if (document.querySelector(`script[src="${turnstileScriptUrl}"]`)) {
      return () => {
        delete window[errorCallbackName];
        delete window[successCallbackName];
      };
    }

    const script = document.createElement("script");
    script.src = turnstileScriptUrl;
    script.async = true;
    script.defer = true;
    document.head.append(script);

    return () => {
      delete window[errorCallbackName];
      delete window[successCallbackName];
    };
  }, [onError, onSuccess]);

  return (
    <div
      className="cf-turnstile waitlist__turnstile"
      data-sitekey={siteKey}
      data-action="waitlist_signup"
      data-theme="light"
      data-error-callback={errorCallbackName}
      data-expired-callback={errorCallbackName}
      data-timeout-callback={errorCallbackName}
      data-callback={successCallbackName}
      aria-label="Verifica anti-abuso"
    />
  );
}
