# Glossary:
# ρ : capacity utilization
# λ : average arrival rate

width = 2000
graph_width = 600
graph_height = 300
height = 400

margin =
  top: 20
  right: 30
  bottom: 20
  left: 30

hours_to_business_days = d3.scale.linear().domain([0,8]).range([0,1])
business_days_to_hours = d3.scale.linear().domain([0,1]).range([0,8])

clock = ticker(100).start()

dispatch = d3.dispatch('params','newjob')

random_int = (μ) ->
  Math.ceil(random.exponential.with_mean(μ))

d3.select("#params").selectAll('#go')
  .on("click",
    () ->
      mean_arrival_interval = parseFloat(d3.select('#params').select('#mean_arrival_rate').property('value')) * 8
      mean_job_size = parseFloat(d3.select('#params').select('#mean_job_size').property('value')) * 8
      team_capacity = parseFloat(d3.select('#params').select('#team_capacity').property('value'))
      dispatch.params(team_capacity,mean_job_size,mean_arrival_interval))

dispatch.on('params',
  (team_capacity,mean_job_size,mean_arrival_interval) ->
    # team capacity: person-hours of work / day
    # job size: person-hours
    # arrival rate: hours
    state = State(clock.time)
    id = random.exponential.with_mean(100)
    ρ = (mean_job_size * (1/mean_arrival_interval)) / team_capacity

    local_dispatch = d3.dispatch('update','started','finished','idle')

    assigner(dispatch,clock.setticktimeout)
      .mean_interval(mean_arrival_interval)
      .call()

    worker(team_capacity,mean_job_size,state,local_dispatch,clock.setticktimeout)

    log = (msg) ->
      console.log "day #{state.days().toFixed(1)}: #{msg}"
  
    d3.select('#viz').append('div')
      .attr('class','title')
      .text("#{Math.round(ρ * 100)}% Capacity Utilization")

    canvas = d3.select("#viz").append('svg').attr('width',width).attr('height',height)
      .append("g")
      .attr("transform","translate(30,30)")

    bc = canvas.append('g').attr('transform',"translate(30,0)")
    sc = canvas.append('g').attr('transform',"translate(#{graph_width + 50},0)")
    leg = canvas.append('g').attr('transform',"translate(#{(graph_width + 50) * 2},0)")
    leads = d3.select('body').append('div').attr('id','leadtimes')

    bars = barchart().height(graph_height).width(graph_width).margin(margin).labels(['Queue','Avg Jobs in System','Avg Lead Time','Avg Job Size'])
    scatter = scatterchart().height(graph_height).width(graph_width).margin(margin).fade_time(120)
    lc = legend().height(graph_height).width(graph_width/2).margin(margin)
    leadtime_chart = timeseries().height(250).width(1000).ymax(20).xmax(1000)

    bc.datum([0,0,0,0]).call(bars)
    sc.datum([]).call(scatter)
    leg.datum([0,0,0,0]).call(lc)
    leads.datum({x: 0, y: 0}).call(leadtime_chart)

    dispatch.on("newjob.#{id}",
      (arrival_interval) ->
        state.enqueue_job()
        state.arrival(arrival_interval)
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
  
    local_dispatch.on('finished.leadtimes',
      (job) ->
        leads.datum({ x: state.now(), y: hours_to_business_days(job.system_time())}).call(leadtime_chart))
        
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
        hours_to_business_days = d3.scale.linear().domain([0,8]).range([0,1])
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
          "Elapsed time: #{hours_to_business_days(state.now()).toFixed(1)} business days"
        ])
        .call(lc))

    local_dispatch.on('finished.log',
      (job) ->
        log "Finished job number #{state.finished()}! That job took #{job.process_time()} hours! It's been in the system for #{job.system_time()} hours, though. That's #{job.queue_pct().toFixed(0)}% queue time."
        local_dispatch.update(state))
  
    local_dispatch.on('idle.log',
      () ->
         log "Nothing for me to do... guess I'll take a nap." unless state.paused()?))
