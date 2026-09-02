import { notFound } from "next/navigation";

export default function AdminPage(): never {
  // Ordinary authentication is not admin authorization. Keep this route
  // fail-closed until the moderation/admin plan defines least-privilege access.
  notFound();
}
