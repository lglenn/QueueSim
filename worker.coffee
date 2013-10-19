arrival_rate = .125
processing_rate = .125

# One tick == one hour
# Rate is (roughly) the number of milliseconds between clock ticks.
# YMMV because of setTimeout
# Don't make it too high, or you'll get a tight loop that gives nobody
# else any time to do any work. 
ticker = (rate) ->
  queue = []
  ticks = 0
  scale = 1/rate
  days = d3.scale.linear().domain([0,24]).range([0,1])

  tick = () ->
    job = queue.shift()
    if job[1] <= 1
      job[0]()
    else
      job[1] -= 1
      queue.push(job)

  my = () ->
    if queue.length > 0
      tick() for index in [0..queue.length-1]
    ticks += 1
    setTimeout(my,rate)

  my.setticktimeout = (t,f) ->
    queue.push [f,t]
    return my
  
  my.time = () ->
    ticks

  my.start = () ->
    my()

  return my

clock = ticker(100)
clock.start()

counter = () ->
  'count': 0
  'total': 0

newstate = () ->
  'start_time': clock.time()
  'queue': []
  'paused': null
  'job': null
  'sizes': counter()
  'arrivals': counter()
  'queue_times': counter()
  'system_times': counter()

now = (state) ->
  clock.time() - state['start_time']

# Generates values from the exponential distribution with rate `rate`
rand_exp = (rate) ->
  Math.log(1-Math.random())/(-1 * rate)

scaled_rate = () ->
  (rate) ->
    Math.ceil(rand_exp(rate))

avg = (hash) ->
  if hash['count'] is 0
    0
  else
    hash['total']/hash['count']

incr = (hash,t) ->
  hash['count'] += 1
  hash['total'] += t

dur = (start,end) ->
  (end - start)

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
  a = avg(state['arrivals'])/1000
  if a == 0 then 0 else 1/a

avg_system_size = (state) ->
  # Little's law: avg jobs in system = avg arrival rate * avg time in system
  avg_arrival_rate(state) * avg_system_time(state)

random_value = scaled_rate()

# Assign work at a given rate
assigner = (arrival_rate,dispatch) ->
  myassigner = () ->
    interarrival_time = random_value(arrival_rate)
    dispatch.newjob(interarrival_time)
    clock.setticktimeout(interarrival_time,myassigner)
  myassigner()

# Work at a given rate
worker = (processing_rate,capacity_utilization,state,dispatcher) ->
  job = null
  myworker = () ->
    if job?
      job['done'] = clock.time()
      incr(state['system_times'],dur(job['queued'],job['done']))
      incr(state['sizes'],dur(job['started'],job['done']))
      dispatcher.finished(job)
      job = null
    if state['queue'].length > 0
      state['paused'] = null
      job = state['queue'].shift()
      job['size'] = random_value(processing_rate * capacity_utilization)
      job['started'] = clock.time()
      incr(state['queue_times'],dur(job['queued'],job['started']))
      dispatcher.started()
      t = job['size']
    else
      dispatcher.idle()
      state['paused'] = 1
      t = 0
    clock.setticktimeout(t,myworker)
  myworker()

cap = d3.select("#params").select('input')
    .on("change", () -> dispatch.params(this.value))

legend = () ->
  height = 0
  width = 0
  margin =
    top: 20
    right: 20
    bottom: 20
    left: 20

  my = (selection) ->
    selection.each((d) ->
      frame =
        height: height - margin.top - margin.bottom
        width: width - margin.left - margin.right
      svg = d3.select(this).selectAll("svg").data([d])
        .attr('height',height)
        .attr('width',width)
      svg.enter().append("svg").append("g")
        .attr('class','frame')
        .attr('height',frame.height)
        .attr('width',frame.width)
        .attr('transform',"translate(#{margin.left},#{margin.top})")

      svg.select('.frame').selectAll('text')
        .data(d)
        .enter()
        .append('svg:text')
        .attr('y',(d,i) -> 50 + (i*20))
        .attr('x',30)
        .attr("text-anchor", "left")
        .attr('class','legend')

      svg.selectAll('text')
        .text(String))

  my.height = (value) ->
    return height if !value?
    height = value
    my

  my.width = (value) ->
    return width if !value?
    width = value
    my

  my.margin = (value) ->
    return margin if !value?
    margin = value
    my

  return my
  
