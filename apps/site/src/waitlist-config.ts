const configuredSiteKey = import.meta.env.VITE_TURNSTILE_SITE_KEY?.trim();

export const WAITLIST_TURNSTILE_SITE_KEY = configuredSiteKey || null;
