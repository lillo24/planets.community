import { createClient } from "@supabase/supabase-js";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/u, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
const bucket = "profile-photos";
const tinyWebp = Buffer.from(
  "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
  "base64",
);

await verifyProfilePhotos();

async function verifyProfilePhotos() {
  const [userA, userB] = await Promise.all([
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "profile-photo-storage-a@planets.invalid",
      verifierName: "profile photo A",
    }),
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "profile-photo-storage-b@planets.invalid",
      verifierName: "profile photo B",
    }),
  ]);
  await Promise.all([ensureProfileAnchor(userA), ensureProfileAnchor(userB)]);

  const userAPaths = [
    `${userA.id}/10000000-0000-4000-8000-000000000001.webp`,
    `${userA.id}/10000000-0000-4000-8000-000000000002.webp`,
    `${userA.id}/10000000-0000-4000-8000-000000000003.webp`,
    `${userA.id}/10000000-0000-4000-8000-000000000004.webp`,
  ];
  const wrongMimePath = `${userA.id}/10000000-0000-4000-8000-000000000005.webp`;
  const oversizedPath = `${userA.id}/10000000-0000-4000-8000-000000000006.webp`;
  const userBPath = `${userB.id}/20000000-0000-4000-8000-000000000001.webp`;
  const cleanupAPaths = [...userAPaths, wrongMimePath, oversizedPath];

  await cleanup(userA, cleanupAPaths);
  await cleanup(userB, [userBPath]);

  try {
    await expectStorageFailure(
      userB.client.storage.from(bucket).upload(userAPaths[0], tinyWebp, {
        contentType: "image/webp",
        upsert: false,
      }),
      "upload another user's profile-photo path",
    );
    await expectStorageFailure(
      userA.client.storage.from(bucket).upload(wrongMimePath, tinyWebp, {
        contentType: "image/png",
        upsert: false,
      }),
      "upload a non-WebP profile photo",
    );
    await expectStorageFailure(
      userA.client.storage
        .from(bucket)
        .upload(oversizedPath, Buffer.alloc(256001), {
          contentType: "image/webp",
          upsert: false,
        }),
      "upload a profile photo larger than 250 KiB",
    );

    await upload(userA, userAPaths[0]);
    await upload(userB, userBPath);
    await expectStorageFailure(
      userA.client.storage.from(bucket).upload(userAPaths[0], tinyWebp, {
        contentType: "image/webp",
        upsert: false,
      }),
      "overwrite an immutable profile-photo path",
    );
    await expectStorageFailure(
      userA.client.storage.from(bucket).update(userAPaths[0], tinyWebp, {
        contentType: "image/webp",
        upsert: false,
      }),
      "update an immutable profile-photo object",
    );

    const { data: ownerDownload, error: ownerDownloadError } =
      await userA.client.storage.from(bucket).download(userAPaths[0]);
    if (ownerDownloadError || !ownerDownload || ownerDownload.size === 0) {
      throw safeStorageFailure(
        "download the owner's private profile photo",
        ownerDownloadError ?? {},
      );
    }
    await expectStorageFailure(
      userB.client.storage.from(bucket).download(userAPaths[0]),
      "download another user's private profile photo",
    );

    const anonymous = createClient(apiUrl, publishableKey, {
      auth: { persistSession: false },
    });
    await expectStorageFailure(
      anonymous.storage.from(bucket).download(userAPaths[0]),
      "download a profile photo anonymously",
    );

    const initialCommit = await setPhoto(userA, userAPaths[0], "interactions");
    if (
      initialCommit.current_object_path !== userAPaths[0] ||
      initialCommit.previous_object_path !== null ||
      initialCommit.audience !== "interactions"
    ) {
      throw new Error(
        "The first canonical profile-photo commit returned unexpected metadata.",
      );
    }
    await assertCanonicalPhoto(userA, {
      objectPath: userAPaths[0],
      audience: "interactions",
    });

    const { error: crossIdentityError } = await userB.client.rpc(
      "get_own_profile_photo",
      { p_expected_profile_id: userA.id },
    );
    if (crossIdentityError?.code !== "42501") {
      throw new Error(
        "A cross-user expected profile was not rejected by the owner read.",
      );
    }

    const { data: audienceRows, error: audienceError } = await userA.client.rpc(
      "set_own_profile_photo_audience",
      {
        p_expected_profile_id: userA.id,
        p_audience: "public",
      },
    );
    if (
      audienceError ||
      audienceRows?.length !== 1 ||
      audienceRows[0].audience !== "public"
    ) {
      throw safeDatabaseFailure(
        "change the owner profile-photo audience",
        audienceError ?? {},
      );
    }
    const { data: publicDownload, error: publicDownloadError } =
      await anonymous.storage.from(bucket).download(userAPaths[0]);
    if (publicDownloadError || !publicDownload || publicDownload.size === 0) {
      throw safeStorageFailure(
        "download a canonical public-audience photo anonymously",
        publicDownloadError ?? {},
      );
    }

    await upload(userA, userAPaths[1]);
    const replacement = await setPhoto(userA, userAPaths[1], "public");
    if (
      replacement.current_object_path !== userAPaths[1] ||
      replacement.previous_object_path !== userAPaths[0]
    ) {
      throw new Error(
        "Canonical replacement did not return the exact previous object path.",
      );
    }
    await assertCanonicalPhoto(userA, {
      objectPath: userAPaths[1],
      audience: "public",
    });

    await Promise.all([
      upload(userA, userAPaths[2]),
      upload(userA, userAPaths[3]),
    ]);
    const concurrentResults = await Promise.all([
      setPhoto(userA, userAPaths[2], "interactions"),
      setPhoto(userA, userAPaths[3], "public"),
    ]);
    const { data: finalRows, error: finalReadError } = await userA.client.rpc(
      "get_own_profile_photo",
      { p_expected_profile_id: userA.id },
    );
    if (finalReadError || finalRows?.length !== 1) {
      throw safeDatabaseFailure(
        "read the final concurrent canonical photo",
        finalReadError ?? {},
      );
    }
    const finalPath = finalRows[0].object_path;
    const finalResult = concurrentResults.find(
      (result) => result.current_object_path === finalPath,
    );
    const otherConcurrentPath =
      userAPaths[2] === finalPath ? userAPaths[3] : userAPaths[2];
    if (
      !userAPaths.slice(2).includes(finalPath) ||
      !finalResult ||
      finalResult.previous_object_path !== otherConcurrentPath
    ) {
      throw new Error(
        "Concurrent canonical commits were not serialized through one final row.",
      );
    }

    const { data: clearedPath, error: clearError } = await userA.client.rpc(
      "clear_own_profile_photo",
      { p_expected_profile_id: userA.id },
    );
    if (clearError || clearedPath !== finalPath) {
      throw safeDatabaseFailure(
        "clear the canonical profile photo",
        clearError ?? {},
      );
    }
    const { data: emptyRows, error: emptyReadError } = await userA.client.rpc(
      "get_own_profile_photo",
      { p_expected_profile_id: userA.id },
    );
    if (emptyReadError || emptyRows?.length !== 0) {
      throw safeDatabaseFailure(
        "confirm cleared profile-photo metadata",
        emptyReadError ?? {},
      );
    }

    await remove(userA, userAPaths);
    await remove(userB, [userBPath]);
    await expectStorageFailure(
      userA.client.storage.from(bucket).download(finalPath),
      "download a deleted profile-photo object",
    );

    console.log(
      "Confirmed owner-only WebP writes, 250 KiB enforcement, immutable paths, canonical replacement/concurrency, public viewer delivery, clear, and Storage API cleanup.",
    );
  } finally {
    await userA.client.rpc("clear_own_profile_photo", {
      p_expected_profile_id: userA.id,
    });
    await cleanup(userA, cleanupAPaths);
    await cleanup(userB, [userBPath]);
  }
}

