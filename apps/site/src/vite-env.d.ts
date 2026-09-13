/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_TURNSTILE_SITE_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

interface Window {
  planetsTurnstileError?: () => void;
  planetsTurnstileSuccess?: () => void;
  turnstile?: {
    reset: () => void;
  };
}
