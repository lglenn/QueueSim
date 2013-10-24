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

