import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";

import { config } from "../../config.js";
import * as schema from "./schema.js";

// postgres.js のコネクションは使い回す（プロセス全体で 1 つ）。
const queryClient = postgres(config.databaseUrl);

export const db = drizzle(queryClient, { schema });
export { schema };
