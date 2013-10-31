timeseries = () ->
  height = 400
  width = 600
  xmax = 20
  ymax = 30
  margin =
    left: 40
    top: 20
    right: 40
    bottom: 20
  y = d3.scale.linear()
  x = d3.scale.linear()
  yaxis = d3.svg.axis().scale(y).orient('left')
  xaxis = d3.svg.axis().scale(x).orient('bottom')
  period = 10
  points = []
  data = []

  line = d3.svg.line()
   .interpolate('basis')
   .x((d) -> x(d.x))
   .y((d) -> y(d.y))

  pointilize = (datum) ->
    points.push(datum)
    points.shift() if points.length > period
    sum = 0
    sum += n for n in points
    sum / points.length

  my = (selection) ->
    selection.each((d) ->

     data.push({ x: pointilize(d.x), y: d.y})

     canvas =
       height: height - margin.top - margin.bottom
       width: width - margin.left - margin.right

     enter = d3.select(this)
       .selectAll('svg')
       .data([0])
       .enter()
       .append('svg')
       .attr('height',height)
       .attr('width',width)

     enter.append('defs')
       .append('clipPath')
       .attr('id', 'clip')
       .append('rect')
       .attr('width', canvas.width)
       .attr('height', canvas.height)

     newframe = enter.append('g')
       .attr('class','frame')
       .attr('transform',"translate(#{margin.left},#{margin.top})")
       .attr('height',canvas.height)
       .attr('width',canvas.width)

     newframe.append('g').attr('class','y axis')
     newframe.append('g').attr('class','x axis')
     newframe.append('g').attr('class','chart')
       .attr('clip-path', 'url(#clip)')
       .append('path')
       .style('fill','none')
       .style('stroke','steelblue')
       .style('stroke-width','2')

     frame = d3.select(this).select('.frame')

     x.domain([d.x - xmax, d.x + 1]).range([0,canvas.width])
     y.domain([0,ymax]).range([canvas.height,0])

     frame.select('.y.axis')
       .call(yaxis)

     frame.select('.x.axis')
       .attr('transform',"translate(0,#{canvas.height})")
       .call(xaxis)

     data.shift() if data.length >= xmax

     frame.select('.chart').select('path')
       .attr('transform',null)
       .attr('d',line(data))
       .transition()
       .duration(750)
       .ease('cubic')
       .attr('transform',"translate(#{if data.length >= xmax then x(-1) else 0})")
    )

   my.margin = (value) ->
     return margin if !value?
     margin = value
     my

   my.height = (value) ->
     return height if !value?
     height = value
     my

   my.width = (value) ->
     return width if !value?
     width = value
     my

   my.ymax = (value) ->
    return ymax if !value?
    ymax = value
    my

   my.xmax = (value) ->
    return xmax if !value?
    xmax = value
    my

  my
