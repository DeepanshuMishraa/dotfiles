import { Type } from "@mariozechner/pi-ai";
import { defineTool, type ExtensionAPI } from "@mariozechner/pi-coding-agent";
import path from "node:path";
import fs from "node:fs/promises";
import os from "node:os";
import { existsSync } from "node:fs";

const REFS_HOME = path.join(os.homedir(), ".local/share/pi/repos");
const REGISTRY_PATH = path.join(REFS_HOME, "registry.json");
const CONFIG_PATH = path.join(os.homedir(), ".pi/agent/pi-refs.json");
const TTL_MS = 5 * 24 * 60 * 60 * 1000;
const GC_INTERVAL_MS = 30 * 60 * 1000;

interface RegistryEntry {
  localPath: string;
  clonedAt: string;
  lastUsedAt: string;
}

interface Registry {
  repos: Record<string, RegistryEntry>;
}

interface RefEntry {
  repository: string;
  branch?: string;
  description?: string;
}

interface RefConfig {
  references: Record<string, string | RefEntry>;
}

async function loadConfig(): Promise<RefConfig> {
  try {
    const raw = await fs.readFile(CONFIG_PATH, "utf-8");
    return JSON.parse(raw) as RefConfig;
  } catch {
    return { references: {} };
  }
}

async function loadRegistry(): Promise<Registry> {
  try {
    const raw = await fs.readFile(REGISTRY_PATH, "utf-8");
    return JSON.parse(raw) as Registry;
  } catch {
    return { repos: {} };
  }
}

async function saveRegistry(r: Registry): Promise<void> {
  await fs.mkdir(REFS_HOME, { recursive: true });
  await fs.writeFile(REGISTRY_PATH, JSON.stringify(r, null, 2));
}

function resolveRepo(input: string): { url: string; cacheDir: string } | null {
  const g = input.match(/^(?:https?:\/\/)?github\.com\/([^\/]+\/[^\/]+?)(?:\.git)?$/);
  if (g?.[1]) {
    const r = g[1].replace(/\.git$/, "");
    return { url: `https://github.com/${r}.git`, cacheDir: path.join(REFS_HOME, "github.com", r) };
  }
  const s = input.match(/^([a-zA-Z0-9_-]+\/[a-zA-Z0-9._-]+)$/);
  if (s?.[1]) {
    return { url: `https://github.com/${s[1]}.git`, cacheDir: path.join(REFS_HOME, "github.com", s[1]) };
  }
  if (input.startsWith("/") || input.startsWith("~") || input.startsWith(".")) {
    const p = input.startsWith("~") ? path.join(os.homedir(), input.slice(1)) : path.resolve(input);
    return { url: "", cacheDir: p };
  }
  return null;
}

function isExpired(e: RegistryEntry): boolean {
  return Date.now() - new Date(e.lastUsedAt).getTime() > TTL_MS;
}

interface RepoRef {
  repository: string;
  branch?: string;
}

async function ensureReference(
  name: string,
  ref: RepoRef,
  execFn: ExtensionAPI["exec"],
): Promise<{ localPath: string; status: "cloned" | "cached" | "expired" | "local" }> {
  const resolved = resolveRepo(ref.repository);
  if (!resolved) {
    throw new Error(`Cannot resolve repository: ${ref.repository}`);
  }

  const registry = await loadRegistry();
  const existing = registry.repos[name];

  if (!resolved.url) {
    return { localPath: resolved.cacheDir, status: "local" };
  }

  const now = new Date().toISOString();

  if (existing && existing.localPath === resolved.cacheDir) {
    if (isExpired(existing)) {
      if (existsSync(resolved.cacheDir)) {
        await fs.rm(resolved.cacheDir, { recursive: true, force: true });
      }
      await cloneRepo(resolved.url, resolved.cacheDir, ref.branch, execFn);
      registry.repos[name] = { localPath: resolved.cacheDir, clonedAt: now, lastUsedAt: now };
      await saveRegistry(registry);
      return { localPath: resolved.cacheDir, status: "cloned" };
    }
    registry.repos[name] = { ...existing, lastUsedAt: now };
    await saveRegistry(registry);
    return { localPath: resolved.cacheDir, status: "cached" };
  }

  await cloneRepo(resolved.url, resolved.cacheDir, ref.branch, execFn);
  registry.repos[name] = { localPath: resolved.cacheDir, clonedAt: now, lastUsedAt: now };
  await saveRegistry(registry);
  return { localPath: resolved.cacheDir, status: "cloned" };
}

