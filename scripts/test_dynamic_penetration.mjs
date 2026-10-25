/**
 * ==============================================================================
 * test_dynamic_penetration.mjs - DİNAMİK PENETRASYON VE RPC ENTEGRASYON TESTİ
 * ==============================================================================
 * Kapsam:
 * 1. Atomik Yarış Görevi (Race Condition & Concurrency Test):
 *    - İki kardeşin aynı anda (eşzamanlı) "claim_race_task_atomic" çağırması.
 *    - Yalnızca bir kardeşin görevi kazanması, diğerinin güvenle reddedilmesi.
 * 2. Kalkan ve İhlal Sınır Testi (Negative Shield Penetration):
 *    - 3 kalkanın 0'ın altına düşemeyeceğinin ve "watchdog_agent_restarted" kaydının doğrulanması.
 * 3. Günlük Görev Üretimi (Idempotence & Anti-Duplicate Test):
 *    - "spawn_daily_recurring_tasks" peş peşe çağrıldığında mükerrer görev açmaması.
 * 4. PIN Hash ve Güvenlik Bütünlüğü:
 *    - "family_settings" tablosundaki SHA-256 hash uzunluğu (64 karakter) ve veri bütünlüğü.
 * ==============================================================================
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://pljxviezoilirlsoavto.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SECRET_KEY || 'sb_secret_C9nDCCofpDqlVy98N1m4bQ_i69iXgyU';

class MockWebSocket {
  constructor() {}
  on() {}
  send() {}
  close() {}
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { persistSession: false },
  realtime: {
    transport: MockWebSocket,
  },
});

let passedCount = 0;
let failedCount = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✅ [PASS] ${message}`);
    passedCount++;
  } else {
    console.error(`  ❌ [FAIL] ${message}`);
    failedCount++;
  }
}

async function runPenetrationSuite() {
  console.log('==================================================================');
  console.log(' 🛡️  FAMILY-TO-STUDY CANLI DİNAMİK PENETRASYON VE RPC TESTLERİ');
  console.log(` 🌐  Hedef Supabase: ${SUPABASE_URL}`);
  console.log('==================================================================\n');

  const testFamilyId = 'fam-ozdemir';
  const testStudent1 = 'child-omer';
  const testStudent2 = 'child-ali';

  // ----------------------------------------------------------------------------
  // 1. PIN Hash & Family Settings Bütünlük Testi
  // ----------------------------------------------------------------------------
  console.log('TEST 1: Family Settings & Offline Master PIN Hash Güvenliği');
  const { data: fsData, error: fsError } = await supabase
    .from('family_settings')
    .select('*')
    .eq('family_id', testFamilyId)
    .single();

  assert(!fsError && fsData, 'family_settings tablosu başarıyla okundu');
  assert(
    typeof fsData.offline_master_pin_hash === 'string' &&
    fsData.offline_master_pin_hash.length === 64,
    `offline_master_pin_hash geçerli 64 karakterli SHA-256 özeti (${fsData?.offline_master_pin_hash?.substring(0, 16)}...)`
  );
  assert(
    typeof fsData.latest_agent_version === 'string',
    `latest_agent_version tanımlı (${fsData.latest_agent_version})`
  );

  // ----------------------------------------------------------------------------
  // 2. Concurrency & Race Condition Test (claim_race_task_atomic)
  // ----------------------------------------------------------------------------
  console.log('\nTEST 2: Eşzamanlı Yarış Görevi Kapma (Race Condition Penetrasyon Testi)');
  const raceTaskId = `test-race-${Date.now()}`;
  
  // Test için sahipsiz bir yarış görevi oluştur
  const { error: insertTaskErr } = await supabase.from('tasks').insert({
    id: raceTaskId,
    family_id: testFamilyId,
    assigned_to: 'both',
    title: '⚡ Penetrasyon Testi: İlk Kapar Görevi',
    category: 'flash_quest',
    points: 50,
    is_active: true,
    is_first_come_race: true,
    claimed_by: null,
  });
  assert(!insertTaskErr, 'Test için sahipsiz ilk kapar görevi oluşturuldu');

  // İki öğrenci tam olarak aynı anda RPC'yi çağırır
  const [res1, res2] = await Promise.all([
    supabase.rpc('claim_race_task_atomic', { p_task_id: raceTaskId, p_user_id: testStudent1 }),
    supabase.rpc('claim_race_task_atomic', { p_task_id: raceTaskId, p_user_id: testStudent2 }),
  ]);

  const win1 = res1.data?.success === true;
  const win2 = res2.data?.success === true;

  assert(
    (win1 && !win2) || (!win1 && win2),
    `Atomik Yarış Koşulu Korundu: Yalnızca BİR öğrenci kazandı (Ömer: ${win1}, Ali: ${win2})`
  );

  // Görevin veritabanında gerçekten tek bir öğrenciye bağlandığını doğrula
  const { data: verifiedTask } = await supabase
    .from('tasks')
    .select('claimed_by')
    .eq('id', raceTaskId)
    .single();
  assert(
    verifiedTask?.claimed_by === testStudent1 || verifiedTask?.claimed_by === testStudent2,
    `Görev veritabanında atomik kilitlendi: claimed_by = ${verifiedTask?.claimed_by}`
  );

  // Temizlik
  await supabase.from('tasks').delete().eq('id', raceTaskId);

  // ----------------------------------------------------------------------------
  // 3. Kalkan İhlal & Negatif Kalkan Sınır Testi (record_violation_and_break_shield)
  // ----------------------------------------------------------------------------
  console.log('\nTEST 3: Kalkan Kırma ve Negatif Kalkan Açığı (Negative Shield Penetrasyon Testi)');
  
  // Ömer'in kalkanını 3'e resetle
  await supabase.from('users').update({ daily_shields: 3 }).eq('id', testStudent1);

  // 1 ihlal yaz: watchdog_agent_restarted
  const { data: v1 } = await supabase.rpc('record_violation_and_break_shield', {
    p_user_id: testStudent1,
    p_device_id: 'dev-omer-pc',
    p_violation_type: 'watchdog_agent_restarted',
  });
  assert(v1?.remaining_shields === 2, `1. İhlal (watchdog_agent_restarted): Kalkan 3 -> 2'ye düştü`);

  // Kalkanları 0'a zorla ve bir kez daha ihlal yaz
  await supabase.from('users').update({ daily_shields: 0 }).eq('id', testStudent1);
  const { data: vZero } = await supabase.rpc('record_violation_and_break_shield', {
    p_user_id: testStudent1,
    p_device_id: 'dev-omer-pc',
    p_violation_type: 'pc_mouse_move',
  });
  assert(
    vZero?.remaining_shields === 0,
    `Kalkan 0 iken ihlal yazıldığında negatif değere (-1) düşmedi (Penetrasyon Koruması: ${vZero?.remaining_shields})`
  );

  // ----------------------------------------------------------------------------
  // 4. Günlük Görev Üretimi Idempotence Testi (spawn_daily_recurring_tasks)
  // ----------------------------------------------------------------------------
  console.log('\nTEST 4: Günlük Görev Üretimi (Idempotence & Anti-Duplicate Testi)');
  
  // 1. Çağrı
  const { data: spawn1, error: spErr1 } = await supabase.rpc('spawn_daily_recurring_tasks', {
    p_family_id: testFamilyId,
  });
  assert(!spErr1 && spawn1?.success === true, '1. spawn_daily_recurring_tasks çağrısı başarılı');

  // Kalkanların 3'e geri geldiğini doğrula
  const { data: uAfterSpawn } = await supabase
    .from('users')
    .select('daily_shields')
    .eq('id', testStudent1)
    .single();
  assert(uAfterSpawn?.daily_shields === 3, 'spawn_daily_recurring_tasks sonrası günlük kalkanlar 3 olarak yenilendi');

  // Hemen ardından 2. Çağrı (Mükerrer görev açmamalı)
  const { data: spawn2, error: spErr2 } = await supabase.rpc('spawn_daily_recurring_tasks', {
    p_family_id: testFamilyId,
  });
  assert(!spErr2 && spawn2?.success === true, '2. spawn_daily_recurring_tasks çağrısı başarılı');
  assert(
    spawn2?.tasks_created === 0,
    `Mükerrer görev açılmadı: tasks_created = ${spawn2?.tasks_created} (Anti-Spam Idempotent)`
  );

  // ----------------------------------------------------------------------------
  // Özet
  // ----------------------------------------------------------------------------
  console.log('\n==================================================================');
  console.log(` 🎯 DİNAMİK PENETRASYON VE TEST SONUCU: ${passedCount} Başarılı, ${failedCount} Hatalı`);
  console.log('==================================================================');

  if (failedCount > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runPenetrationSuite().catch((err) => {
  console.error('Test süreci beklenmedik hata ile sonlandı:', err);
  process.exit(1);
});
