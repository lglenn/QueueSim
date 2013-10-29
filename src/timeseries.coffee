timeseries = () ->
  height = 400
  width = 600
  xmax = 20
  ymax = 30
  margin =
    left: 20
    top: 20
    right: 20
    bottom: 20
  y = d3.scale.linear()
  x = d3.scale.linear()
  yaxis = d3.svg.axis().scale(y).orient('left')
  xaxis = d3.svg.axis().scale(x).orient('bottom')
  data = []

  line = d3.svg.line()
   .interpolate('basis')
   .x((d,i) -> x(i))
   .y((d,i) -> y(d))

  my = (selection) ->
    selection.each((d) ->

     data.push(d)

     canvas =
       height: height - margin.top - margin.bottom
       width: width - margin.left - margin.right

     svg = d3.select(this).selectAll('svg').data([data])

     s = svg.enter()
       .append('svg')

     s
       .append("defs").append("clipPath")
       .attr("id", "clip")
       .append("rect")
       .attr("width", canvas.width - 10)
       .attr("height", canvas.height)
       .attr('transform','translate(10)')

     frame = s
       .append('svg').append('g')
       .attr('class','frame')
       .attr('transform',"translate(#{margin.left},#{margin.top})")
       .attr('height',canvas.height)
       .attr('width',canvas.width)
       .attr('border','1px solid red')

     frame.append('g').attr('class','y axis')
     frame.append('g').attr('class','x axis')
     frame.append('g').attr('class','chart')
       .attr('clip-path', 'url(#clip)')
       .append('path')
       .attr('class','fooxy')

     x.domain([0,xmax]).range([0,canvas.width])
     y.domain([0,ymax]).range([canvas.height,0])

     svg.attr('height',height).attr('width',width)

     frame = svg.select('.frame')

     frame.select('.y.axis')
       .call(yaxis)

     frame.select('.x.axis')
       .attr('transform',"translate(0,#{canvas.height})")
       .call(xaxis)

     data.push(Math.random())

     frame.select('.chart').select('path')
       .style('fill','none')
       .style('stroke','black')
       .attr('transform',null)
       .attr('d',line)
       .transition()
       .duration(750)
       .ease('linear')
       .attr('transform',"translate(#{x(-1)})")

     data.shift()
         
    )

   my.ymax = (value) ->
    return ymax if !value?
    ymax = value
    my

   my.xmax = (value) ->
    return xmax if !value?
    xmax = value
    my

  my
