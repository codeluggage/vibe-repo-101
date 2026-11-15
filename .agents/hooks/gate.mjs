// Hook when the agent wants to finish: check, test and format must pass.
// Exit 2 sends the failure back as the next thing to fix. A second stop in a
// row is let through, so the agent never loops.
// Node, so one file works on Windows, macOS and Linux.
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));

let payload = "";
try {
  payload = readFileSync(0, "utf8");
} catch {
  // no input: run the checks
}
if (/"stop_hook_active"\s*:\s*true/.test(payload)) {
  console.log("{}");
  process.exit(0);
}

const steps = [["check"], ["test"], ["format", "--check", "src", "test", "dev"]];
for (const step of steps) {
  const run = spawnSync("gleam", step, { cwd: root, encoding: "utf8" });
  if (run.error) break; // no gleam on this computer: nothing to check with
  if (run.status !== 0) {
    const tail = `${run.stdout}${run.stderr}`.split("\n").slice(-60).join("\n");
    process.stderr.write(`gleam ${step.join(" ")} failed:\n${tail}`);
    process.exit(2);
  }
}
console.log("{}");
