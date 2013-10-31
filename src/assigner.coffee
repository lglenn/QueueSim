# Assign work at a given rate
assigner = (dispatch,cb) ->
  mean_interval = 8

  my = () ->
    interval = random_int(mean_interval)
    dispatch.newjob(interval)
    cb(interval,my)

  my.mean_interval = (value) ->
    return mean_interval if !value?
    mean_interval = value
    my

  my
