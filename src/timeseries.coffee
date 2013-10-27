timeseries = () ->
  height = 400
  width = 600
  x_max = 100
  y_max = 30
  margin =
    left: 20
    top: 20
    right: 20
    bottom: 20
  y = d3.scale.linear()
  x = d3.scale.linear()
  yaxis = d3.svg.axis().scale(y).orient('left')
  xaxis = d3.svg.axis().scale(x).orient('bottom')

  my = (selection) ->
    selection.each((d) ->

     canvas =
       height: height - margin.top - margin.bottom
       width: width - margin.left - margin.right

     svg = d3.select(this).selectAll('svg').data([d])
     frame = svg.enter()
       .append('svg').append('g')
       .attr('class','frame')
       .attr('transform',"translate(#{margin.left},#{margin.top})")
       .attr('height',canvas.height)
       .attr('width',canvas.width)
       .attr('border','1px solid red')
     frame.append('g').attr('class','y axis')
     frame.append('g').attr('class','x axis')
     frame.append('g').attr('class','chart')

     y.domain([0,y_max]).range([0,canvas.height])
     x.domain([0,x_max]).range([0,canvas.width])

     svg.attr('height',height).attr('width',width)

     frame = svg.select('.frame')

     frame.select('.y.axis')
       .call(yaxis)

     frame.select('.x.axis')
       .attr('transform',"translate(0,#{canvas.height})")
       .call(xaxis))
      
