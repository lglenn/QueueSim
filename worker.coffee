ANSI_ESC            = String.fromCharCode(0x1B)
ANSI_CSI            = ANSI_ESC + '['
ANSI_TEXT_PROP      = 'm'
ANSI_RESET          = '0'
ANSI_BOLD           = '1'
ANSI_FAINT          = '2'
ANSI_NORMAL         = '22'
ANSI_ITALIC         = '3'
ANSI_UNDER          = '4'
ANSI_UNDER_DBL      = '21'
ANSI_UNDER_OFF      = '24'
ANSI_BLINK          = '5'
ANSI_BLINK_FAST     = '6'
ANSI_BLINK_OFF      = '25'
ANSI_REVERSE        = '7'
ANSI_POSITIVE       = '27'
ANSI_CONCEAL        = '8'
ANSI_REVEAL         = '28'
ANSI_FG             = '3'
ANSI_BG             = '4'
ANSI_FG_INTENSE     = '9'
ANSI_BG_INTENSE     = '10'
ANSI_BLACK          = '0'
ANSI_RED            = '1'
ANSI_GREEN          = '2'
ANSI_YELLOW         = '3'
ANSI_BLUE           = '4'
ANSI_MAGENTA        = '5'
ANSI_CYAN           = '6'
ANSI_WHITE          = '7'

ANSIControlCode = (code, parameters) ->
  if not parameters?
    parameters = ""
  else if typeof(parameters) is 'object' and (parameters instanceof Array)
    parameters = parameters.join(';')
  ANSI_CSI + String(parameters) + String(code)

ANSITextApplyProperties = (string, properties) ->
  ANSIControlCode(ANSI_TEXT_PROP, properties) + String(string) + ANSIControlCode(ANSI_TEXT_PROP)

colorCodeMap =
  "black":     ANSI_BLACK
  "red":       ANSI_RED
  "green":     ANSI_GREEN
  "yellow":    ANSI_YELLOW
  "blue":      ANSI_BLUE
  "magenta":   ANSI_MAGENTA
  "cyan":      ANSI_CYAN
  "white":      ANSI_WHITE

ANSITextColorize = (string, color) ->
  if not colorCodeMap[color]?
    string
  ANSITextApplyProperties(string, ANSI_FG + colorCodeMap[color])

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
  console.log ANSITextColorize("#{dateformat now()}: #{msg}",color)

assigner(arrival_rate,worker1,(state) -> log "Do this one day job! Your queue is now #{state['queue'].length} deep.", 'red')

worker(processing_rate,worker1,
  (event,state,job) ->
    switch event
      when 'started'
        log "Picking up a new job, and I have #{state['queue'].length} left in the queue!", 'blue'
        log "Average lead time:      #{avg_system_time(state).toFixed(1)} days.", 'blue'
        log "Average jobs in system: #{avg_system_size(state).toFixed(1)}.", 'blue',
        log "Average pct queue time: #{avg_queue_pct(state).toFixed(1)}%.", 'blue',
      when 'finished'
        log "Finished job number #{finished(state)}! That job took #{process_time(job)} days! It's been in the system for #{system_time(job)} days, though. That's #{queue_pct(job).toFixed(0)}% queue time.", 'green',
      when 'idle'
        log "Nothing for me to do... guess I'll take a nap.", 'yellow'
)

