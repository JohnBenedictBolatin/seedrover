import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const projectRoot = resolve(import.meta.dirname, "..", "..");
const trackedFiles = execFileSync("git", ["ls-files"], {
  cwd: projectRoot,
  encoding: "utf8",
})
  .split(/\r?\n/)
  .filter(Boolean);

const forbiddenEnvFiles = trackedFiles.filter((file) => {
  const name = file.split(/[\\/]/).pop() ?? "";
  return /^\.env(?:\.|$)/.test(name) && name !== ".env.example";
});

const credentialFilePattern = /(?:^|[\\/])(?:secrets?|credentials?)\.(?:env|json|h)$/i;
const trackedCredentialFiles = trackedFiles.filter((file) => credentialFilePattern.test(file));

const assignmentPattern = /(?:SUPABASE_SERVICE_ROLE_KEY|GEMINI_API_KEY|FCM_SERVICE_ACCOUNT_JSON|MQTT_PASSWORD|ROVER_DEVICE_SECRET)\s*=\s*['"]?(?!$|your_|use-the-exact-same-token|<|\.\.\.)[^\s'"#]+/i;
const trackedCredentialAssignments = [];

for (const file of trackedFiles) {
  if (file.endsWith(".lock") || file === ".env.example" || file === "web-admin/.env.example") {
    continue;
  }

  const absolutePath = resolve(projectRoot, file);
  if (!existsSync(absolutePath)) continue;

  const contents = readFileSync(absolutePath, "utf8");
  if (assignmentPattern.test(contents)) {
    trackedCredentialAssignments.push(file);
  }
}

const failures = [
  ...forbiddenEnvFiles.map((file) => `tracked environment file: ${file}`),
  ...trackedCredentialFiles.map((file) => `tracked credential file: ${file}`),
  ...trackedCredentialAssignments.map((file) => `credential-like assignment: ${file}`),
];

if (failures.length > 0) {
  console.error("Tracked secret check failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(`Tracked secret check passed (${trackedFiles.length} files inspected).`);
