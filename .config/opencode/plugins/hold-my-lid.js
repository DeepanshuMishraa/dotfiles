// managed by Wake My Mac; local changes will be replaced on version upgrades.
// HOLD_MY_LID_INTEGRATION=opencode:1
import { mkdir, rename, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";

export const WatchMyMac = async () => {
  const blocked = new Set();
  const sequence = new Map();
  const report = async (sessionID, status) => {
    if (!sessionID) return;
    const dir = join(homedir(), "Library", "Application Support", "Hold My Lid", "Sessions");
    await mkdir(dir, { recursive: true });
    const id = `opencode-${sessionID}`;
    const file = join(dir, `${id}.json`);
    const temp = `${file}.${process.pid}.tmp`;
    const next = (sequence.get(id) ?? Date.now() * 1000) + 1;
    sequence.set(id, next);
    await writeFile(temp, JSON.stringify({ id, agent: "OpenCode", title: "OpenCode", status, lastUpdated: new Date().toISOString(), pid: process.pid, source: "opencode-adapter", sequence: next }));
    await rename(temp, file);
  };

  return {
    event: async ({ event }) => {
      const p = event?.properties ?? {};
      const sessionID = p.sessionID ?? p.info?.id;
      switch (event?.type) {
        case "session.status": {
          const type = p.status?.type;
          await report(sessionID, blocked.has(sessionID) ? "blocked" : (type === "busy" || type === "retry" ? "working" : "idle"));
          break;
        }
        case "permission.asked": blocked.add(sessionID); await report(sessionID, "blocked"); break;
        case "permission.replied": blocked.delete(sessionID); await report(sessionID, "working"); break;
        case "session.idle": blocked.delete(sessionID); await report(sessionID, "idle"); break;
        case "session.deleted": blocked.delete(sessionID); await report(sessionID, "absent"); break;
      }
    },
  };
};
