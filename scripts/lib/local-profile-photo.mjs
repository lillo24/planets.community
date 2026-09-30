import { readFile } from "node:fs/promises";

const profilePhotoBucket = "profile-photos";
const defaultFixtureVersion = "a8f00000-0000-4000-8000-000000000001";
const tinyWebp = Buffer.from(
  "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
  "base64",
);

export async function ensureLocalProfilePhoto(
  user,
  {
    audience = "interactions",
    fixturePath = null,
    fixtureVersion = defaultFixtureVersion,
  } = {},
) {
  const { data: existing, error: readError } = await user.client.rpc(
    "get_own_profile_photo",
    { p_expected_profile_id: user.id },
  );
  if (readError) throw safeFailure("read the fixture profile photo", readError);
  if (!Array.isArray(existing) || existing.length > 1) {
    throw new Error("Fixture profile photo read returned invalid cardinality.");
  }

  const objectPath = `${user.id}/${fixtureVersion}.webp`;
  if (
    existing.length === 1 &&
    (fixturePath === null ||
      (existing[0].object_path === objectPath &&
        existing[0].audience === audience))
  ) {
    return existing[0];
  }

  let bytes = tinyWebp;
  if (fixturePath !== null) {
    try {
      bytes = await readFile(fixturePath);
    } catch (error) {
      throw safeFailure("read the fixture profile photo", error);
    }
  }

  const { error: uploadError } = await user.client.storage
    .from(profilePhotoBucket)
    .upload(objectPath, bytes, {
      contentType: "image/webp",
      upsert: false,
    });
  const uploadedNewObject = !uploadError;
  if (uploadError && uploadError.code !== "KeyAlreadyExists") {
    throw safeFailure("upload the fixture profile photo", uploadError);
  }

  const { data, error } = await user.client.rpc("set_own_profile_photo", {
    p_expected_profile_id: user.id,
    p_object_path: objectPath,
    p_audience: audience,
  });
  if (error || data?.length !== 1) {
    if (uploadedNewObject) {
      await user.client.storage.from(profilePhotoBucket).remove([objectPath]);
    }
    throw safeFailure("commit the fixture profile photo", error ?? {});
  }
  const previousObjectPath = existing[0]?.object_path;
  if (previousObjectPath && previousObjectPath !== objectPath) {
    await user.client.storage
      .from(profilePhotoBucket)
      .remove([previousObjectPath]);
  }
  return {
    profile_id: user.id,
    object_path: data[0].current_object_path,
    updated_at: data[0].updated_at,
  };
}

function safeFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