async function cloneRepo(
  url: string,
  target: string,
  branch: string | undefined,
  exec: ExtensionAPI["exec"],
): Promise<void> {
  await fs.mkdir(path.dirname(target), { recursive: true });
  const args = ["clone", "--depth", "1"];
  if (branch) {
    args.push("--branch", branch);
  }
  args.push(url, target);
  const r = await exec("git", args);
  if (r.code !== 0) {
    throw new Error(`git clone failed: ${r.stderr}`);
  }
}

async function runGC(exec: ExtensionAPI["exec"]): Promise<string[]> {
  const registry = await loadRegistry();
  const removed: string[] = [];
  for (const [name, entry] of Object.entries(registry.repos)) {
    if (isExpired(entry)) {
      if (existsSync(entry.localPath)) {
        await fs.rm(entry.localPath, { recursive: true, force: true });
      }
      delete registry.repos[name];
      removed.push(name);
    }
  }
  await saveRegistry(registry);
  return removed;
}

const AT_REF_PATTERN = /(?:^|(?<=\s))@([a-zA-Z_][a-zA-Z0-9_-]*)/g;

function atRefReplacer(_match: string, name: string, ref: string | RefEntry, localPath: string): string {
  const repo = typeof ref === "string" ? ref : ref.repository;
  const desc = typeof ref === "object" && ref.description ? ` (${ref.description})` : "";
  return `@${name}${desc} [cloned at ${localPath} from ${repo}]`;
}

