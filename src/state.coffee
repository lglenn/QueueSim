# timef parameter is a function which returns the
# number of clock ticks since the world started.
State = (timef) ->

  days = d3.scale.linear().domain([0,24]).range([0,1])

  counter = () ->
   'count': 0
   'total': 0

  start_time = 0
  queue = []
  paused = null
  job = null
  sizes = counter()
  arrivals = counter()
  queue_times = counter()
  system_times = counter()
 
  incr = (hash,t) ->
    hash['count'] += 1
    hash['total'] += t
  
  avg = (hash) ->
    if hash['count'] is 0
      0
    else
      hash['total']/hash['count']
  
  my = () ->
 
  my.now = () ->
    timef() - start_time

  my.days = () ->
    days(my.now())

  my.queue_length = () ->
    queue.length

  my.enqueue = (job) ->
    queue.push(job)

  my.dequeue_job = () ->
    queue.shift()

  my.start_time = () ->
    start_time

  my.paused = (value) ->
    return paused if !value?
    paused = value

  my.size = (size) ->
    incr(sizes,size)

  my.arrival = (time) ->
    incr(arrivals,time)

  my.queue_time = (time) ->
    incr(queue_times,time)

  my.system_time = (time) ->
    incr(system_times,time)

  my.finished = () ->
    system_times['count']
  
  my.avg_job_size = () ->
    avg(sizes)
  
  my.avg_queue_pct = () ->
    my.avg_queue_time() / my.avg_system_time() * 100
  
  my.avg_queue_time = () ->
    avg(queue_times)
  
  my.avg_system_time = () ->
    avg(system_times)
  
  my.avg_arrival_rate = () ->
    a = avg(arrivals)
    if a == 0 then 0 else 1/a
 
  my.avg_system_size = () ->
    # Little's law: avg jobs in system = avg arrival rate * avg time in system
    #                    L = λW
    my.avg_arrival_rate() * my.avg_system_time()
  
  my

