import { handleWaitlistRequest } from "./waitlist";

type WaitlistHandler = typeof handleWaitlistRequest;

function apiNotFoundResponse() {
  return Response.json(
    { ok: false, code: "not_found" },
    {
      status: 404,
      headers: {
        "Cache-Control": "no-store",
      },
    },
  );
}

export async function routeWorkerRequest(
  request: Request,
  env: WorkerEnv,
  waitlistHandler: WaitlistHandler = handleWaitlistRequest,
) {
  const { pathname } = new URL(request.url);

  if (pathname === "/api/waitlist") {
    return waitlistHandler(request, env);
  }

  if (pathname.startsWith("/api/")) {
    return apiNotFoundResponse();
  }

  return env.ASSETS.fetch(request);
}

export default {
  fetch(request, env) {
    return routeWorkerRequest(request, env);
  },
} satisfies ExportedHandler<WorkerEnv>;
