import { afterEach, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../src/app";

describe("health routes", () => {
  let app: FastifyInstance | undefined;

  afterEach(async () => {
    if (app) {
      await app.close();
      app = undefined;
    }
  });

  it("returns liveness without requiring a database", async () => {
    app = buildApp({ checkDatabase: async () => undefined });
    const response = await app.inject({ method: "GET", url: "/health/live" });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      status: "ok",
      service: "firefa-backend",
    });
  });

  it("returns ready when the database check succeeds", async () => {
    app = buildApp({ checkDatabase: async () => undefined });
    const response = await app.inject({ method: "GET", url: "/health/ready" });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      status: "ready",
      database: "reachable",
    });
  });

  it("returns 503 when the database is unavailable", async () => {
    app = buildApp({
      checkDatabase: async () => {
        throw new Error("database unavailable");
      },
    });
    const response = await app.inject({ method: "GET", url: "/health/ready" });

    expect(response.statusCode).toBe(503);
    expect(response.json()).toEqual({
      status: "not_ready",
      database: "unavailable",
    });
  });
});