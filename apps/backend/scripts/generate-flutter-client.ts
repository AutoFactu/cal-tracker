import { copyFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";

const source = resolve(process.cwd(), "../../packages/contracts/openapi.json");
const targetDir = resolve(process.cwd(), "../mobile/lib/generated/api");
mkdirSync(targetDir, { recursive: true });
copyFileSync(source, resolve(targetDir, "openapi.json"));
console.log("Copied OpenAPI spec for Flutter client generation.");
