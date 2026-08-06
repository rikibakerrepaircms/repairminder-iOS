#!/usr/bin/env node
/**
 * Replace personal data in a captured API payload, keeping everything the
 * decode tests actually read: structure, key names, enum values, counts.
 *
 * Usage: node scripts/scrub-fixture.mjs < raw.json > Fixtures/tickets.json
 *
 * TWO PASSES OVER THE INPUT, ONE WRITE. Pass 1 reads the raw payload and
 * decides a fake for every real personal string. Pass 2 reads the raw payload
 * again and emits the output. Nothing is ever re-processed.
 *
 * That structure is not decoration. An earlier version scrubbed keyed values
 * and then ran an embedded-text pass over its OWN output, so a fake could be
 * matched and rewritten a second time - producing "Robin ArcherFrost" out of
 * two perfectly good synthetic names. Substitutions must not compound.
 *
 * Determinism: the same input id always yields the same fake, so a refreshed
 * capture produces a readable diff rather than noise on every row.
 *
 * @example.invalid is reserved by RFC 2606 and can never be a real domain.
 * 07700900000 is Ofcom's reserved drama range. FixturePrivacyTests asserts
 * every email and number in the output is one of those.
 */
const FIRST = ['Alex', 'Sam', 'Jo', 'Robin', 'Chris', 'Morgan', 'Casey', 'Riley'];
const LAST = ['Archer', 'Brook', 'Chase', 'Dale', 'Ellis', 'Frost', 'Gale', 'Hart'];

function hash(s) {
  let h = 0;
  for (const ch of String(s)) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return h;
}
// Unsigned shift throughout: a signed `>>` on a value ToInt32'd negative would
// index LAST[] with a negative number and yield `undefined`.
const fakeFirst = (seed) => FIRST[hash(seed) % FIRST.length];
const fakeLast = (seed) => LAST[(hash(seed) >>> 3) % LAST.length];
const fakeFull = (seed) => `${fakeFirst(seed)} ${fakeLast(seed)}`;

// SUFFIX-matched, not exact-matched. An anchored `^...$` list leaked every real
// customer name in devices.json, because that endpoint uses
// `client_first_name` / `client_last_name` and no alternative happened to spell
// that prefix. Any key ENDING in a personal noun is personal, whatever it is
// prefixed with - client_, contact_, assigned_user_, or a prefix nobody has
// invented yet.
const FIRST_NAME_KEYS = /(^|_)first_?name$/i;
const LAST_NAME_KEYS = /(^|_)last_?name$/i;
const FULL_NAME_KEYS = /(^|_)(name|full_?name|display_?name)$/i;
const EMAIL_KEYS = /(^|_)(email|email_?address)$/i;
const PHONE_KEYS = /(^|_)(phone|mobile|telephone|phone_?number)$/i;
const ADDRESS_KEYS = /(^|_)(address_?line_?1|address_?line_?2|address|street|city|town|county|postcode|post_?code|zip)$/i;

// A bare `name` / `display_name` is ALSO used for catalogue data the decode
// tests need byte-identical: location names, device-type labels
// ("Repair"/"Buyback"), workflow labels, device display names ("Apple iPhone
// 11"). Those sit under one of these parents; only there is a bare name left
// alone. Everywhere else a bare name is a real person.
const CATALOG_NAME_PARENTS = /^(location|locations|company_locations|device_type|device_types|group|groups|ticket_type|ticket_types|status|statuses|payment_status|payment_statuses|sub_location|data|devices)$/i;

// Keys ending in `name` that name a THING, not a person. Checked before any
// personal match, because a denylist of nouns is far more reliable than the
// parent-key whitelist below: `notes[].device_name` held "Apple iPhone 15 Pro
// Max" and was rewritten to "Morgan Hart" purely because its parent happened
// not to be on the whitelist.
const NON_PERSONAL_NAME_KEYS = /(^|_)(device_name|model_name|brand_name|product_name|location_name|company_name|workflow_name|type_name|status_name|group_name|category_name|service_name|repair_name|item_name|file_name|template_name|tag_name)$/i;

// People, referenced by what they did rather than by a name field.
const ACTOR_KEYS = /(^|_)(created_by|updated_by|assigned_to|closed_by|approved_by|cancelled_by|actioned_by|technician|engineer)$/i;

