barchart = () ->
  barwidth = 120
  labels  = []
  width = 0
  height = 0
  ymax = 30
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
      x = d3.scale.linear().domain([0,d.length]).range([0,frame.width])
      y = d3.scale.linear().domain([0,ymax]).range([frame.height, 0]).nice()

      svg = d3.select(this).selectAll('svg').data([d])

      xaxis = d3.svg.axis()
        .scale(x)
        .orient('bottom')
        .tickSize(0)
        .tickFormat('')
    
      yaxis = d3.svg.axis()
        .scale(y)
        .orient('left')
        .tickFormat(d3.format('.2s'))
    
      genter = svg.enter().append('svg').append('g')
        .attr('class','frame')
      genter.append('g')
        .attr('class','x axis')
        .attr('transform',"translate(0,#{frame.height})")
        .call(xaxis)
      genter.append('g').attr('class','y axis')
        .call(yaxis)
      genter.append('g').attr('class','chart')
      
      genter
        .attr('transform',"translate(#{margin.left},#{margin.top})")
        .attr('height',frame.height)
        .attr('width',frame.width)
    
      g = svg.select('.frame')

      xlabels = g.selectAll('.xlabel').data(d)

      xlabels.enter()
        .append('svg:text')
        .attr('class','xlabel')
        .attr('x', (d,i) -> x(i) + barwidth )
        .attr('y', frame.height + 12)
        .attr('dx', -barwidth/2)
        .attr('text-anchor', 'middle')
        .text((d,i) -> labels[i])
    
      bars = g.select('.chart').selectAll('.bar')
        .data(d)

      bars.enter()
        .append('rect')
        .attr('class',(d,i) -> "bar bar#{i}")
        .attr('x',(d,i) -> x(i))
        .attr('width',barwidth)

      bars
        .transition()
        .delay(0)
        .duration(120)
        .attr('height',(d) -> frame.height - y(d))
        .attr('y',y))

  my.labels = (value) ->
    return labels if !value?
    labels = value
    return my

  my.height = (value) ->
    return height if !value?
    height = value
    return my

  my.width = (value) ->
    return width if !value?
    width = value
    return my

  my.ymax = (value) ->
    return ymax if !value?
    ymax = value
    return my

  my.margin = (value) ->
    return margin if !value?
    margin = value
    return my

  return my


