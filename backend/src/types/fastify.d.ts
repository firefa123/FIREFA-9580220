import "@fastify/jwt";

type FirefaRole = "owner" | "cashier" | "staff";

declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: {
      sub: string;
      tenantId: string;
      role: FirefaRole;
      outletIds: string[];
    };
    user: {
      sub: string;
      tenantId: string;
      role: FirefaRole;
      outletIds: string[];
    };
  }
}