function personalKind(key, parentKey) {
  if (NON_PERSONAL_NAME_KEYS.test(key)) return null;
  if (FIRST_NAME_KEYS.test(key)) return 'first';
  if (LAST_NAME_KEYS.test(key)) return 'last';
  if (ACTOR_KEYS.test(key)) return 'full';
  if (FULL_NAME_KEYS.test(key)) {
    return CATALOG_NAME_PARENTS.test(parentKey) ? null : 'full';
  }
  if (EMAIL_KEYS.test(key)) return 'email';
  if (PHONE_KEYS.test(key)) return 'phone';
  if (ADDRESS_KEYS.test(key)) return 'address';
  return null;
}

// Words that appear inside placeholder "names" this system generates -
// "Guest Customer", "Unknown Buyer", "Test Account". Recording one of these as
// a person rewrites it everywhere it appears as an ordinary word: the literal
// label "Customer:" in every note body became "Hart:" because one walk-in row
// was named "Guest Customer". A placeholder identifies nobody, so it is not
// personal data and must never enter the map.
const NOT_A_REAL_NAME = new Set([
  'customer', 'guest', 'unknown', 'test', 'admin', 'account', 'buyer', 'seller',
  'client', 'user', 'staff', 'engineer', 'technician', 'walk', 'walkin',
  'anonymous', 'none', 'null', 'system', 'api', 'default', 'sample', 'demo',
]);

/** real string -> fake string, for text that mentions a person in prose. */
const nameMap = new Map();
function record(real, fake) {
  const r = typeof real === 'string' ? real.trim() : '';
  // Three characters is the floor: shorter tokens are initials and ordinary
  // words, and replacing those would corrupt prose rather than protect anyone.
  if (r.length < 3 || nameMap.has(r)) return;
  // A single token that is a placeholder word, or that is not capitalised, is
  // not a person. Multi-word strings are kept even if one part is a
  // placeholder, because "Guest Customer" as a whole is still worth replacing
  // - it is only its PARTS that must not be recorded separately.
  if (!r.includes(' ')) {
    if (NOT_A_REAL_NAME.has(r.toLowerCase())) return;
    if (r[0] !== r[0].toUpperCase()) return;
  }
  nameMap.set(r, fake);
}

// ---------- pass 1: decide every replacement, from the RAW input ----------

function collect(node, seed, parentKey) {
  if (Array.isArray(node)) return node.forEach((v, i) => collect(v, `${seed}.${i}`, parentKey));
  if (!node || typeof node !== 'object') return;

  const rowSeed = node.id ?? seed;

  // A person's parts, so prose mentioning either half is covered. The generated
  // templates are not consistent: orders.json writes "Good Morning First Last,"
  // and tickets.json writes "Good Morning First ,", so mapping only the
  // concatenation left every bare first name in the fixture.
  for (const prefix of ['', 'client_', 'contact_', 'assigned_user_']) {
    const f = node[`${prefix}first_name`];
    const l = node[`${prefix}last_name`];
    if (typeof f === 'string' && typeof l === 'string') {
      record(`${f} ${l}`, fakeFull(rowSeed));
      record(`${f.trim()} ${l.trim()}`, fakeFull(rowSeed));
    }
    if (typeof f === 'string') record(f, fakeFirst(rowSeed));
    if (typeof l === 'string') record(l, fakeLast(rowSeed));
  }

  for (const [k, v] of Object.entries(node)) {
    if (typeof v === 'string') {
      const kind = personalKind(k, parentKey);
      if (kind === 'full') {
        record(v, fakeFull(rowSeed));
        // Some endpoints only give a combined `name`, and their prose uses the
        // first name alone. Map each part to the matching part of the fake.
        const parts = v.trim().split(/\s+/);
        if (parts.length > 1) {
          record(parts[0], fakeFirst(rowSeed));
          record(parts[parts.length - 1], fakeLast(rowSeed));
        }
      } else if (kind === 'email') {
        record(v, `${fakeFull(rowSeed).toLowerCase().replace(' ', '.')}@example.invalid`);
      }
    }
    collect(v, `${rowSeed}.${k}`, k);
  }
}

// ---------- pass 2: emit, from the RAW input, replacing once ----------

/**
 * Last line of defence for free text: redact anything SHAPED like an email or
 * a UK phone number, wherever it appears, under whatever key.
 *
 * The name map only covers people the key pass met. A note body reading
 * "chased on 07969741650, emailed stuart@example.net" holds a real mobile and
 * a real address belonging to nobody in this payload's client records, so the
 * map never sees them. Defend by shape, not by a list you remembered.
 */
function redactByShape(s) {
  return redactPostcodes(s)
    .replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, 'redacted@example.invalid')
    // Bounded on BOTH sides by a non-digit: a greedier version ate two 12-digit
    // device serial numbers that happened to start with a zero.
    .replace(/(?<!\d)(\+44\s?\d{10}|0\d{10})(?!\d)/g, '07700900000');
}