scatterchart = () ->
  height = 0
  width = 0
  x_max = 30
  c_max = 20
  fade_time = 120
  max_radius = 40
  x_tick_format = d3.format("2s")
  margin =
    top: 20
    right: 20
    bottom: 20
    left: 20

  my = (selection) ->
    selection.each((d) ->
      frame =
          height: height - margin.top - margin.bottom
          width: width - margin.left - margin.right
      x = d3.scale.linear().domain([0,x_max]).range([0,frame.width])
      y = d3.scale.linear().domain([0,1]).range([frame.height, 0]).nice()
      c = d3.scale.sqrt().domain([0,c_max]).range([0,max_radius]).nice()

      yaxis = d3.svg.axis()
        .scale(y)
        .orient("left")
        .tickFormat((d) -> "#{d * 100}%")
    
      xaxis = d3.svg.axis()
        .scale(x)
        .orient("bottom")
        .tickSize(0)
        .tickFormat(x_tick_format)
    
      svg = d3.select(this).selectAll('svg').data([d])
      genter = svg.enter().append('svg').append('g')
      genter.append('g').attr('class','x axis')
      genter.append('g').attr('class','y axis')
      genter.append('g').attr('class','chart')

      genter
        .attr('class','frame')
        .attr('transform',"translate(#{margin.left},#{margin.top})")
        .attr('width',frame.width)
        .attr('height',frame.height)
    
      fr = svg.select('.frame')

      fr.select('.y.axis')
        .call(yaxis)
    
      fr.select('.x.axis')
        .attr('transform',"translate(0,#{frame.height})")
        .call(xaxis)
    
      circle = fr.select('.chart').append('circle')
        .data(d)
        .attr('r',0)
        .attr('cy',(d) -> y(d['y']))
        .attr('cx',(d) -> x(d['x']))
        .transition()
        .delay(0)
        .duration(fade_time)
        .attr('r',(d) -> c(d['r']))
        .attr('class','scatterplot'))

  my.x_format = (value) ->
    return x_tick_format if !value?
    x_tick_format = value
    return my

  my.height = (value) ->
    return height if !value?
    height = value
    return my

  my.width = (value) ->
    return width if !value?
    width = value
    return my

  my.x_max = (value) ->
    return x_max if !value?
    x_max = value
    return my

  my.c_max = (value) ->
    return c_max if !value?
    c_max = value
    return my

  my.max_radius = (value) ->
    return max_radius if !value?
    max_radius = value
    return my

  my.fade_time = (value) ->
    return fade_time if !value?
    fade_time = value
    return my

  my.margin = (value) ->
    return margin if !value?
    margin = value
    return my

  return my

barchart = () ->
  barwidth = 120
  labels  = []
  width = 0
  height = 0
  ymax = 30
  margin =
    top: 20
    right: 20
    bottom: 20
    left: 20

  my = (selection) ->
    selection.each((d) ->
      frame =
          height: height - margin.top - margin.bottom
          width: width - margin.left - margin.right
      x = d3.scale.linear().domain([0,d.length]).range([0,frame.width])
      y = d3.scale.linear().domain([0,ymax]).range([frame.height, 0]).nice()

      svg = d3.select(this).selectAll('svg').data([d])

      xaxis = d3.svg.axis()
        .scale(x)
        .orient('bottom')
        .tickSize(0)
        .tickFormat('')
    
      yaxis = d3.svg.axis()
        .scale(y)
        .orient('left')
        .tickFormat(d3.format('.2s'))
    
      genter = svg.enter().append('svg').append('g')
        .attr('class','frame')
      genter.append('g')
        .attr('class','x axis')
        .attr('transform',"translate(0,#{frame.height})")
        .call(xaxis)
      genter.append('g').attr('class','y axis')
        .call(yaxis)
      genter.append('g').attr('class','chart')
      
      genter
        .attr('transform',"translate(#{margin.left},#{margin.top})")
        .attr('height',frame.height)
        .attr('width',frame.width)
    
      g = svg.select('.frame')

      xlabels = g.selectAll('.xlabel').data(d)

      xlabels.enter()
        .append('svg:text')
        .attr('class','xlabel')
        .attr('x', (d,i) -> x(i) + barwidth )
        .attr('y', frame.height + 12)
        .attr('dx', -barwidth/2)
        .attr('text-anchor', 'middle')
        .text((d,i) -> labels[i])
    
      bars = g.select('.chart').selectAll('.bar')
        .data(d)

      bars.enter()
        .append('rect')
        .attr('class',(d,i) -> "bar bar#{i}")
        .attr('x',(d,i) -> x(i))
        .attr('width',barwidth)

      bars
        .transition()
        .delay(0)
        .duration(120)
        .attr('height',(d) -> frame.height - y(d))
        .attr('y',y))

  my.labels = (value) ->
    return labels if !value?
    labels = value
    return my

  my.height = (value) ->
    return height if !value?
    height = value
    return my

  my.width = (value) ->
    return width if !value?
    width = value
    return my

  my.ymax = (value) ->
    return ymax if !value?
    ymax = value
    return my

  my.margin = (value) ->
    return margin if !value?
    margin = value
    return my

  return my

