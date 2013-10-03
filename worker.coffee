state = () ->
  'queue': []
  'paused': null
  'job': null
  'arrivals':
    'count': 0
    'total': 0
  'queue_times':
    'count': 0
    'total': 0
  'system_times':
    'count': 0
    'total': 0

rand = (rate) ->
  r = Math.log(1-Math.random())/(-1 * rate)
  return r

sleeptime = (rate) ->
  t = rand(rate) * 1000
  t

avg = (hash) ->
  hash['total']/hash['count']

incr = (hash,t) ->
  hash['count'] += 1
  hash['total'] += t

assigner = (rate,state,cb) ->
  myassigner = () ->
    state['queue'].push {'queued': new Date()}
    cb(state)
    t = sleeptime(rate)
    incr(state['arrivals'],t)
    setTimeout(myassigner,t)
  myassigner()

dur = (start,end) ->
  (end - start) / 1000

worker = (processing_rate,state,observer) ->
  job = null
  myworker = () ->
    if job?
      job['done'] = new Date()
      incr(state['system_times'],dur(job['queued'],job['done']))
      observer 'finished', state, job
      job = null
    if state['queue'].length > 0
      state['paused'] = null
      job = state['queue'].shift()
      job['started'] = new Date()
      incr(state['queue_times'],dur(job['queued'],job['started']))
      t = sleeptime(processing_rate)
      observer('started',state,job)
    else
      observer('idle',state,job) unless state['paused']?
      state['paused'] = 1
      t = 0
    setTimeout(myworker,t)
  myworker()

start_time = new Date()
worker1 = state()
worker2 = state()
capacity_utilization = .9
processing_rate = 1
arrival_rate = processing_rate * capacity_utilization

now = () ->
  runtime = new Date() - start_time
  d = new Date()
  d.setSeconds(d.getSeconds() + ((runtime / 1000) * 60 * 60 * 24))
  d

dateformat = (d) ->
  "#{d.toLocaleDateString()} #{d.toLocaleTimeString()}"

system_time = (job) ->
  dur(job['queued'],job['done'])

process_time = (job) ->
  dur(job['started'],job['done'])

queue_time = (job) ->
  dur(job['queued'],job['started'])

queue_pct = (job) ->
  (queue_time(job) / system_time(job)) * 100

finished = (state) ->
  state['system_times']['count']

avg_queue_pct = (state) ->
  avg_queue_time(state) / avg_system_time(state) * 100

avg_queue_time = (state) ->
  avg(state['queue_times'])

avg_system_time = (state) ->
  avg(state['system_times'])

avg_arrival_rate = (state) ->
  1/(avg(state['arrivals'])/1000)

avg_system_size = (state) ->
  # Little's law: avg jobs in system = avg arrival rate * avg time in system
  avg_arrival_rate(state) * avg_system_time(state)

log = (msg,color='white') ->
  console.log "#{dateformat now()}: #{msg}"

assigner(arrival_rate,worker1,(state) -> log "Do this one day job! Your queue is now #{state['queue'].length} deep.", 'red')

worker(processing_rate,worker1,
  (event,state,job) ->
    switch event
      when 'started'
        log "Picking up a new job, and I have #{state['queue'].length} left in the queue!"
        log "Average lead time:      #{avg_system_time(state).toFixed(1)} days."
        log "Average jobs in system: #{avg_system_size(state).toFixed(1)}."
        log "Average pct queue time: #{avg_queue_pct(state).toFixed(1)}%."
      when 'finished'
        log "Finished job number #{finished(state)}! That job took #{process_time(job)} days! It's been in the system for #{system_time(job)} days, though. That's #{queue_pct(job).toFixed(0)}% queue time."
      when 'idle'
        log "Nothing for me to do... guess I'll take a nap."
)

