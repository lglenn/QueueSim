legend = () ->
  height = 0
  width = 0
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
      svg = d3.select(this).selectAll("svg").data([d])
        .attr('height',height)
        .attr('width',width)
      svg.enter().append("svg").append("g")
        .attr('class','frame')
        .attr('height',frame.height)
        .attr('width',frame.width)
        .attr('transform',"translate(#{margin.left},#{margin.top})")

      svg.select('.frame').selectAll('text')
        .data(d)
        .enter()
        .append('svg:text')
        .attr('y',(d,i) -> 50 + (i*20))
        .attr('x',30)
        .attr("text-anchor", "left")
        .attr('class','legend')

      svg.selectAll('text')
        .text(String))

  my.height = (value) ->
    return height if !value?
    height = value
    my

  my.width = (value) ->
    return width if !value?
    width = value
    my

  my.margin = (value) ->
    return margin if !value?
    margin = value
    my

  return my
  

