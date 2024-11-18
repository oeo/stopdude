# stopdude

Another Redis rate limiter.

## Features

- Supports minute, hour, day, week, and month-based rate limiting.
- Built on top of Redis for high performance and scalability.

## Install

To include StopDude in your project, run:

```bash
npm install stopdude --save
```

## Usage

Here's a basic example of how to use StopDude:

```javascript
const StopDude = require('stopdude');

// Initialize with custom options if needed
const options = {
  redis: yourRedisClient, // Pass in a configured Redis client
  prefix: 'yourPrefix',   // Optional: to namespace your keys in Redis
};

const rateLimiter = new StopDude(options);

// Example of creating a rate-limiting rule
rateLimiter.create({ key: 'api_user_123', max: 100, time: 'hour' })
  .then(() => {
    console.log('Rule created successfully');
  })
  .catch(err => {
    console.error('Error creating rule:', err);
  });
```

## API

### `create(options)`

- Description: Creates a new rate-limiting rule.
- Parameters:
  - `options`: Object containing `key`, `max`, and `time`.
  - `key`: String, the unique identifier for the rule.
  - `max`: Number, the maximum number of allowed requests in the specified time.
  - `time`: String, one of ['minute', 'hour', 'day', 'week', 'month'].
- Returns: Promise that resolves with the created rule details.

### `find(key)`

- Description: Finds an existing rate limit rule by key.
- Parameters:
  - `key`: String, the unique identifier for the rule.
- Returns: Promise that resolves with the rule details or `false` if not found.

### `update(key, properties)`

- Description: Updates an existing rate limit rule.
- Parameters:
  - `key`: String, the rule key to update.
  - `properties`: Object containing properties to update (`max`, `time`).
- Returns: Promise that resolves with `true` if update was successful.

### `incr(key, amount)`

- Description: Increments the counter for the specified rule key.
- Parameters:
  - `key`: String, the rule key to increment.
  - `amount`: Number, the amount to increase by (default 1).
- Returns: Promise that resolves with `true` if the increment was successful.

### `stats(key)`

- Description: Retrieves usage statistics for a rule.
- Parameters:
  - `key`: String, the rule key to retrieve stats for.
- Returns: Promise that resolves with an object containing usage stats such as `counters`, `allowed`, and `percent` utilization.

### `remove(key)`

- Description: Removes a rate-limiting rule completely.
- Parameters:
  - `key`: String, the rule key to remove.
- Returns: Promise that resolves with `true` if the rule was successfully removed.

## Development

- `yarn`: Install project dependencies.
- `yarn test`: Run the test suite to ensure all functionality works as expected.
- `yarn build`: Compile CoffeeScript source code to JavaScript for distribution.

```
  StopDude
    create
      ✔ should create a new rule
      ✔ should throw an error for invalid time segment
    find
      ✔ should find an existing rule
      ✔ should return false for non-existent rule
    update
      ✔ should update an existing rule
    incr
      ✔ should increment the counter
    clear
      ✔ should clear the counters
    remove
      ✔ should remove a rule
    stats
      ✔ should return stats for a rule
      ✔ should return not allowed when max is reached
    generateUUID
      ✔ should generate a valid UUID
    getExpires
      ✔ should return a future timestamp for each time segment
      ✔ should throw an error for invalid time segment
    secsToTime
      ✔ should convert a string to seconds
    getTime
      ✔ should return current unix timestamp
    getMinute
      ✔ should return the start of the current minute
    getHour
      ✔ should return the start of the current hour
    getType
      ✔ should return the type of an object


  18 passing (19ms)

Done in 0.34s.
```
