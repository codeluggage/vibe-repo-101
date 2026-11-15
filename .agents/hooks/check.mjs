// Hook after a file edit: type-check the project.
// Exit 2 sends the errors back to the agent, so it fixes them before going on.
// Node, so one file works on Windows, macOS and Linux. No decisions beyond that.
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));
const run = spawnSync("gleam", ["check"], { cwd: root, encoding: "utf8" });
if (run.error) process.exit(0); // no gleam on this computer: nothing to check with
if (run.status !== 0) {
  process.stderr.write(`gleam check failed:\n${run.stdout}${run.stderr}`);
  process.exit(2);
}
