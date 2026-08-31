// managed by Wake My Mac; local changes will be replaced on version upgrades.
// HOLD_MY_LID_INTEGRATION=pi:1
import { mkdir, rename, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";

export default function (pi) {
  let sessionID = `pi-${process.pid}`;
  let sequence = Date.now() * 1000;
  let active = false;
  let blocked = 0;

  const report = async (status) => {
    const dir = join(homedir(), "Library", "Application Support", "Hold My Lid", "Sessions");
    await mkdir(dir, { recursive: true });
    const file = join(dir, `${sessionID}.json`);
    const temp = `${file}.${process.pid}.tmp`;
    const payload = {
      id: sessionID,
      agent: "Pi",
      title: "Pi",
      status,
      lastUpdated: new Date().toISOString(),
      pid: process.pid,
      source: "pi-adapter",
      sequence: ++sequence,
    };
    await writeFile(temp, JSON.stringify(payload));
    await rename(temp, file);
  };

  pi.on("session_start", async (_event, ctx) => {
    const id = ctx?.sessionManager?.getSessionId?.();
    if (typeof id === "string" && id) sessionID = `pi-${id}`;
    await report("idle");
  });
  pi.on("agent_start", async () => { active = true; await report(blocked > 0 ? "blocked" : "working"); });
  pi.on("turn_start", async () => { active = true; await report(blocked > 0 ? "blocked" : "working"); });
  pi.on("agent_end", async () => { active = false; await report(blocked > 0 ? "blocked" : "idle"); });
  pi.events.on("herdr:blocked", async (data) => {
    blocked = data?.active ? blocked + 1 : Math.max(0, blocked - 1);
    await report(blocked > 0 ? "blocked" : (active ? "working" : "idle"));
  });
  pi.on("session_shutdown", async () => { await report("absent"); });
}