dispatch = d3.dispatch('params','newjob')

assigner(.125,dispatch)

dispatch.on('params',
  (capacity_utilization) ->
    state = newstate()
    id = rand_exp(100)
    capacity_utilization = parseFloat(capacity_utilization)
    arrival_rate = .125 # one-eighth of a job in an hour, or one job per day.
    width = 2000
    graph_width = 600
    graph_height = 300
    height = 400

    dateformat = (d) ->
      "#{d.toFixed(2)} days"

    log = (msg) ->
      console.log "#{dateformat now(state)}: #{msg}"
  
    d3.select('#viz').append('div')
      .attr('class','title')
      .text("#{capacity_utilization * 100}% Capacity Utilization")

    canvas = d3.select("#viz").append('svg').attr('width',width).attr('height',height)
      .append("g")
      .attr("transform","translate(30,30)")

    local_dispatch = d3.dispatch('update','started','finished','idle')

    margin =
      top: 20
      right: 30
      bottom: 20
      left: 30

    bc = canvas.append('g').attr('transform',"translate(30,0)")
    sc = canvas.append('g').attr('transform',"translate(#{graph_width + 50},0)")
    leg = canvas.append('g').attr('transform',"translate(#{(graph_width + 50) * 2},0)")

    bars = barchart().height(graph_height).width(graph_width).margin(margin).labels(['Queue','Avg Jobs in System','Avg Lead Time','Avg Job Size'])
    scatter = scatterchart().height(graph_height).width(graph_width).margin(margin).fade_time(120)
    lc = legend().height(graph_height).width(graph_width/2).margin(margin)

    bc.datum([0,0,0,0]).call(bars)
    sc.datum([]).call(scatter)
    leg.datum([0,0,0,0]).call(lc)

    worker(processing_rate,capacity_utilization,state,local_dispatch)

    dispatch.on("newjob.#{id}",
      (arrival) ->
        state['queue'].push {'queued': clock.time()}
        incr(state['arrivals'],arrival)
        local_dispatch.update(state)
        log "Do this one day job! Your queue is now #{state['queue'].length} deep.")
  
    local_dispatch.on('started.log',
      (job) ->
        local_dispatch.update(state)
        log "Picking up a new job, and I have #{state['queue'].length} left in the queue!"
        log "Average job size:       #{avg_job_size(state).toFixed(1)} hours."
        log "Average lead time:      #{avg_system_time(state).toFixed(1)} hours."
        log "Average jobs in system: #{avg_system_size(state).toFixed(1)}."
        log "Average pct queue time: #{avg_queue_pct(state).toFixed(1)}%.")
  
    local_dispatch.on('update.barchart',
      () ->
        bc.datum(
          [
            state['queue'].length
            avg_system_size(state)
            avg_system_time(state)
            avg_job_size(state)
          ]
        )
        .call(bars))

    local_dispatch.on('finished.scatterchart',
      (job) ->
        hours_to_business_days = d3.scale.linear().domain([0,8]).range([0,1])
        sc.datum(
          [ { 'x': hours_to_business_days(system_time(job)), 'y': queue_pct(job) / 100, 'r': hours_to_business_days(process_time(job)) } ]
        )
        .call(scatter))

    local_dispatch.on('finished.legend',
      (job) ->
        leg.datum([
          "Last job lead time: #{system_time(job).toFixed(1)} hours"
          "% queue time: #{(queue_time(job)/system_time(job) * 100).toFixed(0)}%"
          "Avg % queue time: #{avg_queue_pct(state).toFixed(0)}%"
          "Jobs completed: #{finished(state)}"
          "Total Cost of Delay: $#{(avg_system_time(state) * finished(state) * 100).toFixed(0)}"
          "Elapsed time: #{now(state).toFixed(1)} hours"
        ])
        .call(lc))

    local_dispatch.on('finished.log',
      (job) ->
        log "Finished job number #{finished(state)}! That job took #{process_time(job)} hours! It's been in the system for #{system_time(job)} hours, though. That's #{queue_pct(job).toFixed(0)}% queue time."
        local_dispatch.update(state))
  
    local_dispatch.on('idle.log',
      () ->
         log "Nothing for me to do... guess I'll take a nap." unless state['paused']?))
