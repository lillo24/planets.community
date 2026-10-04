import type { ParticipantFailure } from "./participant-models";
export function participantFailureMessage(failure: ParticipantFailure): string {
  switch (failure) {
    case "unavailable":
      return "This link cannot be used to join now. It may have been replaced, revoked, or the activity may no longer accept participants.";
    case "full":
      return "This Project is full. No place is reserved by this link.";
    case "identity":
      return "Your account or permission changed. Check your sign-in and try again.";
    case "profile":
      return "Complete your basic profile before joining. A profile photo is not required for this invitation.";
    case "input":
      return "The join action could not be validated. Check this invitation before trying again.";
    case "network":
      return "We could not confirm the response. Check your connection and retry the same join action if one is pending.";
    case "malformed":
      return "We could not read a valid response. Retry the read or check the previous join; its result is not confirmed.";
  }
}
