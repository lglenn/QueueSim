# Assign work at a given rate
assigner = (dispatch,cb) ->
  interarrival_time = () -> 1
  size = () -> 1

  my = () ->
    interval = interarrival_time()
    dispatch.newjob(interval,size())
    cb(interval,my)

  my.interarrival_time = (f) ->
    return interarrival_time if !f?
    interarrival_time = f
    return my

  my.size = (f) ->
    return size if !f?
    size = f
    return my

  my
