# Work at a given rate
worker = (capacity,mean_size,state,dispatcher,cb) ->
  job = null
  myworker = () ->
    if job?
      job.done(state.now())
      state.system_time(job.system_time())
      state.size(job.size())
      dispatcher.finished(job)
      job = null
    if state.queue_length() > 0
      state.paused(null)
      job = state.dequeue_job()
      job.size(random_int(mean_size))
      job.started(state.now())
      state.queue_time(job.queue_time())
      dispatcher.started()
      t = (job.size() / capacity)
    else
      dispatcher.idle()
      state.paused(1)
      t = 0
    cb(t,myworker)
  myworker()

