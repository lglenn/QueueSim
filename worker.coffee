counter = () ->
  'count': 0
  'total': 0

state = () ->
  'queue': []
  'paused': null
  'job': null
  'sizes': counter()
  'arrivals': counter()
  'queue_times': counter()
  'system_times': counter()

rand = (rate) ->
  Math.log(1-Math.random())/(-1 * rate)

sleeptime = (rate) ->
  rand(rate) * 1000

avg = (hash) ->
  if hash['count'] is 0
    0
  else
    hash['total']/hash['count']

incr = (hash,t) ->
  hash['count'] += 1
  hash['total'] += t

dispatch = d3.dispatch('params','newjob')

assigner = (rate) ->
  myassigner = () ->
    t = sleeptime(rate)
    dispatch.newjob(t)
    setTimeout(myassigner,t)
  myassigner()

dur = (start,end) ->
  (end - start) / 1000

worker = (processing_rate,state,dispatcher) ->
  job = null
  myworker = () ->
    if job?
      job['done'] = new Date()
      incr(state['system_times'],dur(job['queued'],job['done']))
      incr(state['sizes'],dur(job['started'],job['done']))
      dispatcher.finished(state, job)
      job = null
    if state['queue'].length > 0
      state['paused'] = null
      job = state['queue'].shift()
      job['started'] = new Date()
      incr(state['queue_times'],dur(job['queued'],job['started']))
      t = sleeptime(processing_rate)
      dispatcher.started(state)
    else
      dispatcher.idle(state)
      state['paused'] = 1
      t = 0
    setTimeout(myworker,t)
  myworker()

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

avg_job_size = (state) ->
  avg(state['sizes'])

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

# Graph Stuff

cap = d3.select("body")
    .append("div")
    .append("input")
    .on("change", () -> dispatch.params(this.value))

colors = ['red','green','#ff8800','#0088ff']

assigner(1)

dispatch.on('params',
  (capacity_utilization) ->
    start_time = new Date()
    worker1 = state()
    id = rand(100)
    console.log "My id is #{id}"
    capacity_utilization = parseFloat(capacity_utilization)
    arrival_rate = 1
    processing_rate = arrival_rate / capacity_utilization
    local_dispatch = d3.dispatch('update','started','finished','idle')

    now = () ->
      runtime = new Date() - start_time
      d = new Date()
      d.setSeconds(d.getSeconds() + ((runtime / 1000) * 60 * 60 * 24))
      d
    
    log = (msg) ->
      console.log "#{dateformat now()}: #{msg}"
  
    canvas = d3.select("#viz").append('svg').attr('width',500).attr('height',400)
      .append("g")
      .attr("transform","translate(30,30)")

    bars = canvas.selectAll('bars')
      .data([0,0,0,0])
      .enter()
      .append('rect')
      .style('stroke',(d,i) -> colors[i])
      .style('fill',(d,i) -> colors[i])
      .attr('x',(d,i) -> ((1 + i) * 80 - 50))
      .attr('y',300)
      .attr('width',50)
      .attr('height',(d) -> d)

    canvas.selectAll("text")
      .data([1])
      .enter()
      .append("svg:text")
      .attr("x", 150)
      .attr("y", 50)
      .attr("text-anchor", "middle")
      .attr("style", "font-size: 12; font-family: Helvetica, sans-serif")
      .text("Cap: #{capacity_utilization}")

    y = d3.scale.linear()
      .domain([0, 30])
      .range([300, 0])
      .nice()

    yAxis = d3.svg.axis()
      .scale(y)
      .orient("left")
      .tickFormat(d3.format(".2s"))

    canvas.append("g")
      .attr("class", "y axis")
      .call(yAxis)

    heights = (state,factor) ->
      (Math.round(x) * factor) for x in [state['queue'].length,avg_system_size(state),avg_system_time(state),avg_job_size(state)]

    dispatch.on("newjob.#{id}",
      (t) ->
        worker1['queue'].push {'queued': new Date()}
        incr(worker1['arrivals'],t)
        local_dispatch.update(worker1)
        log "Do this one day job! Your queue is now #{worker1['queue'].length} deep.", 'red')

    local_dispatch.on("update",
      (state) ->
        bars
        .data(heights(state,10))
        .transition()
        .delay(0)
        .duration(120)
        .attr('y',(d) -> 300 - d)
        .attr('height',(d) -> d))

    local_dispatch.on('started',
      (state,job) ->
        local_dispatch.update(state)
        log "Picking up a new job, and I have #{state['queue'].length} left in the queue!"
        log "Average job size:       #{avg_job_size(state).toFixed(1)} days."
        log "Average lead time:      #{avg_system_time(state).toFixed(1)} days."
        log "Average jobs in system: #{avg_system_size(state).toFixed(1)}."
        log "Average pct queue time: #{avg_queue_pct(state).toFixed(1)}%.")

    local_dispatch.on('finished',
      (state,job) ->
        log "Finished job number #{finished(state)}! That job took #{process_time(job)} days! It's been in the system for #{system_time(job)} days, though. That's #{queue_pct(job).toFixed(0)}% queue time.")

    local_dispatch.on('idle',
      (state) ->
         log "Nothing for me to do... guess I'll take a nap." unless state['paused']?)

    worker(processing_rate,worker1,local_dispatch))
