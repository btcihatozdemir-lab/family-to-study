import fs from 'fs';
import pg from 'pg';

const { Client } = pg;

const PROJECT_REF = 'pljxviezoilirlsoavto';
const DB_PASS = process.env.SUPABASE_DB_PASSWORD;
if (!DB_PASS) {
  console.warn('⚠️ SUPABASE_DB_PASSWORD ortam değişkeni ayarlanmadı. Migration için gereklidir.');
}
const POOLER_HOST = 'aws-0-ap-northeast-2.pooler.supabase.com';

const schemaSql = fs.readFileSync('./supabase/schema.sql', 'utf8');
const phase2Sql = fs.readFileSync('./supabase/phase2_migration.sql', 'utf8');
const phase3Sql = fs.readFileSync('./supabase/phase3_migration.sql', 'utf8');
const phase4Sql = fs.readFileSync('./supabase/phase4_migration.sql', 'utf8');
const phase5Sql = fs.readFileSync('./supabase/phase5_migration.sql', 'utf8');

const enumAdditions = [
  "ALTER TYPE student_state ADD VALUE IF NOT EXISTS 'COMPUTER_STUDY';",
  "ALTER TYPE student_state ADD VALUE IF NOT EXISTS 'GUEST_MODE';",
  "ALTER TYPE student_state ADD VALUE IF NOT EXISTS 'FROZEN_HOLIDAY';",
  "ALTER TYPE student_state ADD VALUE IF NOT EXISTS 'CO_STUDY_MODE';",
  "ALTER TYPE task_verification_type ADD VALUE IF NOT EXISTS 'qr_scan';",
  "ALTER TYPE task_submission_method ADD VALUE IF NOT EXISTS 'qr_scanned';",
  "ALTER TYPE reward_tier ADD VALUE IF NOT EXISTS 'parent_challenge';",
  "ALTER TYPE shield_violation_type ADD VALUE IF NOT EXISTS 'unauthorized_app_opened';",
  "ALTER TYPE shield_violation_type ADD VALUE IF NOT EXISTS 'clock_tamper_attempt';",
  "ALTER TYPE shield_violation_type ADD VALUE IF NOT EXISTS 'high_noise_detected';",
  "ALTER TYPE shield_violation_type ADD VALUE IF NOT EXISTS 'watchdog_agent_restarted';",
];

async function run() {
  const client = new Client({
    connectionString: `postgresql://postgres.${PROJECT_REF}:${DB_PASS}@${POOLER_HOST}:5432/postgres`,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 15000,
  });

  await client.connect();
  console.log(`Bağlandı (${POOLER_HOST})! 1) Ana SQL Şeması kontrol ediliyor...`);
  await client.query(schemaSql);

  console.log('2) Faz 2 + Faz 3 ENUM değerleri ekleniyor...');
  for (const stmt of enumAdditions) {
    await client.query(stmt);
  }

  console.log('3) Faz 2 Tablo, Sütun ve RPC Fonksiyonları uygulanıyor...');
  await client.query(phase2Sql);

  console.log('4) Faz 3 Tablo, Sütun ve RPC Fonksiyonları uygulanıyor...');
  await client.query(phase3Sql);

  console.log('5) Faz 4 Tablo, Sütun ve RPC Fonksiyonları uygulanıyor...');
  await client.query(phase4Sql);

  console.log('6) Faz 5 Tablo, Sütun ve RPC Fonksiyonları uygulanıyor...');
  await client.query(phase5Sql);

  console.log('✅ Faz 1 + Faz 2 + Faz 3 + Faz 4 SQL Şeması ve RPC fonksiyonları başarıyla canlı Supabase veritabanına uygulandı!');
  await client.end();
}

run().catch((err) => {
  console.error('Migration hatası:', err.message);
  process.exit(1);
});
