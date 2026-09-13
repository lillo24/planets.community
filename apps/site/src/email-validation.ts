const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/u;

export function validateEmailAddress(value: string): boolean {
  const email = value.trim();

  return email.length <= 254 && emailPattern.test(email);
}
