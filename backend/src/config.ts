import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  HOST: z.string().default("0.0.0.0"),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z.string().min(1, "DATABASE_URL is required"),
  JWT_SECRET: z.string().min(32, "JWT_SECRET must contain at least 32 characters"),
  BOOTSTRAP_TOKEN: z.string().min(32, "BOOTSTRAP_TOKEN must contain at least 32 characters"),
  PLATFORM_ADMIN_BOOTSTRAP_TOKEN: z.string().min(32, "PLATFORM_ADMIN_BOOTSTRAP_TOKEN must contain at least 32 characters"),
});

export type AppConfig = z.infer<typeof envSchema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const config = envSchema.parse(env);
  if (config.NODE_ENV === "production") {
    const secrets = [config.JWT_SECRET, config.BOOTSTRAP_TOKEN, config.PLATFORM_ADMIN_BOOTSTRAP_TOKEN];
    if (secrets.some((secret) =>
      secret.toLowerCase().includes("replace-with") ||
      secret.toLowerCase().includes("change-this") ||
      secret.toLowerCase().includes("example") ||
      secret.toLowerCase().includes("secret-that-is-at-least")
    )) {
      throw new Error("Production JWT_SECRET, BOOTSTRAP_TOKEN, and PLATFORM_ADMIN_BOOTSTRAP_TOKEN must be unique random secrets, not template values");
    }
  }
  return config;
}