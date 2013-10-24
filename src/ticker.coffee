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
