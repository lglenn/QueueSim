queue = []
paused = null
job = null
arrivals = {'count':0,'total':0}
times = {'count':0,'total':0}

rand = (rate) ->
  r = Math.log(1-Math.random())/(-1 * rate)
  return r

sleeptime = () ->
  t = rand(1) * 1000
  t

avg = (hash) ->
  hash['total']/hash['count']

incr = (hash,t) ->
  hash['count'] += 1
  hash['total'] += t

assigner = (cb) ->
  myassigner = () ->
    queue.push {'queued': new Date()}
    cb()
    t = sleeptime()
    incr(arrivals,t)
    setTimeout(myassigner,t)
  myassigner()

dur = (start,end) ->
  (end - start) / 1000

worker = (newjob,done,idle) ->
  myworker = () ->
    if job?
      end = new Date()
      incr(times,dur(job['queued'],end))
      done(job,end)
      job = null
    if queue.length > 0
      paused = null
      t = sleeptime()
      job = queue.shift()
      job['started'] = new Date()
      newjob()
    else
      idle() unless paused?
      paused = 1
      t = 0
    setTimeout(myworker,t)
  myworker()

assigner(() -> console.log "Do this one day job! Your queue is now #{queue.length} deep.")

worker(
  () ->
    console.log "Picking up a new job, and I have #{queue.length} left in the queue!"
    console.log "Average time in q: #{avg(times).toFixed(1)} days."
    console.log "Average q len: #{((1/avg(times))*avg(arrivals)/1000).toFixed(1)} jobs.",
  (job,end) ->
    console.log "Finished! That job took #{dur(job['started'],end)} days! It's been in the system for #{dur(job['queued'],end)} days, though.",
  () ->
    console.log "Nothing for me to do... guess I'll take a nap."
)
