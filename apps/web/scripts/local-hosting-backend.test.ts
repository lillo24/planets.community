// @vitest-environment node
import { describe, expect, it } from "vitest";
import { assertHostingBackend } from "./local-hosting-backend.mjs";

describe("disposable hosting backend guard", () => {
  const config = 'project_id = "planets-community-webhost01-qa"\n';
  const status = {
    apiUrl: "http://127.0.0.1:54361",
    databaseUrl: "postgresql://postgres:local@127.0.0.1:54362/postgres",
  };

  it("accepts only the named local fixture endpoints", () => {
    expect(() => assertHostingBackend(config, status)).not.toThrow();
  });

  it.each([
    "",
    'project_id = "planets-community"\n',
    'project_id = "another-project"\n',
  ])("rejects another project: %s", (value) => {
    expect(() => assertHostingBackend(value, status)).toThrow();
  });

  it.each([
    { apiUrl: "http://127.0.0.1:54321" },
    { apiUrl: "https://example.com" },
    { databaseUrl: undefined },
    { databaseUrl: "postgresql://postgres:local@example.com:54362/postgres" },
    { databaseUrl: "postgresql://postgres:local@127.0.0.1:54322/postgres" },
  ])("rejects unsafe endpoints: %j", (value) => {
    expect(() =>
      assertHostingBackend(config, { ...status, ...value }),
    ).toThrow();
  });

  const integratedConfig = 'project_id = "planets-community-modint01-qa"\n';
  const integratedStatus = {
    apiUrl: "http://127.0.0.1:54611",
    databaseUrl: "postgresql://postgres:local@127.0.0.1:54612/postgres",
  };
  it("requires explicit MODINT01 selection for its exact project/endpoints", () => {
    expect(() =>
      assertHostingBackend(integratedConfig, integratedStatus),
    ).toThrow();
    expect(() =>
      assertHostingBackend(integratedConfig, integratedStatus, "modint01"),
    ).not.toThrow();
    expect(() => assertHostingBackend(config, status, "modint01")).toThrow();
  });
  it.each([
    { apiUrl: "http://127.0.0.1:54361" },
    { databaseUrl: "postgresql://postgres:local@127.0.0.1:54362/postgres" },
    { databaseUrl: "postgresql://postgres:local@example.com:54612/postgres" },
    { apiUrl: "https://example.com" },
  ])("rejects unsafe MODINT01 endpoints: %j", (value) => {
    expect(() =>
      assertHostingBackend(
        integratedConfig,
        { ...integratedStatus, ...value },
        "modint01",
      ),
    ).toThrow();
  });
  it("does not accept arbitrary target names", () => {
    expect(() => assertHostingBackend(config, status, "main")).toThrow();
  });
});
