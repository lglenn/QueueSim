# Symbols:
# ρ : capacity utilization
# λ : average arrival rate

# One tick == one hour
# Rate is (roughly) the number of milliseconds between clock ticks.
# YMMV because of setTimeout
# Don't make it too high, or you'll get a tight loop that gives nobody
# else any time to do any work. 
ticker = (λ) ->
  queue = []
  ticks = 0
  scale = 1/λ
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
    setTimeout(my,λ)

  my.setticktimeout = (t,f) ->
    queue.push [f,t]
    return my
  
  my.time = () ->
    ticks

  my.start = () ->
    my()
    return my

  return my

State = (clock) ->

  counter = () ->
   'count': 0
   'total': 0

  start_time = clock.time()
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
 
  my.queue_length = () ->
    queue.length

  my.enqueue_job = () ->
    queue.push(Job().new(clock.time()))

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

hours_to_business_days = d3.scale.linear().domain([0,8]).range([0,1])
business_days_to_hours = d3.scale.linear().domain([0,1]).range([0,8])

clock = ticker(100).start()

now = (state) ->
  clock.time() - state.start_time()

random =

  # Generates values from the exponential distribution with rate λ
  exponential:

    with_rate: (λ) ->
      Math.log(1-Math.random())/(-1 * λ)

    with_mean: (μ) ->
      random.exponential.with_rate(1/μ)

random_int = (μ) ->
  Math.ceil(random.exponential.with_mean(μ))

Job = () ->
  queued = null
  started = null
  size = 0
  done = null

  dur = (start,end) ->
    (end - start)
  
  my = () ->

  my.new = (start_time) ->
    queued = start_time
    my

  my.size = (value) ->
    return size if !value?
    size = value
    my

  my.started = (value) ->
    return started if !value?
    started = value
    my

  my.done = (value) ->
    return done if !value?
    done = value
    my

  my.system_time = () ->
    dur(queued,done)
    
  my.process_time = () ->
    dur(started,done)
  
  my.queue_time = () ->
    dur(queued,started)
  
  my.queue_pct = () ->
    (my.queue_time() / my.system_time()) * 100

  my
  
# Assign work at a given rate
assigner = (dispatch) ->
  mean_interval = 8

  my = () ->
    interval = random_int(mean_interval)
    dispatch.newjob(interval)
    clock.setticktimeout(interval,my)

  my.mean_interval = (value) ->
    return mean_interval if !value?
    mean_interval = value
    my

  my

# Work at a given rate
worker = (capacity,mean_size,state,dispatcher) ->
  job = null
  myworker = () ->
    if job?
      job.done(clock.time())
      state.system_time(job.system_time())
      state.size(job.size())
      dispatcher.finished(job)
      job = null
    if state.queue_length() > 0
      state.paused(null)
      job = state.dequeue_job()
      job.size(random_int(mean_size))
      job.started(clock.time())
      state.queue_time(job.queue_time())
      dispatcher.started()
      t = (job.size() / capacity)
    else
      dispatcher.idle()
      state.paused(1)
      t = 0
    clock.setticktimeout(t,myworker)
  myworker()

d3.select("#params").selectAll('#go')
  .on("click",
    () ->
      mean_arrival_interval = parseFloat(d3.select('#params').select('#mean_arrival_rate').property('value')) * 8
      mean_job_size = parseFloat(d3.select('#params').select('#mean_job_size').property('value')) * 8
      team_capacity = parseFloat(d3.select('#params').select('#team_capacity').property('value'))
      dispatch.params(team_capacity,mean_job_size,mean_arrival_interval))

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

dispatch.on('params',
  (team_capacity,mean_job_size,mean_arrival_interval) ->
    # team capacity: person-hours of work / day
    # job size: person-hours
    # arrival rate: hours
    state = State(clock)
    id = random.exponential.with_mean(100)
    ρ = (mean_job_size * (1/mean_arrival_interval)) / team_capacity

    local_dispatch = d3.dispatch('update','started','finished','idle')

    assigner(dispatch)
      .mean_interval(mean_arrival_interval)
      .call()

    worker(team_capacity,mean_job_size,state,local_dispatch)

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
      .text("#{Math.round(ρ * 100)}% Capacity Utilization")

    canvas = d3.select("#viz").append('svg').attr('width',width).attr('height',height)
      .append("g")
      .attr("transform","translate(30,30)")

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

    dispatch.on("newjob.#{id}",
      (arrival) ->
        state.enqueue_job()
        state.arrival(arrival)
        local_dispatch.update(state)
        log "Do this one day job! Your queue is now #{state.queue_length()} deep.")
  
    local_dispatch.on('started.log',
      (job) ->
        local_dispatch.update(state)
        log "Picking up a new job, and I have #{state.queue_length()} left in the queue!"
        log "Average job size:       #{state.avg_job_size().toFixed(1)} hours."
        log "Average lead time:      #{state.avg_system_time().toFixed(1)} hours."
        log "Average jobs in system: #{state.avg_system_size().toFixed(1)}."
        log "Average pct queue time: #{state.avg_queue_pct().toFixed(1)}%.")
  
    local_dispatch.on('update.barchart',
      () ->
        bc.datum(
          [
            state.queue_length()
            state.avg_system_size()
            hours_to_business_days(state.avg_system_time())
            hours_to_business_days(state.avg_job_size())
          ]
        )
        .call(bars))

    local_dispatch.on('finished.scatterchart',
      (job) ->
        sc.datum(
          [ { 'x': hours_to_business_days(job.system_time()), 'y': job.queue_pct() / 100, 'r': hours_to_business_days(job.process_time()) } ]
        )
        .call(scatter))

    local_dispatch.on('finished.legend',
      (job) ->
        leg.datum([
          "Last job lead time: #{job.system_time().toFixed(1)} hours"
          "% queue time: #{(job.queue_time()/job.system_time() * 100).toFixed(0)}%"
          "Avg % queue time: #{state.avg_queue_pct().toFixed(0)}%"
          "Jobs completed: #{state.finished()}"
          "Total Cost of Delay: $#{(state.avg_system_time() * state.finished() * 100).toFixed(0)}"
          "Elapsed time: #{hours_to_business_days(now(state)).toFixed(1)} business days"
        ])
        .call(lc))

    local_dispatch.on('finished.log',
      (job) ->
        log "Finished job number #{state.finished()}! That job took #{job.process_time()} hours! It's been in the system for #{job.system_time()} hours, though. That's #{job.queue_pct().toFixed(0)}% queue time."
        local_dispatch.update(state))
  
    local_dispatch.on('idle.log',
      () ->
         log "Nothing for me to do... guess I'll take a nap." unless state.paused()?))
