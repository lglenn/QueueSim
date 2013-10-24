scatterchart = () ->
  height = 0
  width = 0
  x_max = 30
  c_max = 20
  fade_time = 120
  max_radius = 40
  x_tick_format = d3.format("2s")
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
      x = d3.scale.linear().domain([0,x_max]).range([0,frame.width])
      y = d3.scale.linear().domain([0,1]).range([frame.height, 0]).nice()
      c = d3.scale.sqrt().domain([0,c_max]).range([0,max_radius]).nice()

      yaxis = d3.svg.axis()
        .scale(y)
        .orient("left")
        .tickFormat((d) -> "#{d * 100}%")
    
      xaxis = d3.svg.axis()
        .scale(x)
        .orient("bottom")
        .tickSize(0)
        .tickFormat(x_tick_format)
    
      svg = d3.select(this).selectAll('svg').data([d])
      genter = svg.enter().append('svg').append('g')
      genter.append('g').attr('class','x axis')
      genter.append('g').attr('class','y axis')
      genter.append('g').attr('class','chart')

      genter
        .attr('class','frame')
        .attr('transform',"translate(#{margin.left},#{margin.top})")
        .attr('width',frame.width)
        .attr('height',frame.height)
    
      fr = svg.select('.frame')

      fr.select('.y.axis')
        .call(yaxis)
    
      fr.select('.x.axis')
        .attr('transform',"translate(0,#{frame.height})")
        .call(xaxis)
    
      circle = fr.select('.chart').append('circle')
        .data(d)
        .attr('r',0)
        .attr('cy',(d) -> y(d['y']))
        .attr('cx',(d) -> x(d['x']))
        .transition()
        .delay(0)
        .duration(fade_time)
        .attr('r',(d) -> c(d['r']))
        .attr('class','scatterplot'))

  my.x_format = (value) ->
    return x_tick_format if !value?
    x_tick_format = value
    return my

  my.height = (value) ->
    return height if !value?
    height = value
    return my

  my.width = (value) ->
    return width if !value?
    width = value
    return my

  my.x_max = (value) ->
    return x_max if !value?
    x_max = value
    return my

  my.c_max = (value) ->
    return c_max if !value?
    c_max = value
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