async function ensureProfileAnchor(user) {
  const { error } = await user.client.from("profiles").insert({ id: user.id });
  if (error) {
    const diagnostic = `${error.message ?? ""} ${error.details ?? ""}`;
    if (error.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a profile anchor", error);
    }
  }
}

async function upload(user, objectPath) {
  const { error } = await user.client.storage
    .from(bucket)
    .upload(objectPath, tinyWebp, {
      contentType: "image/webp",
      upsert: false,
    });
  if (error) {
    throw safeStorageFailure("upload an owner profile photo", error);
  }
}

async function setPhoto(user, objectPath, audience) {
  const { data, error } = await user.client.rpc("set_own_profile_photo", {
    p_expected_profile_id: user.id,
    p_object_path: objectPath,
    p_audience: audience,
  });
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure(
      "commit canonical profile-photo metadata",
      error ?? {},
    );
  }
  return data[0];
}

async function assertCanonicalPhoto(user, { objectPath, audience }) {
  const { data, error } = await user.client.rpc("get_own_profile_photo", {
    p_expected_profile_id: user.id,
  });
  if (
    error ||
    data?.length !== 1 ||
    data[0].profile_id !== user.id ||
    data[0].object_path !== objectPath ||
    data[0].audience !== audience ||
    Object.keys(data[0]).sort().join(",") !==
      "audience,created_at,object_path,profile_id,updated_at"
  ) {
    throw safeDatabaseFailure(
      "read canonical profile-photo metadata",
      error ?? {},
    );
  }
}

async function remove(user, objectPaths) {
  const { error } = await user.client.storage.from(bucket).remove(objectPaths);
  if (error) {
    throw safeStorageFailure("delete owner profile-photo objects", error);
  }
}

async function cleanup(user, objectPaths) {
  try {
    await user.client.storage.from(bucket).remove(objectPaths);
  } catch {
    // Best-effort cleanup must not conceal the verifier's original failure.
  }
}

async function expectStorageFailure(operation, action) {
  const { error } = await operation;
  if (!error) {
    throw new Error(`Unexpectedly succeeded to ${action}.`);
  }
}

function safeStorageFailure(action, error) {
  const statusCode = Number.isInteger(error?.statusCode)
    ? error.statusCode
    : "unknown";
  return new Error(`Failed to ${action} (HTTP ${statusCode}).`);
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