/**
 * Every device model named anywhere in this payload, so a postcode-shaped
 * token that is really a product name is left alone.
 *
 * This is not hypothetical: "S20FE" is a Samsung Galaxy S20 FE and parses
 * perfectly as the postcode S2 0FE. A regex alone cannot tell them apart, so
 * the document's own catalogue decides - if the token is a device name
 * somewhere, it is a device name everywhere.
 */

/** Keys whose value names a THING - a device, a model, a location, a status. */
function isThingNameKey(k) {
  return NON_PERSONAL_NAME_KEYS.test(k) || /^(display_name|name)$/i.test(k);
}

const deviceWords = new Set();
function collectDeviceWords(node) {
  if (Array.isArray(node)) return node.forEach(collectDeviceWords);
  if (!node || typeof node !== 'object') return;
  for (const [k, v] of Object.entries(node)) {
    // Every key that names a THING: the explicit device/model keys, and the
    // bare `name`/`display_name` that sit under a catalogue parent. Missing
    // the second group rewrote "Galaxy S20FE" to "Galaxy AA1 1AA", because
    // S20FE parses as the postcode S2 0FE and nothing said it was a product.
    if (typeof v === 'string' && isThingNameKey(k)) {
      v.split(/[\s,()]+/).forEach((w) => w && deviceWords.add(w.toUpperCase()));
    }
    collectDeviceWords(v);
  }
}

/**
 * A postcode identifies a household, so it is personal data even without a
 * name beside it - and ours were sitting in free-text note bodies, reachable
 * by neither the key pass nor the name map, exactly like the emails and phone
 * numbers before them.
 */
function redactPostcodes(s) {
  return s.replace(/\b[A-Z]{1,2}[0-9][0-9A-Z]? ?[0-9][A-Z]{2}\b/g, (m) =>
    deviceWords.has(m.replace(/\s+/g, '').toUpperCase()) ? m : 'AA1 1AA');
}

/** Longest real string first, so a full name is consumed before its parts. */
let sortedNames = [];
function redactProse(s) {
  let out = s;
  for (const [real, fake] of sortedNames) {
    if (real.includes(' ')) {
      if (out.includes(real)) out = out.split(real).join(fake);
    } else {
      // Single token: WORD-BOUNDED, or a short real first name like "Will"
      // would rewrite ordinary prose ("Will call back") and corrupt the fixture.
      const re = new RegExp(`\\b${real.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'g');
      out = out.replace(re, fake);
    }
  }
  return redactByShape(out);
}

function emit(node, seed, parentKey) {
  if (Array.isArray(node)) return node.map((v, i) => emit(v, `${seed}.${i}`, parentKey));
  if (node && typeof node === 'object') {
    const out = {};
    const rowSeed = node.id ?? seed;
    for (const [k, v] of Object.entries(node)) {
      if (v === null) { out[k] = null; continue; }
      if (typeof v === 'string') {
        const kind = personalKind(k, parentKey);
        // A keyed personal value is REPLACED, never also prose-redacted - that
        // double handling is what produced "Robin ArcherFrost".
        if (kind === 'first') { out[k] = fakeFirst(rowSeed); continue; }
        if (kind === 'last') { out[k] = fakeLast(rowSeed); continue; }
        if (kind === 'full') { out[k] = fakeFull(rowSeed); continue; }
        if (kind === 'email') { out[k] = `${fakeFull(rowSeed).toLowerCase().replace(' ', '.')}@example.invalid`; continue; }
        if (kind === 'phone') { out[k] = '07700900000'; continue; }
        if (kind === 'address') { out[k] = 'Redacted'; continue; }
        // A catalogue name is a THING and never mentions a person, so it does
        // not go through the name map at all. It must not: a customer surnamed
        // Gray put "Gray" in the map, and "Space Gray" became "Space Dale".
        if (isThingNameKey(k)) { out[k] = v; continue; }
        out[k] = redactProse(v);
        continue;
      }
      out[k] = emit(v, `${rowSeed}.${k}`, k);
    }
    return out;
  }
  if (typeof node === 'string') return redactProse(node);
  return node;
}

const raw = JSON.parse(await new Response(process.stdin).text());
collectDeviceWords(raw);
collect(raw, 'root', 'root');
sortedNames = [...nameMap.entries()].sort((a, b) => b[0].length - a[0].length);
process.stdout.write(JSON.stringify(emit(raw, 'root', 'root'), null, 2) + '\n');
