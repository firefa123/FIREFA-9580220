import Fastify, { type FastifyInstance } from "fastify";
import jwt from "@fastify/jwt";
import { Pool } from "pg";
import { authRoutes } from "./routes/auth";
import { syncRoutes } from "./routes/sync";
import { catalogRoutes } from "./routes/catalog";
import { paymentRoutes } from "./routes/payments";
import { staffAttendanceRoutes } from "./routes/staff-attendance";
import { outletLocationRoutes } from "./routes/outlet-location";
import { publicOrderRoutes } from "./routes/public-orders";
import { platformAdminRoutes } from "./routes/platform-admin";

export interface AppDependencies {
  checkDatabase?: () => Promise<void>;
  pool?: Pool;
  jwtSecret?: string;
  bootstrapToken?: string;
  platformAdminBootstrapToken?: string;
}

export function buildApp(dependencies: AppDependencies = {}): FastifyInstance {
  const jwtSecret = dependencies.jwtSecret ?? process.env.JWT_SECRET;
  const bootstrapToken = dependencies.bootstrapToken ?? process.env.BOOTSTRAP_TOKEN;
  const platformAdminBootstrapToken = dependencies.platformAdminBootstrapToken ?? process.env.PLATFORM_ADMIN_BOOTSTRAP_TOKEN;
  if (!jwtSecret || jwtSecret.length < 32) {
    throw new Error("JWT_SECRET must contain at least 32 characters");
  }
  if (!bootstrapToken || bootstrapToken.length < 32) {
    throw new Error("BOOTSTRAP_TOKEN must contain at least 32 characters");
  }

  if (!platformAdminBootstrapToken || platformAdminBootstrapToken.length < 32) {
    throw new Error("PLATFORM_ADMIN_BOOTSTRAP_TOKEN must contain at least 32 characters");
  }

  const app = Fastify({ logger: process.env.NODE_ENV !== "test" });
  const pool = dependencies.pool ?? new Pool({ connectionString: process.env.DATABASE_URL });

  // Flutter Web runs on a different localhost port from the API. Allow local
  // development origins and explicitly configured production web origins.
  const configuredOrigins = new Set(
    (process.env.CORS_ORIGINS ?? "")
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
  );

  app.addHook("onRequest", async (request, reply) => {
    const origin = request.headers.origin;
    if (typeof origin !== "string") return;

    const localOrigin = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
    if (!localOrigin && !configuredOrigins.has(origin)) return;

    reply.header("Access-Control-Allow-Origin", origin);
    reply.header("Vary", "Origin");
    reply.header(
      "Access-Control-Allow-Methods",
      "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    );
    reply.header(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization, X-Bootstrap-Token, X-Platform-Bootstrap-Token, Idempotency-Key, If-Match",
    );

    if (request.method === "OPTIONS") {
      return reply.code(204).send();
    }
  });

  app.options("/*", async (_request, reply) => reply.code(204).send());

  const checkDatabase =
    dependencies.checkDatabase ??
    (async () => {
      await pool.query("SELECT 1");
    });

  app.register(jwt, {
    secret: jwtSecret,
    sign: { expiresIn: "15m" },
  });
  app.register(authRoutes, {
    prefix: "/api/v1/auth",
    pool,
    bootstrapToken,
  });
  app.register(syncRoutes, {
    prefix: "/api/v1/sync",
    pool,
  });
  app.register(catalogRoutes, {
    prefix: "/api/v1",
    pool,
  });
  app.register(paymentRoutes, {
    prefix: "/api/v1",
    pool,
  });
  app.register(staffAttendanceRoutes, {
    prefix: "/api/v1",
    pool,
  });
  app.register(outletLocationRoutes, {
    prefix: "/api/v1",
    pool,
  });
  app.register(publicOrderRoutes, {
    prefix: "/api/v1/public",
    pool,
  });
  app.register(platformAdminRoutes, {
    prefix: "/api/v1/platform-admin",
    pool,
    bootstrapToken: platformAdminBootstrapToken!,
  });

  app.get("/health/live", async () => ({
    status: "ok",
    service: "firefa-backend",
  }));

  app.get("/health/ready", async (_request, reply) => {
    try {
      await checkDatabase();
      return { status: "ready", database: "reachable" };
    } catch {
      return reply.code(503).send({
        status: "not_ready",
        database: "unavailable",
      });
    }
  });

  app.addHook("onClose", async () => {
    await pool.end();
  });

  return app;
}
