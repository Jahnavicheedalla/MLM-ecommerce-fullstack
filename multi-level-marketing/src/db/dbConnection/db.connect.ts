import * as dotenv from 'dotenv';
dotenv.config(); // Load variables from .env

import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import type { PoolConfig } from 'pg';

// Factory function to create database pool
function createDatabasePool(): Pool {
  const databaseUrl = process.env.DATABASE_URL;

  if (databaseUrl) {
    console.log('✅ Using DATABASE_URL for database connection');
    const ssl: PoolConfig['ssl'] =
      process.env.NODE_ENV === 'production'
        ? { rejectUnauthorized: false }
        : undefined;

    const config: PoolConfig = {
      connectionString: databaseUrl,
      ssl,
    };

    return new Pool(config);
  }

  // Check for individual parameters
  const host = process.env.HOST;
  const user = process.env.USER;
  const password = process.env.PASSWORD;
  const database = process.env.DATABASE;

  if (!host || !user || !password || !database) {
    console.error('❌ Missing required environment variables');
    console.error(
      '💡 Please set DATABASE_URL or HOST, USER, PASSWORD, DATABASE',
    );
    process.exit(1);
  }

  console.log(
    '⚠️  DATABASE_URL not found, falling back to individual parameters',
  );

  const port = Number(process.env.PORT || '5432');

  console.log('Connecting to DB with individual parameters:', {
    host,
    port,
    user,
    database,
  });

  const config: PoolConfig = {
    host,
    port,
    user,
    password,
    database,
  };

  return new Pool(config);
}

// Create the pool using the factory function
const databasePool = createDatabasePool();

// Export the drizzle database instance
export const db = drizzle(databasePool);

// Database ping function with proper error handling
export async function pingDatabase(): Promise<void> {
  try {
    await databasePool.query('SELECT 1');
  } catch (error: unknown) {
    const errorMessage =
      error instanceof Error ? error.message : 'Unknown database error';
    console.error('Database ping failed:', errorMessage);
    throw new Error(`Database ping failed: ${errorMessage}`);
  }
}
