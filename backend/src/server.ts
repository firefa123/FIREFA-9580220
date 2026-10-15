import { buildApp } from "./app";
import { loadConfig } from "./config";

async function main(): Promise<void> {
  const config = loadConfig();
  const app = buildApp();

  const shutdown = async (signal: string): Promise<void> => {
    app.log.info({ signal }, "Shutting down FIREFA backend");
    await app.close();
    process.exit(0);
  };

  process.once("SIGINT", () => void shutdown("SIGINT"));
  process.once("SIGTERM", () => void shutdown("SIGTERM"));

  try {
    await app.listen({ host: config.HOST, port: config.PORT });
  } catch (error) {
    app.log.error(error);
    await app.close();
    process.exitCode = 1;
  }
}

void main();