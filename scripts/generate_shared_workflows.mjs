import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const contract = JSON.parse(await readFile(path.join(root, "contracts/shared-workflows.json"), "utf8"));
const dartLiteral = (value) => JSON.stringify(value).replaceAll("$", "\\$");
const dartStrings = Object.entries(contract.terms)
  .map(([key, value]) => `  static const ${key} = ${dartLiteral(value)};`).join("\n");
const dartChoices = Object.entries(contract.choices)
  .map(([key, values]) => `  static const ${key} = <String>[${values.map(dartLiteral).join(", ")}];`).join("\n");
const dartRules = Object.entries(contract.rules)
  .map(([key, value]) => `  static const ${key} = ${dartLiteral(value)};`).join("\n");
const dartDiffs = Object.entries(contract.intentionalDifferences)
  .map(([key, value]) => `  static const ${key} = ${dartLiteral(JSON.stringify(value))};`).join("\n");
const dart = `// Generated from contracts/shared-workflows.json. Do not edit by hand.\nabstract final class SharedWorkflowTerms {\n  static const version = ${contract.version};\n${dartStrings}\n}\n\nabstract final class SharedWorkflowChoices {\n${dartChoices}\n}\n\nabstract final class SharedWorkflowRules {\n${dartRules}\n}\n\nabstract final class IntentionalPlatformDifferences {\n${dartDiffs}\n}\n`;
const ts = `// Generated from contracts/shared-workflows.json. Do not edit by hand.\nexport const sharedWorkflowContractVersion = ${contract.version} as const;\nexport const sharedWorkflowTerms = ${JSON.stringify(contract.terms)} as const;\nexport const sharedWorkflowChoices = ${JSON.stringify(contract.choices)} as const;\nexport const sharedWorkflowRules = ${JSON.stringify(contract.rules)} as const;\nexport const intentionalPlatformDifferences = ${JSON.stringify(contract.intentionalDifferences)} as const;\n`;

const outputs = [
  ["lib/core/constants/shared_workflow_terms.dart", dart],
  ["web-admin/src/lib/shared-workflow-terms.ts", ts],
];
let stale = false;
for (const [file, contents] of outputs) {
  const target = path.join(root, file);
  if (process.argv.includes("--check")) {
    let current = "";
    try { current = await readFile(target, "utf8"); } catch {}
    if (current !== contents) {
      console.error(`${file} is out of date`);
      stale = true;
    }
  } else {
    await writeFile(target, contents);
  }
}
if (stale) process.exitCode = 1;