export default function piRefsExtension(pi: ExtensionAPI) {
  const exec = pi.exec;
  let gcTimer: ReturnType<typeof setInterval> | null = null;

  pi.on("input", async (event, ctx) => {
    if (event.source === "extension") return { action: "continue" };

    const text = event.text;
    const matches = Array.from(text.matchAll(AT_REF_PATTERN));
    if (matches.length === 0) return { action: "continue" };

    const config = await loadConfig();
    const refs = config.references;
    const resolved = new Map<string, { ref: string | RefEntry; localPath: string }>();

    for (const m of matches) {
      const name = m[1];
      if (!name || !(name in refs)) continue;
      if (resolved.has(name)) continue;
      try {
        const ref = refs[name]!;
        const repoRef: RepoRef = typeof ref === "string" ? { repository: ref } : { repository: ref.repository, branch: ref.branch };
        const result = await ensureReference(name, repoRef, exec);
        resolved.set(name, { ref, localPath: result.localPath });
      } catch {
        ctx.ui.notify(`Failed to clone reference "${name}"`, "error");
      }
    }

    if (resolved.size === 0) return { action: "continue" };

    const transformed = text.replace(AT_REF_PATTERN, (match, name) => {
      const entry = resolved.get(name);
      if (!entry) return match;
      return atRefReplacer(match, name, entry.ref, entry.localPath);
    });

    return { action: "transform", text: transformed };
  });

  pi.on("before_agent_start", async (event) => {
    const config = await loadConfig();
    const refs = config.references;
    const entries = Object.keys(refs);
    if (entries.length === 0) return;

    const lines = entries.map((name) => {
      const ref = refs[name]!;
      const repo = typeof ref === "string" ? ref : ref.repository;
      const desc = typeof ref === "object" && ref.description ? ` - ${ref.description}` : "";
      return `  - ${name}: ${repo}${desc}`;
    });

    return {
      systemPrompt:
        event.systemPrompt
        + "\n\n<available_repo_references>\n"
        + lines.join("\n")
        + "\n</available_repo_references>\n"
        + "Type @<refname> in your prompt (e.g. @effect) to clone and reference a repo. "
        + "Repos auto-delete after 5 days of inactivity.",
    };
  });

  const useRepoRefTool = defineTool({
    name: "use_repo_reference",
    label: "Use Repo Reference",
    description:
      "Clone or access a referenced repository by name and return its local path. "
      + "The repo is cached for 5 days and auto-deleted if unused. "
      + "Pass name=\"list\" to see available references.",
    parameters: Type.Object({
      name: Type.String({ description: "Reference name from config. Use \"list\" to see all available." }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      if (params.name === "list") {
        const config = await loadConfig();
        const names = Object.entries(config.references).map(([n, e]) => {
          const repo = typeof e === "string" ? e : e.repository;
          const desc = typeof e === "object" && e.description ? ` - ${e.description}` : "";
          return `  - ${n}: ${repo}${desc}`;
        });
        return {
          content: [{
            type: "text",
            text: names.length > 0
              ? `Available references:\n${names.join("\n")}`
              : "No references configured. Edit ~/.pi/agent/pi-refs.json or use `/refs add <name> <repo>`.",
          }],
          details: {},
        };
      }

      const config = await loadConfig();
      const raw = config.references[params.name];
      if (!raw) {
        return {
          content: [{
            type: "text",
            text: `Reference "${params.name}" not found. Use name="list" to see available references.`,
          }],
          details: {},
          isError: true,
        };
      }

      const ref: RepoRef = typeof raw === "string" ? { repository: raw } : raw;

      try {
        const result = await ensureReference(params.name, ref, exec);
        return {
          content: [{
            type: "text",
            text: `Repository "${params.name}" is available at:\n  ${result.localPath}\nStatus: ${result.status}`,
          }],
          details: result,
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: `Failed to setup reference "${params.name}": ${err}` }],
          details: { error: String(err) },
          isError: true,
        };
      }
    },
  });

  pi.registerCommand("refs", {
    description: "List, add, or inspect repository references",
    async handler(args, ctx) {
      const parts = args.trim().split(/\s+/);
      const sub = parts[0]!;

      if (sub === "add" && parts.length >= 3 && parts[1]) {
        const name = parts[1];
        const repo = parts.slice(2).join(" ");
        const config = await loadConfig();
        const ref = (repo.startsWith("/") || repo.startsWith(".") || repo.startsWith("~")) ? repo : { repository: repo };
        config.references[name] = ref;
        await fs.mkdir(path.dirname(CONFIG_PATH), { recursive: true });
        await fs.writeFile(CONFIG_PATH, JSON.stringify(config, null, 2));
        ctx.ui.notify(`Added reference "${name}" -> ${repo}`);
        return;
      }

      if (sub === "rm" && parts.length >= 2 && parts[1]) {
        const name = parts[1];
        const config = await loadConfig();
        if (name in config.references) {
          delete config.references[name];
          await fs.writeFile(CONFIG_PATH, JSON.stringify(config, null, 2));
        }
        const registry = await loadRegistry();
        const entry = registry.repos[name];
        if (entry) {
          if (existsSync(entry.localPath)) {
            await fs.rm(entry.localPath, { recursive: true, force: true });
          }
          delete registry.repos[name];
          await saveRegistry(registry);
        }
        ctx.ui.notify(`Removed reference "${name}"`);
        return;
      }

      if (sub === "rm-expired") {
        const removed = await runGC(exec);
        ctx.ui.notify(removed.length > 0
          ? `Removed ${removed.length} expired repo(s): ${removed.join(", ")}`
          : "No expired repos found");
        return;
      }

      const config = await loadConfig();
      const refs = config.references;
      const registry = await loadRegistry();
      const lines: string[] = [];

      for (const [name, entry] of Object.entries(refs)) {
        const repo = typeof entry === "string" ? entry : entry.repository;
        const desc = typeof entry === "object" && entry.description ? ` - ${entry.description}` : "";
        const cached = registry.repos[name];
        const status = cached
          ? `[cached, expires ${new Date(new Date(cached.lastUsedAt).getTime() + TTL_MS).toLocaleDateString()}]`
          : "[not cloned]";
        lines.push(`  ${name}: ${repo} ${status}${desc}`);
      }

      ctx.ui.notify(`References:\n${lines.join("\n") || "  (none)"}`);
    },
  });

  pi.registerTool(useRepoRefTool);

  pi.on("session_start", async (_event, ctx) => {
    const removed = await runGC(exec);
    if (removed.length > 0) {
      ctx.ui.notify(`Reaped ${removed.length} expired repo(s): ${removed.join(", ")}`);
    }
  });

  pi.on("session_shutdown", async () => {
    if (gcTimer !== null) {
      clearInterval(gcTimer);
      gcTimer = null;
    }
  });

  gcTimer = setInterval(async () => {
    try {
      await runGC(exec);
    } catch {
      // retry on next interval
    }
  }, GC_INTERVAL_MS);
}
