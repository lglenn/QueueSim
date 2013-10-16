counter = () ->
  'count': 0
  'total': 0

newstate = () ->
  'start_time': new Date()
  'queue': []
  'paused': null
  'job': null
  'sizes': counter()
  'arrivals': counter()
  'queue_times': counter()
  'system_times': counter()

now = (state) ->
  runtime = new Date() - state['start_time']
  d = new Date()
  d.setSeconds(d.getSeconds() + ((runtime / 1000) * 60 * 60 * 24))
  d

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
  a = avg(state['arrivals'])/1000
  if a == 0 then 0 else 1/a

avg_system_size = (state) ->
  # Little's law: avg jobs in system = avg arrival rate * avg time in system
  avg_arrival_rate(state) * avg_system_time(state)

# Assign work at a given rate
assigner = (arrival_rate,processing_rate,dispatch) ->
  myassigner = () ->
    t = sleeptime(arrival_rate)
    size = sleeptime(processing_rate)
    dispatch.newjob(t,size)
    setTimeout(myassigner,t)
  myassigner()

# Work at a given rate
worker = (capacity_utilization,state,dispatcher) ->
  job = null
  myworker = () ->
    if job?
      job['done'] = new Date()
      incr(state['system_times'],dur(job['queued'],job['done']))
      incr(state['sizes'],dur(job['started'],job['done']))
      dispatcher.finished(job)
      job = null
    if state['queue'].length > 0
      state['paused'] = null
      job = state['queue'].shift()
      job['started'] = new Date()
      incr(state['queue_times'],dur(job['queued'],job['started']))
      t = job['size'] * (1 / capacity_utilization)
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

legend = () ->
  height = 0
  width = 0
  mydispatch = null
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
        .attr("style", "font-size: 12; font-family: Helvetica, sans-serif")

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

  my.mydispatch = (value) ->
    return mydispatch if !value?
    mydispatch = value
    my

  my.margin = (value) ->
    return margin if !value?
    margin = value
    my

  return my
  
scatterchart = () ->
  height = 0
  width = 0
  max_lead = 30
  fade_time = 120
  max_radius = 40
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
      x = d3.scale.linear().domain([0,max_lead]).range([0,frame.width])
      y = d3.scale.linear().domain([0,1]).range([frame.height, 0]).nice()
      c = d3.scale.linear().domain([0,8]).range([0,max_radius]).nice()

      yaxis = d3.svg.axis()
        .scale(y)
        .orient("left")
        .tickFormat(d3.format("2s"))
    
      xaxis = d3.svg.axis()
        .scale(x)
        .orient("bottom")
        .tickSize(0)
        .tickFormat(d3.format("2s"))
    
      svg = d3.select(this).selectAll('svg').data([d])
      svg.attr('height',height ).attr('width',width)
      genter = svg.enter().append('svg').append('g').attr('class','frame')
      genter.append('g').attr('class','x axis')
      genter.append('g').attr('class','y axis')
      genter.append('g').attr('class','chart')

      svg.select('.frame')
        .attr('transform',"translate(#{margin.left},#{margin.top})")
        .attr('width',frame.width)
        .attr('height',frame.height)
    
      g = svg.select('.frame')

      g.select('.y.axis')
        .call(yaxis)
    
      g.select('.x.axis')
        .attr('transform',"translate(0,#{frame.height})")
        .call(xaxis)
    
      circle = g.select('.chart').append('circle')
        .data(d)
        .attr('r',0)
        .attr('cy',(d) -> y(d['y']))
        .attr('cx',(d) -> x(d['x']))
        .transition()
        .delay(0)
        .duration(fade_time)
        .attr('r',(d) -> c(d['r']))

      circle
        .style('fill','#ff4444')
        .style('opacity',0.5)
        .style('stroke','black'))

  my.height = (value) ->
    return height if !value?
    height = value
    return my

  my.width = (value) ->
    return width if !value?
    width = value
    return my

  my.max_lead = (value) ->
    return max_lead if !value?
    max_lead = value
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
  names  = ['Queue',"Avg Jobs in System","Avg Lead Time","Avg Job Size"]
  colors = ['red','green','#ff8800','#0088ff']
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
      svg.attr('height',height ).attr('width',width)

      genter = svg.enter().append('svg').append('g').attr('class','frame')
      genter.append('g').attr('class','x axis')
      genter.append('g').attr('class','y axis')
      genter.append('g').attr('class','chart')
      
      genter
        .attr('transform',"translate(#{margin.left},#{margin.top})")
        .attr('height',frame.height)
        .attr('width',frame.width)
    
      g = svg.select('.frame')

      xaxis = d3.svg.axis()
        .scale(x)
        .orient('bottom')
        .tickSize(0)
        .tickFormat('')
    
      g.select('.x.axis')
        .attr('transform',"translate(0,#{frame.height})")
        .call(xaxis)
    
      xlabels = g.selectAll('.xlabel').data(d)

      xlabels.enter()
        .append('svg:text')
        .attr('class','xlabel')
        .attr('x', (d,i) -> x(i) + barwidth )
        .attr('y', frame.height + 12)
        .attr('dx', -barwidth/2)
        .attr('text-anchor', 'middle')
        .attr('style', 'font-size: 12; font-family: Helvetica, sans-serif')
        .text((d,i) -> names[i])
    
      yaxis = d3.svg.axis()
        .scale(y)
        .orient('left')
        .tickFormat(d3.format('.2s'))
    
      g.select('.y.axis')
        .call(yaxis)
    
      bars = svg.select('.chart').selectAll('.bar')
        .data(d)

      bars.enter()
        .append('rect')
        .style('stroke','black')
        .style('fill',(d,i) -> colors[i])
        .attr('x',(d,i) -> x(i))
        .attr('width',barwidth)
        .attr('class','bar')
        .style('opacity',.5)

      bars
        .transition()
        .delay(0)
        .duration(120)
        .attr('height',(d) -> frame.height - y(d))
        .attr('y',y))

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

