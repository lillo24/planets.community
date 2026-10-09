"use client";

import { CircleAlertIcon, CircleCheckIcon } from "lucide-react";
import { useClientNavigation } from "@/lib/navigation/client-navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FieldLegend,
  FieldSet,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Spinner } from "@/components/ui/spinner";
import { Textarea } from "@/components/ui/textarea";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import {
  createWebProfileGateway,
  type WebProfileGateway,
} from "@/features/profile/profile-gateway";
import {
  hasProfileValidationErrors,
  normalizeProfileUpdate,
  validateProfileUpdate,
  type ProfileAudience,
  type ProfileEditorData,
  type ProfileFieldKey,
  type ProfileValidationErrors,
} from "@/features/profile/profile-models";

type ProfileFormProps = Readonly<{
  initialData: ProfileEditorData;
  returnTo?: string;
  gateway?: WebProfileGateway;
  onRefresh?: () => void;
  // Invitation setup collects only a name; omitted fields keep their loaded values.
  nameOnly?: boolean;
}>;

export function ProfileFormView({
  initialData,
  returnTo = "/profile",
  gateway,
  onRefresh,
  nameOnly = false,
}: ProfileFormProps) {
  const router = useClientNavigation();
  const [profileGateway] = useState(() => gateway ?? createWebProfileGateway());
  const lock = useRef(false);
  const live = useRef(true);
  useEffect(() => {
    live.current = true;
    return () => {
      live.current = false;
    };
  }, []);
  const [displayName, setDisplayName] = useState(
    initialData.profile.displayName ?? "",
  );
  const [bio, setBio] = useState(initialData.profile.bio ?? "");
  const [selectedSkillIds, setSelectedSkillIds] = useState(
    () => new Set(initialData.profile.selectedSkillIds),
  );
  const [visibility, setVisibility] = useState(initialData.profile.visibility);
  const [errors, setErrors] = useState<ProfileValidationErrors>({});
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const [saved, setSaved] = useState(false);

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (lock.current) {
      return;
    }
    const update = normalizeProfileUpdate({
      expectedProfileId: initialData.profile.id,
      displayName,
      bio,
      selectedSkillIds: [...selectedSkillIds],
      visibility,
    });
    const validation = validateProfileUpdate(update);
    setErrors(validation);
    if (hasProfileValidationErrors(validation)) {
      return;
    }

    lock.current = true;
    setBusy(true);
    setFailed(false);
    setSaved(false);
    try {
      await profileGateway.updateOwnProfile(update);
      if (!live.current) return;
      setDisplayName(update.displayName);
      setBio(update.bio);
      setSaved(true);
      if (onRefresh) {
        onRefresh();
      } else if (returnTo !== "/profile") {
        router.replace(returnTo);
      } else {
        router.refresh();
      }
    } catch {
      setFailed(true);
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }

  function setSkill(skillId: string, selected: boolean) {
    setSelectedSkillIds((current) => {
      const next = new Set(current);
      if (selected) {
        next.add(skillId);
      } else {
        next.delete(skillId);
      }
      return next;
    });
  }

  function setAudience(field: ProfileFieldKey, values: string[]) {
    const audience = values[0];
    if (audience !== "public" && audience !== "private") {
      return;
    }
    setVisibility((current) => ({ ...current, [field]: audience }));
  }

  const incomplete = initialData.profile.displayName === null;

  return (
    <Card className="w-full" aria-labelledby="profile-settings-title">
      <CardHeader>
        <CardTitle id="profile-settings-title">
          {nameOnly
            ? "What's your name?"
            : incomplete
              ? "Complete your profile"
              : "Your profile"}
        </CardTitle>
        <CardDescription>
          {nameOnly
            ? "Add your name to continue. You can personalize your profile in the app."
            : "Display name is required. Bio and controlled skills are optional, and each field can be public or private."}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form id="profile-settings-form" onSubmit={save} noValidate>
          <FieldGroup>
            <Field data-invalid={errors.displayName !== undefined || undefined}>
              <FieldLabel htmlFor="profile-display-name">
                {nameOnly ? "Name" : "Display name"}
              </FieldLabel>
              <Input
                id="profile-display-name"
                value={displayName}
                onChange={(event) => setDisplayName(event.target.value)}
                maxLength={60}
                required
                disabled={busy}
                aria-invalid={errors.displayName !== undefined || undefined}
              />
              <FieldDescription>
                The name shown on your PLANETS profile. Casing is preserved.
              </FieldDescription>
              {errors.displayName ? (
                <FieldError>{errors.displayName}</FieldError>
              ) : null}
            </Field>

            {!nameOnly ? (
              <>
                <Field data-invalid={errors.bio !== undefined || undefined}>
                  <FieldLabel htmlFor="profile-bio">Bio</FieldLabel>
                  <Textarea
                    id="profile-bio"
                    value={bio}
                    onChange={(event) => setBio(event.target.value)}
                    maxLength={500}
                    rows={4}
                    disabled={busy}
                    aria-invalid={errors.bio !== undefined || undefined}
                    placeholder="Share how you enjoy contributing."
                  />
                  <FieldDescription>
                    Optional, up to 500 characters.
                  </FieldDescription>
                  {errors.bio ? <FieldError>{errors.bio}</FieldError> : null}
                </Field>

                <FieldSet>
                  <FieldLegend>Skills</FieldLegend>
                  <FieldDescription>
                    Choose capabilities you would enjoy bringing to community
                    projects.
                  </FieldDescription>
                  {initialData.categories.map((category) => (
                    <FieldSet key={category.id}>
                      <FieldLegend variant="label">
                        {category.label}
                      </FieldLegend>
                      <FieldGroup data-slot="checkbox-group">
                        {category.skills.map((skill) => {
                          const skillId = `profile-skill-${skill.slug}`;
                          return (
                            <Field key={skill.id} orientation="horizontal">
                              <Checkbox
                                id={skillId}
                                checked={selectedSkillIds.has(skill.id)}
                                onCheckedChange={(checked) =>
                                  setSkill(skill.id, checked)
                                }
                                disabled={busy}
                              />
                              <FieldContent>
                                <FieldLabel htmlFor={skillId}>
                                  {skill.label}
                                </FieldLabel>
                              </FieldContent>
                            </Field>
                          );
                        })}
                      </FieldGroup>
                    </FieldSet>
                  ))}
                </FieldSet>

                <FieldSet>
                  <FieldLegend>Public profile visibility</FieldLegend>
                  <FieldDescription>
                    Public viewers see only fields marked public. You always see
                    your complete profile.
                  </FieldDescription>
                  <VisibilityField
                    field="display_name"
                    label="Display name"
                    value={visibility.display_name}
                    disabled={busy}
                    onChange={setAudience}
                  />
                  <VisibilityField
                    field="bio"
                    label="Bio"
                    value={visibility.bio}
                    disabled={busy}
                    onChange={setAudience}
                  />
                  <VisibilityField
                    field="skills"
                    label="Skills"
                    value={visibility.skills}
                    disabled={busy}
                    onChange={setAudience}
                  />
                </FieldSet>
              </>
            ) : null}

            {failed ? (
              <Alert variant="destructive" aria-live="polite">
                <CircleAlertIcon />
                <AlertTitle>Profile was not saved</AlertTitle>
                <AlertDescription>
                  Your previous profile is unchanged. Check your connection and
                  try again.
                </AlertDescription>
              </Alert>
            ) : null}
            {saved ? (
              <Alert aria-live="polite">
                <CircleCheckIcon />
                <AlertTitle>Profile saved</AlertTitle>
                <AlertDescription>
                  {nameOnly
                    ? "Your name is saved. You can personalize your profile in the app."
                    : "Your profile and visibility choices are up to date."}
                </AlertDescription>
              </Alert>
            ) : null}
          </FieldGroup>
        </form>
      </CardContent>
      <CardFooter>
        <Button type="submit" form="profile-settings-form" disabled={busy}>
          {busy ? <Spinner data-icon="inline-start" /> : null}
          {nameOnly ? "Continue" : "Save profile"}
        </Button>
      </CardFooter>
    </Card>
  );
}

function VisibilityField({
  field,
  label,
  value,
  disabled,
  onChange,
}: Readonly<{
  field: ProfileFieldKey;
  label: string;
  value: ProfileAudience;
  disabled: boolean;
  onChange(field: ProfileFieldKey, values: string[]): void;
}>) {
  return (
    <Field>
      <FieldLabel id={`${field}-visibility-label`}>{label}</FieldLabel>
      <ToggleGroup
        aria-labelledby={`${field}-visibility-label`}
        value={[value]}
        onValueChange={(values) => onChange(field, values)}
        multiple={false}
        variant="outline"
        spacing={0}
        disabled={disabled}
      >
        <ToggleGroupItem value="public">Public</ToggleGroupItem>
        <ToggleGroupItem value="private">Private</ToggleGroupItem>
      </ToggleGroup>
    </Field>
  );
}
