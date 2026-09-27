const profilePhotoBucket = "profile-photos";
const fixtureVersion = "a8f00000-0000-4000-8000-000000000001";
const tinyWebp = Buffer.from(
  "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
  "base64",
);

export async function ensureLocalProfilePhoto(
  user,
  { audience = "interactions" } = {},
) {
  const { data: existing, error: readError } = await user.client.rpc(
    "get_own_profile_photo",
    { p_expected_profile_id: user.id },
  );
  if (readError) throw safeFailure("read the fixture profile photo", readError);
  if (existing?.length === 1) return existing[0];
  if (existing?.length !== 0) {
    throw new Error("Fixture profile photo read returned invalid cardinality.");
  }

  const objectPath = `${user.id}/${fixtureVersion}.webp`;
  await user.client.storage.from(profilePhotoBucket).remove([objectPath]);
  const { error: uploadError } = await user.client.storage
    .from(profilePhotoBucket)
    .upload(objectPath, tinyWebp, {
      contentType: "image/webp",
      upsert: false,
    });
  if (uploadError) {
    throw safeFailure("upload the fixture profile photo", uploadError);
  }

  const { data, error } = await user.client.rpc("set_own_profile_photo", {
    p_expected_profile_id: user.id,
    p_object_path: objectPath,
    p_audience: audience,
  });
  if (error || data?.length !== 1) {
    throw safeFailure("commit the fixture profile photo", error ?? {});
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