dispatch = d3.dispatch('params','newjob')

assigner(1,1,dispatch)

dispatch.on('params',
  (capacity_utilization) ->
    state = newstate()
    id = rand(100)
    capacity_utilization = parseFloat(capacity_utilization)
    arrival_rate = 1
    processing_rate = arrival_rate / capacity_utilization
    width = 2000
    graph_width = 600
    graph_height = 300
    height = 400

    dateformat = (d) ->
      "#{d.toLocaleDateString()} #{d.toLocaleTimeString()}"

    log = (msg) ->
      console.log "#{dateformat now(state)}: #{msg}"
  
    canvas = d3.select("#viz").append('svg').attr('width',width).attr('height',height)
      .append("g")
      .attr("transform","translate(30,30)")

    local_dispatch = d3.dispatch('update','started','finished','idle')

    title(canvas,width/2,20,"Capacity Utilization: #{capacity_utilization * 100}%")

    margin =
      top: 20
      right: 20
      bottom: 20
      left: 20

    bc = canvas.append('g')
    sc = canvas.append('g').attr('transform','translate(675,0)')
    leg = d3.select('body').append('div').attr('class','.legend').style('border','1px solid red')

    bars = barchart().height(graph_height).width(graph_width).margin(margin)
    scatter = scatterchart().height(graph_height).width(graph_width).margin(margin)
    lc = legend().height(graph_height).width(graph_width/2).margin(margin)

    bc.datum([0,0,0,0]).call(bars)
    sc.datum([]).call(scatter)
    leg.datum([0,0,0,0]).call(lc)

    worker(processing_rate,state,local_dispatch)

    dispatch.on("newjob.#{id}",
      (arrival,process) ->
        state['queue'].push {'queued': new Date(), 'size': process}
        incr(state['arrivals'],arrival)
        local_dispatch.update(state)
        log "Do this one day job! Your queue is now #{state['queue'].length} deep.", 'red')
  
    local_dispatch.on('started.log',
      (job) ->
        local_dispatch.update(state)
        log "Picking up a new job, and I have #{state['queue'].length} left in the queue!"
        log "Average job size:       #{avg_job_size(state).toFixed(1)} days."
        log "Average lead time:      #{avg_system_time(state).toFixed(1)} days."
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
        sc.datum(
          [ { 'x': system_time(job), 'y': queue_pct(job) / 100, 'r': process_time(job) } ]
        )
        .call(scatter))

    local_dispatch.on('finished.legend',
      (job) ->
        leg.datum([
          "Last job lead time: #{system_time(job).toFixed(1)} days"
          "% queue time: #{(queue_time(job)/system_time(job) * 100).toFixed(0)}%"
          "Avg % queue time: #{avg_queue_pct(state).toFixed(0)}%"
          "Jobs completed: #{finished(state)}"
          "Total Cost of Delay: $#{(avg_system_time(state) * finished(state) * 100).toFixed(0)}"
          "Elapsed time: #{(dur(state['start_time'],now(state)) / 60 / 60 / 24).toFixed(1)} days"
        ])
        .call(lc))

    local_dispatch.on('finished.log',
      (job) ->
        log "Finished job number #{finished(state)}! That job took #{process_time(job)} days! It's been in the system for #{system_time(job)} days, though. That's #{queue_pct(job).toFixed(0)}% queue time."
        local_dispatch.update(state))
  
    local_dispatch.on('idle.log',
      () ->
         log "Nothing for me to do... guess I'll take a nap." unless state['paused']?))
