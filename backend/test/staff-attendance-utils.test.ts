import { describe, expect, it } from "vitest";
import { distanceMeters, lateMinutes, localWorkDate } from "../src/routes/staff-attendance-utils";

describe("staff attendance calculations", () => {
  it("returns zero distance for the same coordinates", () => {
    expect(distanceMeters(-7.25, 112.75, -7.25, 112.75)).toBe(0);
  });

  it("calculates distance in meters and can distinguish the configured radius", () => {
    const distance = distanceMeters(-7.2575, 112.7521, -7.2585, 112.7521);
    expect(distance).toBeGreaterThan(100);
    expect(distance).toBeLessThan(120);
  });

  it("allows flexible check-in when no expected start time exists", () => {
    expect(lateMinutes(null, new Date("2026-10-16T09:45:00.000Z"), "Asia/Jakarta")).toBeNull();
  });

  it("measures lateness against the expected local start time", () => {
    expect(lateMinutes("16:00:00", new Date("2026-10-16T09:15:00.000Z"), "Asia/Jakarta")).toBe(15);
    expect(lateMinutes("16:00:00", new Date("2026-10-16T08:45:00.000Z"), "Asia/Jakarta")).toBe(0);
  });

  it("calculates the work date in the outlet time zone", () => {
    expect(localWorkDate(new Date("2026-10-16T17:30:00.000Z"), "Asia/Jakarta")).toBe("2026-10-17");
  });
});
