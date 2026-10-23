const test = require('node:test');
const assert = require('node:assert/strict');
const {requestedDateKey, dayBounds, enumerateDays} = require('../src/amenity_booking');

test('Manila phone date is preserved when the community is in Bengaluru', () => {
  const midnightInPhilippines = Date.parse('2035-11-14T16:00:00Z');
  const key = requestedDateKey(midnightInPhilippines, 'Asia/Calcutta', 480);
  assert.equal(key, '2035-11-15');
  const day = dayBounds(midnightInPhilippines, 'Asia/Calcutta', 480);
  assert.equal(day.key, '2035-11-15');
  assert.equal(day.startMs, Date.parse('2035-11-14T18:30:00Z'));
  assert.equal(day.endMs, Date.parse('2035-11-15T18:30:00Z') - 1);
  assert.deepEqual(enumerateDays(midnightInPhilippines, midnightInPhilippines, 'Asia/Calcutta', 480).map(d => d.key), ['2035-11-15']);
});

test('Older clients without an offset keep community-instant semantics', () => {
  const midnightInPhilippines = Date.parse('2035-11-14T16:00:00Z');
  assert.equal(requestedDateKey(midnightInPhilippines, 'Asia/Calcutta'), '2035-11-14');
});

test('Device-local month range ending after a DST shift includes final day', () => {
  // US West Coast midnight goes from UTC-8 to UTC-7 during March.
  const start = Date.parse('2035-03-01T08:00:00Z');
  const end = Date.parse('2035-03-31T07:00:00Z');
  const days = enumerateDays(start, end, 'Asia/Calcutta', -480);
  assert.equal(days.length, 31);
  assert.equal(days[0].key, '2035-03-01');
  assert.equal(days.at(-1).key, '2035-03-31');
});

test('Different phone offsets select the same community civil date', () => {
  for (const [timestamp, offset] of [
    ['2035-11-15T08:00:00Z', -480],
    ['2035-11-15T00:00:00Z', 0],
    ['2035-11-14T18:30:00Z', 330],
    ['2035-11-14T16:00:00Z', 480],
  ]) {
    assert.equal(requestedDateKey(Date.parse(timestamp), 'Asia/Calcutta', offset), '2035-11-15');
  }
});
