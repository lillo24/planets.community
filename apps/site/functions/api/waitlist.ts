import { handleWaitlistRequest } from "../waitlist";

export const onRequest: PagesFunction<WaitlistEnv> = ({ request, env }) =>
  handleWaitlistRequest(request, env);
