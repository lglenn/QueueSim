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
  1/(avg(state['arrivals'])/1000)

avg_system_size = (state) ->
  # Little's law: avg jobs in system = avg arrival rate * avg time in system
  avg_arrival_rate(state) * avg_system_time(state)

dispatch = d3.dispatch('params','newjob')

# Assign work at a given rate
assigner = (arrival_rate,processing_rate) ->
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
      dispatcher.finished(state,job)
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
  dispatcher = null

  legends = [
    (d) -> "Last job lead time: #{d.toFixed(1)} days"
    (d) -> "% queue time: #{d.toFixed(0)}%"
    (d) -> "Avg % queue time: #{d.toFixed(0)}%"
    (d) -> "Jobs completed: #{d}"
    (d) -> "Total Cost of Delay: $#{d.toFixed(0)}"
    (d) -> "Elapsed time: #{d.toFixed(1)} days"
  ]

  my = (selection) ->
    selection.each((d) ->
      svg = d3.select(this).selectAll("svg").data([d])
      # Create the SVG if the selection isn't one (i.e. if it's an e.g. div)
      svg.enter().append("svg")
      g = svg.append("g")
        .attr('height',height)
        .attr('width',width)
      g.selectAll("text")
        .data([0..legends.length-1])
        .enter()
        .append("svg:text")
        .attr('y',(d,i) -> 100 + (i*30))
        .attr("text-anchor", "left")
        .attr("style", "font-size: 12; font-family: Helvetica, sans-serif")
        .text((d,i) -> legends[i](d))
      dispatcher.on('finished.legend',
        (state,job) ->
          g.selectAll("text").data([
            system_time(job)
            (queue_time(job)/system_time(job) * 100)
            avg_queue_pct(state)
            finished(state)
            avg_system_time(state) * finished(state) * 100
            dur(state['start_time'],now(state)) / 60 / 60 / 24
          ])
          .text((d,i) -> console.log("D: #{d}; I: #{i}"); legends[i](d))))

  my.height = (value) ->
    return height if !value?
    height = value
    my

  my.width = (value) ->
    return width if !value?
    width = value
    my

  my.dispatcher = (value) ->
    return dispatcher if !value?
    dispatcher = value
    my

  return my
  
assigner(1,1)

scatterchart = (svg,width,height,dispatch) ->
  height = 0
  width = 0
  dispatch = null
  max_lead = 30
  margin =
    top: 20
    right: 20
    bottom: 20
    left: 20

  my = (selection) ->
    selection.each((d) ->
      x = d3.scale.linear().domain([0,max_lead]).range([0,width - margin.left - margin.right])
      y = d3.scale.linear().domain([0, 1]).range([height - margin.top - margin.bottom, 0]).nice()
      c = d3.scale.linear().domain([0,8]).range([0,40]).nice()

      yaxis = d3.svg.axis()
        .scale(y)
        .orient("left")
        .tickFormat(d3.format("2s"))
    
      xaxis = d3.svg.axis()
        .scale(x)
        .orient("bottom")
        .tickSize(0)
        .tickFormat(d3.format("2s"))
    
      svg = d3.select(this).selectAll("svg").data([d])
      # Create the SVG if the selection isn't one (i.e. if it's an e.g. div)
      svg.enter().append("svg")

      svg.attr('height',height ).attr('width',width)

      canvas = svg.append("g")
        .attr('transform',"translate(#{margin.left},#{margin.top})")
    
      canvas.append("g")
        .attr("class", "y axis")
        .attr('transform',"translate(30,0)")
        .call(yaxis)
    
      canvas.append("g")
        .attr("class", "x axis")
        .attr("width",width)
        .attr('height',100)
        .attr('transform',"translate(30,#{height - margin.top - margin.bottom})")
        .call(xaxis)
    
      dispatch.on('finished.scatterchart',
        (state,job) ->
          canvas.append('circle')
            .attr('r',0)
            .attr('cy',y(queue_pct(job)/100))
            .attr('cx',x(system_time(job)))
            .attr('transform','translate(30,0)')
            .style('fill','#ff4444')
            .style('opacity',0.5)
            .style('stroke','black')
            .transition()
            .delay(0)
            .duration(120)
            .attr('r',c(process_time(job)))))

  my.height = (value) ->
    return height if !value?
    height = value
    return my

  my.width = (value) ->
    return width if !value?
    width = value
    return my

  my.dispatch = (value) ->
    return dispatch if !value?
    dispatch = value
    return my

  my.max_lead = (value) ->
    return max_lead if !value?
    max_lead = value
    return my

  return my

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
    .style('stroke','black')
    .style('fill',(d,i) -> colors[i])
    .attr('x',(d,i) -> x(i))
    .attr('y',height)
    .attr('width',barwidth)
    .attr('height',(d) -> d)
    .style('opacity',.5)

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
    d3.select('body').append('div').attr('class','.legend').style('border','1px solid red').call(legend()
      .height(graph_height)
      .width(graph_width/2)
      .dispatcher(local_dispatch))
    barchart(canvas,graph_width,graph_height,local_dispatch)
    canvas.append("g").attr('transform','translate(675,0)').call(scatterchart().height(graph_height).width(graph_width).dispatch(local_dispatch))

    worker(processing_rate,state,local_dispatch)

    dispatch.on("newjob.#{id}",
      (arrival,process) ->
        state['queue'].push {'queued': new Date(), 'size': process}
        incr(state['arrivals'],arrival)
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
