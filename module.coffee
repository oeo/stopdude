# vim: set expandtab tabstop=2 shiftwidth=2 softtabstop=2
require 'date-utils'

_ = require 'lodash'
englishSecs = require 'english-secs'

{ EventEmitter } = require 'events'

module.exports = class Throttle
  timeSegments: [
    'minute'
    'hour'
    'day'
    'week'
    'month'
  ]

  constructor: (opt={}) ->
    opt.prefix ?= 'stopdude'

    @opt = opt
    [@redis, @prefix] = [opt.redis, opt.prefix]

    # Properly set up EventEmitter
    EventEmitter.call(this)
    Object.assign(this, EventEmitter.prototype)

  create: (opt) ->
    for x in ['key', 'max', 'time']
      if !opt[x]
        throw new Error "Option #{x} is required"

    if opt.time not in @timeSegments
      throw new Error "Time segment #{opt.time} was invalid"

    exists = await @find opt.key
    return exists if exists

    uu = @generateUUID()
    dictKey = [@prefix, 'rules', '_dict']
    dictMember = "#{uu}=#{opt.key}"

    await @redis.sadd dictKey.join(':'), dictMember

    ruleHash = [@prefix, 'rules', uu]
    ruleDoc =
      _id: uu
      key: opt.key
      max: opt.max
      time: opt.time
      ctime: @getTime()

    await @redis.hmset ruleHash.join(':'), ruleDoc

    r = await @find opt.key
    @emit 'ruleCreated', r
    r

  find: (key) ->
    id = await @findId key
    return no if !id

    ruleHash = [@prefix, 'rules', id]
    r = await @redis.hgetall ruleHash.join(':')

    for x in ['max', 'ctime']
      try r[x] = parseInt(r[x])

    r

  findId: (key) ->
    dictKey = [@prefix, 'rules', '_dict']
    list = await @redis.smembers dictKey.join(':')

    id = no
    if list.length
      for x in list
        [uu, ruleKey] = x.split '='
        if ruleKey is key
          id = uu
          break

    id

  update: (key, props) ->
    id = await @findId key
    return no if !id

    updateObj = utime: @getTime()

    for k, v of props
      continue if k not in ['time', 'max']

      if k is 'time' and v not in @timeSegments
        throw new Error "Time value #{v} was invalid"

      updateObj[k] = v

    if !_.size(updateObj)
      throw new Error 'Properties provided were invalid'

    ruleHash = [@prefix, 'rules', id]
    await @redis.hmset ruleHash.join(':'), updateObj

    @emit 'ruleUpdated', key
    yes

  incr: (key, amount=1) ->
    id = await @findId key
    return no if !id

    baseKey = [@prefix, 'counters', id]
    statsKeys = {}

    for timeStr in @timeSegments
      statsKeys[timeStr] =
        key: baseKey.concat([timeStr]).join ':'
        expires: @getExpires timeStr
        amount: amount

    for k, v of statsKeys
      exists = await @redis.exists v.key
      await @redis.incrby v.key, amount

      if !exists
        await @redis.expireat v.key, v.expires
        @emit 'counterCreated', v.key

      @emit 'counterIncremented', v.key

    yes

  clear: (key) ->
    id = await @findId key
    return no if !id

    baseKey = [@prefix, 'counters', id]
    m = @redis.multi()

    for timeStr in @timeSegments
      m.del(baseKey.concat([timeStr]).join ':')

    await m.exec()

    @emit 'countersCleared', key
    yes

  remove: (key) ->
    id = await @findId key
    return no if !id

    m = @redis.multi()

    dictKey = [@prefix, 'rules', '_dict']
    dictVal = "#{id}=#{key}"

    m.srem dictKey.join(':'), dictVal

    ruleHash = [@prefix, 'rules', id]
    m.del ruleHash.join(':')

    baseKey = [@prefix, 'counters', id]

    for timeStr in @timeSegments
      m.del(baseKey.concat([timeStr]).join ':')

    await m.exec()

    @emit 'ruleRemoved', key
    yes

  stats: (key) ->
    start = new Date

    rule = await @find key
    return no if !rule

    baseKey = [@prefix, 'counters', rule._id]
    m = @redis.multi()

    for timeStr in @timeSegments
      m.get(baseKey.concat([timeStr]).join ':')

    r = await m.exec()

    counters = _.zipObject @timeSegments, (_.map r, (item) ->
      return 0 if !item[1]
      parseInt item[1]
    )

    response =
      allowed: do ->
        if (counter = counters[rule.time]) and rule.max
          return false if counter >= rule.max
        true
      counters: counters
      percent: do ->
        if (counter = counters[rule.time]) and rule.max
          return (100).toFixed 2 if counter >= rule.max
          return ((counter/rule.max) * 100).toFixed 2 if counter > 0
        (0).toFixed 2
      _meta:
        elapsed: new Date - start
        rule: rule

    response

  getExpires: (timeStr) ->
    now = Math.floor(Date.now() / 1000)
    nextMin = => now + 60
    nextHr = => now + 3600
    nextDay = => now + 86400
    nextWk = => now + 604800
    nextMo = => now + 2592000  # Assuming 30 days in a month

    switch timeStr
      when 'minute' then nextMin()
      when 'hour' then nextHr()
      when 'day' then nextDay()
      when 'week' then nextWk()
      when 'month' then nextMo()
      else
        throw new Error "Time value #{timeStr} was invalid"

  generateUUID: ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
      r = Math.random() * 16 | 0
      v = if c is 'x' then r else (r & 0x3 | 0x8)
      v.toString(16)

  secsToTime: (str) ->
    return englishSecs(str)

  getTime: -> Math.floor(new Date().getTime()/1000)

  getMinute: (unixInput=null) ->
    d = new Date
    d = new Date (unixInput * 1000) if unixInput
    d.setMinutes new Date().getMinutes(), 0, 0
    Math.round(d.getTime()/1000)

  getHour: (unixInput=null) ->
    d = new Date
    d = new Date (unixInput * 1000) if unixInput
    d.setHours new Date().getHours(), 0, 0, 0
    Math.round(d.getTime()/1000)

  getType: (obj) ->
    return false if obj is undefined or obj is null
    Object::toString.call(obj).slice(8, -1).toLowerCase()

# vim: set ts=2 sw=2 et
