legend = () ->

  matrix = (list) ->
    ([el] for el in list)

  labels = matrix([])
  units = []

  my = (selection) ->
    selection.each((d) ->

      table = d3.select(this)
        .selectAll('table')
        .data([d])

      table
        .enter()
        .append('table')

      rows = table.selectAll('tr')
        .data(matrix(d))

      rows
        .enter()
        .append('tr')

      rows.selectAll('td.label')
        .data((d,i) -> labels[i])
        .enter()
        .append('td')
        .attr('class','label')
        .text((d) -> d)

      datacells = rows.selectAll('td.value')
        .data((d) -> d)

      datacells
        .enter()
        .append('td')
        .attr('class','value')
      
      datacells
        .text((d,i,j) -> units[j](d)))

  my.labels = (values) ->
    return labels if !values?
    labels = matrix(values)
    return my

  my.units = (values) ->
    return units if !values?
    units = values
    return my

  return my
