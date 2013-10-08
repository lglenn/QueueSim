counter = () ->
  'count': 0
  'total': 0

newstate = () ->
  'queue': []
  'paused': null
  'job': null
  'sizes': counter()
  'arrivals': counter()
  'queue_times': counter()
  'system_times': counter()

# Generates values from the exponential distribution with rate `rate`
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

dur = (start,end) ->
  (end - start) / 1000

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

dispatch = d3.dispatch('params','newjob')

# Assign work at a given rate
assigner = (rate) ->
  myassigner = () ->
    t = sleeptime(rate)
    dispatch.newjob(t)
    setTimeout(myassigner,t)
  myassigner()

# Work at a given rate
worker = (processing_rate,state,dispatcher) ->
  job = null
  myworker = () ->
    if job?
      job['done'] = new Date()
      incr(state['system_times'],dur(job['queued'],job['done']))
      incr(state['sizes'],dur(job['started'],job['done']))
      dispatcher.finished(state,job)
      job = null
    if state['queue'].length > 0
      state['paused'] = null
      job = state['queue'].shift()
      job['started'] = new Date()
      incr(state['queue_times'],dur(job['queued'],job['started']))
      t = sleeptime(processing_rate)
      dispatcher.started()
    else
      dispatcher.idle()
      state['paused'] = 1
      t = 0
    setTimeout(myworker,t)
  myworker()

cap = d3.select("body")
    .append("div")
    .append("input")
    .on("change", () -> dispatch.params(this.value))

legend = (svg,x_pos,dispatcher) ->
  legends = [
    (d) -> "Last job lead time: #{d.toFixed(1)} days"
    (d) -> "% queue time: #{d.toFixed(0)}%"
    (d) -> "Avg % queue time: #{d.toFixed(0)}%"
    (d) -> "Jobs completed: #{d}"
  ]
  l = svg.selectAll("text.legend")
    .data([0,0,0,0])
    .enter().append("svg:text")
    .attr('x',x_pos + 40)
    .attr('y',(d,i) -> 100 + (i*30))
    .attr("text-anchor", "left")
    .attr("style", "font-size: 12; font-family: Helvetica, sans-serif")
    .text((d,i) -> legends[i](d))
  dispatcher.on('finished.legend',
    (state,job) ->
      l.data([
        system_time(job)
        (queue_time(job)/system_time(job) * 100)
        avg_queue_pct(state)
        finished(state)
      ])
      .text((d,i) -> legends[i](d)))
  
assigner(1)

barchart = (canvas,width,height,dispatch) ->
  barwidth = 120
  names  = ['Queue',"Avg Jobs in System","Avg Lead Time","Avg Job Size"]
  colors = ['red','green','#ff8800','#0088ff']

  x = d3.scale.linear().domain([0,4]).range([0,width])
  y = d3.scale.linear().domain([0, 30]).range([height, 0]).nice()

  canvas.selectAll("text.xaxis")
    .data([0,0,0,0])
    .enter().append("svg:text")
    .attr("x", (d,i) -> x(i) + barwidth )
    .attr("y", height - 15)
    .attr("dx", -barwidth/2)
    .attr("text-anchor", "middle")
    .attr("style", "font-size: 12; font-family: Helvetica, sans-serif")
    .text((d,i) -> names[i])
    .attr("transform", "translate(0, 32)")
    .attr("class", "yAxis")

  yaxis = d3.svg.axis()
    .scale(y)
    .orient("left")
    .tickFormat(d3.format(".2s"))

  xaxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")
    .tickSize(0)
    .tickFormat("")

  canvas.append("g")
    .attr("class", "y axis")
    .call(yaxis)

  bars = canvas.selectAll('bars')
    .data([0,0,0,0])
    .enter()
    .append('rect')
    .style('stroke',(d,i) -> colors[i])
    .style('fill',(d,i) -> colors[i])
    .attr('x',(d,i) -> x(i))
    .attr('y',height)
    .attr('width',barwidth)
    .attr('height',(d) -> d)

  canvas.append("g")
    .attr("class", "x axis")
    .attr("width",width)
    .attr('height',100)
    .attr('transform',"translate(0,#{height})")
    .call(xaxis)

  dispatch.on('update.barchart',
    (state) ->
      heights = () ->
        height - y(n) for n in [
          state['queue'].length
          avg_system_size(state)
          avg_system_time(state)
          avg_job_size(state)
        ]
      bars.data(heights)
      .transition()
      .delay(0)
      .duration(120)
      .attr('y',(d) -> height - d)
      .attr('height',(d) -> d))

title = (canvas,x,y,text) ->
  canvas.selectAll("text.title")
    .data([1])
    .enter()
    .append("svg:text")
    .attr("x", x)
    .attr("y", y)
    .attr("text-anchor", "middle")
    .attr("style", "font-size: 12; font-family: Helvetica, sans-serif")
    .text(text)

dispatch.on('params',
  (capacity_utilization) ->
    start_time = new Date()
    state = newstate()
    id = rand(100)
    capacity_utilization = parseFloat(capacity_utilization)
    arrival_rate = 1
    processing_rate = arrival_rate / capacity_utilization
    width = 900
    graph_width = 600
    graph_height = 300
    legend_width = 300
    height = 400

    now = () ->
      runtime = new Date() - start_time
      d = new Date()
      d.setSeconds(d.getSeconds() + ((runtime / 1000) * 60 * 60 * 24))
      d
    
    dateformat = (d) ->
      "#{d.toLocaleDateString()} #{d.toLocaleTimeString()}"

    log = (msg) ->
      console.log "#{dateformat now()}: #{msg}"
  
    canvas = d3.select("#viz").append('svg').attr('width',width).attr('height',height)
      .append("g")
      .attr("transform","translate(30,30)")

    local_dispatch = d3.dispatch('update','started','finished','idle')

    title(canvas,width/2,20,"Capacity Utilization: #{capacity_utilization * 100}%")
    legend(canvas,graph_width,local_dispatch)
    barchart(canvas,graph_width,graph_height,local_dispatch)

    worker(processing_rate,state,local_dispatch)

    dispatch.on("newjob.#{id}",
      (t) ->
        state['queue'].push {'queued': new Date()}
        incr(state['arrivals'],t)
        local_dispatch.update(state)
        log "Do this one day job! Your queue is now #{state['queue'].length} deep.", 'red')
  
    local_dispatch.on('started',
      (job) ->
        local_dispatch.update(state)
        log "Picking up a new job, and I have #{state['queue'].length} left in the queue!"
        log "Average job size:       #{avg_job_size(state).toFixed(1)} days."
        log "Average lead time:      #{avg_system_time(state).toFixed(1)} days."
        log "Average jobs in system: #{avg_system_size(state).toFixed(1)}."
        log "Average pct queue time: #{avg_queue_pct(state).toFixed(1)}%.")
  
    local_dispatch.on('finished',
      (state,job) ->
        log "Finished job number #{finished(state)}! That job took #{process_time(job)} days! It's been in the system for #{system_time(job)} days, though. That's #{queue_pct(job).toFixed(0)}% queue time."
        local_dispatch.update(state))
  
    local_dispatch.on('idle',
      () ->
         log "Nothing for me to do... guess I'll take a nap." unless state['paused']?))
