// drizzle-kit generate で作った SQL を適用する専用スクリプト（npm run db:migrate）。
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";

import { config } from "../../config.js";

const migrationClient = postgres(config.databaseUrl, { max: 1 });

async function main() {
  await migrate(drizzle(migrationClient), { migrationsFolder: "./drizzle" });
  console.log("✅ migrations applied");
  await migrationClient.end();
}

main().catch((err) => {
  console.error("❌ migration failed:", err);
  process.exit(1);
});
