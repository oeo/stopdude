const assert = require('assert');
const sinon = require('sinon');
const Redis = require('ioredis-mock');
const StopDude = require('./module');

describe('StopDude', function() {
  let redis;
  let throttle;
  let uniqueKey;

  beforeEach(function() {
    redis = new Redis();
    throttle = new StopDude({ redis: redis });

    // Use a unique key for each test
    uniqueKey = `test_${Date.now()}_${Math.random()}`;
  });

  afterEach(async function() {
    // Cleanup any potential data in Redis related to uniqueKey
    const id = await throttle.findId(uniqueKey);
    if (id) {
      const baseKey = [throttle.prefix, 'counters', id];
      const allDeletePromises = throttle.timeSegments.map(timeStr => {
        return redis.del(baseKey.concat([timeStr]).join(':'));
      });

      await Promise.all(allDeletePromises);
      await throttle.remove(uniqueKey); // Ensure rule is removed
    }
  });

  describe('create', function() {
    it('should create a new rule', async function() {
      const rule = await throttle.create({ key: uniqueKey, max: 10, time: 'minute' });
      assert(typeof rule === 'object');
      assert.strictEqual(rule.key, uniqueKey);
      assert.strictEqual(rule.max, 10);
      assert.strictEqual(rule.time, 'minute');
    });

    it('should throw an error for invalid time segment', async function() {
      await assert.rejects(() => throttle.create({ key: uniqueKey, max: 10, time: 'invalid' }), Error);
    });
  });

  describe('find', function() {
    it('should find an existing rule', async function() {
      await throttle.create({ key: uniqueKey, max: 10, time: 'minute' });
      const rule = await throttle.find(uniqueKey);
      assert(typeof rule === 'object');
      assert.strictEqual(rule.key, uniqueKey);
    });

    it('should return false for non-existent rule', async function() {
      const result = await throttle.find('nonexistent');
      assert.strictEqual(result, false);
    });
  });

  describe('update', function() {
    it('should update an existing rule', async function() {
      await throttle.create({ key: uniqueKey, max: 10, time: 'minute' });
      const result = await throttle.update(uniqueKey, { max: 20 });
      assert.strictEqual(result, true);
      const updatedRule = await throttle.find(uniqueKey);
      assert.strictEqual(updatedRule.max, 20);
    });
  });

  describe('incr', function() {
    it('should increment the counter', async function() {
      await throttle.create({ key: uniqueKey, max: 10, time: 'minute' });
      const result = await throttle.incr(uniqueKey);
      assert.strictEqual(result, true);
      const stats = await throttle.stats(uniqueKey);
      assert.strictEqual(stats.counters.minute, 1);
    });
  });

  describe('clear', function() {
    it('should clear the counters', async function() {
      await throttle.create({ key: uniqueKey, max: 10, time: 'minute' });
      await throttle.incr(uniqueKey);
      const result = await throttle.clear(uniqueKey);
      assert.strictEqual(result, true);
      const stats = await throttle.stats(uniqueKey);
      assert.strictEqual(stats.counters.minute, 0);
    });
  });

  describe('remove', function() {
    it('should remove a rule', async function() {
      await throttle.create({ key: uniqueKey, max: 10, time: 'minute' });
      const result = await throttle.remove(uniqueKey);
      assert.strictEqual(result, true);
      const findResult = await throttle.find(uniqueKey);
      assert.strictEqual(findResult, false);
    });
  });

  describe('stats', function() {
    it('should return stats for a rule', async function() {
      await throttle.create({ key: uniqueKey, max: 10, time: 'minute' });
      await throttle.incr(uniqueKey);
      const stats = await throttle.stats(uniqueKey);
      assert(typeof stats === 'object');
      assert.strictEqual(stats.counters.minute, 1);
      assert.strictEqual(stats.allowed, true);
      assert.strictEqual(parseFloat(stats.percent), 10);
    });

    it('should return not allowed when max is reached', async function() {
      await throttle.create({ key: uniqueKey, max: 2, time: 'minute' });
      await throttle.incr(uniqueKey);
      await throttle.incr(uniqueKey);
      const stats = await throttle.stats(uniqueKey);
      assert.strictEqual(stats.allowed, false);
      assert.strictEqual(parseFloat(stats.percent), 100);
    });
  });

  describe('generateUUID', function() {
    it('should generate a valid UUID', function() {
      const uuid = throttle.generateUUID();
      assert(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(uuid));
    });
  });

  describe('getExpires', function() {
    it('should return a future timestamp for each time segment', function() {
      const now = Math.floor(Date.now() / 1000);
      throttle.timeSegments.forEach(segment => {
        const expires = throttle.getExpires(segment);
        assert(expires > now, `Expires for ${segment} should be in the future`);
      });
    });

    it('should throw an error for invalid time segment', function() {
      assert.throws(() => throttle.getExpires('invalid'), Error);
    });
  });

  describe('secsToTime', function() {
    it('should convert a string to seconds', function() {
      const secs = throttle.secsToTime('1 hour');
      assert.strictEqual(secs, 3600);
    });
  });

  describe('getTime', function() {
    it('should return current unix timestamp', function() {
      const time = throttle.getTime();
      assert(Math.abs(time - Math.floor(Date.now() / 1000)) <= 1);
    });
  });

  describe('getMinute', function() {
    it('should return the start of the current minute', function() {
      const minute = throttle.getMinute();
      const now = new Date();
      assert.strictEqual(minute % 60, 0);
      assert(Math.abs(minute - Math.floor(now.getTime() / 1000)) <= 60);
    });
  });

  describe('getHour', function() {
    it('should return the start of the current hour', function() {
      const hour = throttle.getHour();
      const now = new Date();
      assert.strictEqual(hour % 3600, 0);
      assert(Math.abs(hour - Math.floor(now.getTime() / 1000)) <= 3600);
    });
  });

  describe('getType', function() {
    it('should return the type of an object', function() {
      assert.strictEqual(throttle.getType({}), 'object');
      assert.strictEqual(throttle.getType([]), 'array');
      assert.strictEqual(throttle.getType('string'), 'string');
      assert.strictEqual(throttle.getType(123), 'number');
      assert.strictEqual(throttle.getType(null), false);
      assert.strictEqual(throttle.getType(undefined), false);
    });
  });
});

// vim: set ts=2 sw=2 et
