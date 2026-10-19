import Fastify from "fastify";
import jwt from "@fastify/jwt";
import type { Pool, PoolClient } from "pg";
import { afterEach, describe, expect, it, vi } from "vitest";
import { outletLocationRoutes } from "./outlet-location";

const tenantId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const outletId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const userId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const jwtSecret = "test-secret-that-is-long-enough-for-firefa";

async function setup(role: string, outletRole: string | undefined = role) {
  const client = {
    query: vi.fn()
      .mockResolvedValueOnce({ rows: outletRole ? [{ role: outletRole }] : [], rowCount: outletRole ? 1 : 0 })
      .mockResolvedValueOnce({
        rows: [{ outletId, latitude: -6.2, longitude: 106.8, radiusMeters: 100 }],
        rowCount: 1,
      }),
    release: vi.fn(),
  };
  const pool = { connect: vi.fn().mockResolvedValue(client) } as unknown as Pool;
  const app = Fastify({ logger: false });
  app.register(jwt, { secret: jwtSecret });
  app.register(outletLocationRoutes, { prefix: "/api/v1", pool });

  await app.ready();
  const token = app.jwt.sign({ sub: userId, tenantId, role, outletIds: [outletId] });
  return { app, client, token };
}

afterEach(() => vi.restoreAllMocks());

describe("PATCH /api/v1/staff/geofence-location", () => {
  it("allows Owner to set valid coordinates and preserves the configured radius", async () => {
    const { app, client, token } = await setup("owner", "owner");
    const response = await app.inject({
      method: "PATCH",
      url: "/api/v1/staff/geofence-location",
      headers: { authorization: `Bearer ${token}` },
      payload: { outletId, latitude: -6.2, longitude: 106.8 },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().geofence.radiusMeters).toBe(100);
    const update = client.query.mock.calls[1]?.[0] as string;
    expect(update).toContain("SET latitude = $1, longitude = $2, updated_at = now()");
    expect(update).not.toMatch(/SET[^;]*geofence_radius_m\s*=/i);
    expect(client.query.mock.calls[1]?.[1]).toEqual([-6.2, 106.8, outletId, tenantId]);
    await app.close();
  });

  it.each([
    { outletId, latitude: -91, longitude: 106.8 },
    { outletId, latitude: 91, longitude: 106.8 },
    { outletId, latitude: -6.2, longitude: -181 },
    { outletId, latitude: -6.2, longitude: 181 },
  ])("rejects invalid coordinate values", async (payload) => {
    const { app, client, token } = await setup("owner", "owner");
    await app.ready();
    const response = await app.inject({
      method: "PATCH",
      url: "/api/v1/staff/geofence-location",
      headers: { authorization: `Bearer ${token}` },
      payload,
    });
    expect(response.statusCode).toBe(400);
    expect(client.query).not.toHaveBeenCalled();
    await app.close();
  });

  it.each(["cashier", "staff"])("denies %s even with valid coordinates", async (role) => {
    const { app, client, token } = await setup(role, role);
    await app.ready();
    const response = await app.inject({
      method: "PATCH",
      url: "/api/v1/staff/geofence-location",
      headers: { authorization: `Bearer ${token}` },
      payload: { outletId, latitude: -6.2, longitude: 106.8 },
    });
    expect(response.statusCode).toBe(403);
    expect(response.json().error).toBe("owner_required");
    expect(client.query).not.toHaveBeenCalled();
    await app.close();
  });

  it("denies an Owner who is not a member of the outlet", async () => {
    const { app, client, token } = await setup("owner", undefined);
    await app.ready();
    const response = await app.inject({
      method: "PATCH",
      url: "/api/v1/staff/geofence-location",
      headers: { authorization: `Bearer ${token}` },
      payload: { outletId, latitude: -6.2, longitude: 106.8 },
    });
    expect(response.statusCode).toBe(403);
    expect(response.json().error).toBe("outlet_forbidden");
    expect(client.query).toHaveBeenCalledTimes(1);
    await app.close();
  });

  it("requires authentication", async () => {
    const { app, client } = await setup("owner", "owner");
    await app.ready();
    const response = await app.inject({
      method: "PATCH",
      url: "/api/v1/staff/geofence-location",
      payload: { outletId, latitude: -6.2, longitude: 106.8 },
    });
    expect(response.statusCode).toBe(401);
    expect(client.query).not.toHaveBeenCalled();
    await app.close();
  });
});
