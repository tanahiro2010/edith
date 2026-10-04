// drizzle-kit generate で作った SQL を適用する。
// - npm run db:migrate で直接実行
// - 起動時(index.ts)からも runMigrations() として呼ぶ
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";

import { config } from "../../config.js";

export async function runMigrations(): Promise<void> {
  const client = postgres(config.databaseUrl, { max: 1 });
  try {
    await migrate(drizzle(client), { migrationsFolder: "./drizzle" });
  } finally {
    await client.end();
  }
}

// CLI として直接実行されたときだけ動かす。
if (import.meta.url === `file://${process.argv[1]}`) {
  runMigrations()
    .then(() => {
      console.log("✅ migrations applied");
      process.exit(0);
    })
    .catch((err) => {
      console.error("❌ migration failed:", err);
      process.exit(1);
    });
}
