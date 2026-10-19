import Fastify, { type FastifyInstance } from "fastify";
import jwt from "@fastify/jwt";
import { Pool } from "pg";
import { authRoutes } from "./routes/auth";
import { syncRoutes } from "./routes/sync";
import { catalogRoutes } from "./routes/catalog";
import { paymentRoutes } from "./routes/payments";
import { staffAttendanceRoutes } from "./routes/staff-attendance";
import { outletLocationRoutes } from "./routes/outlet-location";

export interface AppDependencies {
  checkDatabase?: () => Promise<void>;
  pool?: Pool;
  jwtSecret?: string;
  bootstrapToken?: string;
}

export function buildApp(dependencies: AppDependencies = {}): FastifyInstance {
  const jwtSecret = dependencies.jwtSecret ?? process.env.JWT_SECRET;
  const bootstrapToken = dependencies.bootstrapToken ?? process.env.BOOTSTRAP_TOKEN;
  if (!jwtSecret || jwtSecret.length < 32) {
    throw new Error("JWT_SECRET must contain at least 32 characters");
  }
  if (!bootstrapToken || bootstrapToken.length < 32) {
    throw new Error("BOOTSTRAP_TOKEN must contain at least 32 characters");
  }

  const app = Fastify({ logger: process.env.NODE_ENV !== "test" });
  const pool = dependencies.pool ?? new Pool({ connectionString: process.env.DATABASE_URL });

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