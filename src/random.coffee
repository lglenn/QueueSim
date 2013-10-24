random =

  # Generates values from the exponential distribution with rate λ
  exponential:

    with_rate: (λ) ->
      Math.log(1-Math.random())/(-1 * λ)

    with_mean: (μ) ->
      random.exponential.with_rate(1/μ)
