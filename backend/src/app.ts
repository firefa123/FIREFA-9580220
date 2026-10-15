import Fastify, { type FastifyInstance } from "fastify";
import { Pool } from "pg";

export interface AppDependencies {
  checkDatabase?: () => Promise<void>;
}

export function buildApp(dependencies: AppDependencies = {}): FastifyInstance {
  const app = Fastify({ logger: process.env.NODE_ENV !== "test" });
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });

  const checkDatabase =
    dependencies.checkDatabase ??
    (async () => {
      await pool.query("SELECT 1");
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