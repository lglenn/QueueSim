Job = () ->
  queued = null
  started = null
  size = 0
  done = null

  dur = (start,end) ->
    (end - start)
  
  my = () ->

  my.start_time = (start_time) ->
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
