import { notFound } from "next/navigation";

export default function AdminPage(): never {
  // Authentication and authorization are introduced by roadmap plan 03.
  // Until then this route must not expose a plausible admin shell.
  notFound();
}
