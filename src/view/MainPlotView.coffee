R.create "MainPlotView",
  propTypes:
    fn: C.Fn

  getLocalMouseCoords: ->
    bounds = @fn.bounds
    rect = @getDOMNode().getBoundingClientRect()
    x = util.lerp(UI.mousePosition.x, rect.left, rect.right, bounds.xMin, bounds.xMax)
    y = util.lerp(UI.mousePosition.y, rect.bottom, rect.top, bounds.yMin, bounds.yMax)
    return {x, y}

  changeSelection: ->
    {x, y} = @getLocalMouseCoords()

    rect = @getDOMNode().getBoundingClientRect()
    bounds = @fn.bounds
    pixelWidth = (bounds.xMax - bounds.xMin) / rect.width

    found = null
    for childFn in @fn.childFns
      exprString = childFn.getExprString("x")
      fnString = "(function (x) { return #{exprString}; })"

      fn = util.evaluate(fnString)

      distance = Math.abs(y - fn(x))
      if distance < config.hitTolerance * pixelWidth
        found = childFn

    UI.selectChildFn(found)

  startPan: (e) ->
    originalX = e.clientX
    originalY = e.clientY
    originalBounds = {
      xMin: @fn.bounds.xMin
      xMax: @fn.bounds.xMax
      yMin: @fn.bounds.yMin
      yMax: @fn.bounds.yMax
    }

    rect = @getDOMNode().getBoundingClientRect()
    xScale = (originalBounds.xMax - originalBounds.xMin) / rect.width
    yScale = (originalBounds.yMax - originalBounds.yMin) / rect.height

    UI.dragging = {
      cursor: config.cursor.grabbing
      onMove: (e) =>
        dx = e.clientX - originalX
        dy = e.clientY - originalY
        @fn.bounds = {
          xMin: originalBounds.xMin - dx * xScale
          xMax: originalBounds.xMax - dx * xScale
          yMin: originalBounds.yMin + dy * yScale
          yMax: originalBounds.yMax + dy * yScale
        }
    }

    util.onceDragConsummated e, null, =>
      @changeSelection()

  handleMouseDown: (e) ->
    return if e.target.closest(".PointControl")
    UI.preventDefault(e)
    @startPan(e)

  handleWheel: (e) ->
    e.preventDefault()

    {x, y} = @getLocalMouseCoords()

    bounds = @fn.bounds

    scaleFactor = 1.1
    scale = if e.deltaY > 0 then scaleFactor else 1/scaleFactor

    @fn.bounds = {
      xMin: (bounds.xMin - x) * scale + x
      xMax: (bounds.xMax - x) * scale + x
      yMin: (bounds.yMin - y) * scale + y
      yMax: (bounds.yMax - y) * scale + y
    }


  renderPlot: (curve, style) ->
    exprString = curve.getExprString("x")
    fnString = "(function (x) { return #{exprString}; })"
    return R.PlotCartesianView {
      bounds: @fn.bounds
      fnString
      style
    }


  render: ->
    R.div {className: "MainPlot", onMouseDown: @handleMouseDown, onWheel: @handleWheel},
      R.div {className: "PlotContainer"},
        # Grid
        R.GridView {bounds: @fn.bounds}

        # Child Fns
        @fn.childFns.map (childFn) =>
          @renderPlot(childFn, config.style.default)

        # Main
        @renderPlot(@fn, config.style.main)

        if UI.selectedChildFn
          @renderPlot(UI.selectedChildFn, config.style.selected)

        if UI.selectedChildFn
          R.TransformedFnControlsView {
            transformedFn: UI.selectedChildFn
          }


R.create "TransformedFnControlsView",
  propTypes:
    transformedFn: C.TransformedFn

  snap: (value) ->
    container = @getDOMNode().closest(".PlotContainer")
    rect = container.getBoundingClientRect()

    bounds = @lookup("fn").bounds

    pixelWidth = (bounds.xMax - bounds.xMin) / rect.width

    {largeSpacing, smallSpacing} = util.canvas.getSpacing({
      xMin: bounds.xMin
      xMax: bounds.xMax
      yMin: bounds.yMin
      yMax: bounds.yMax
      width: rect.width
      height: rect.height
    })

    snapTolerance = pixelWidth * config.snapTolerance

    nearestSnap = Math.round(value / largeSpacing) * largeSpacing
    if Math.abs(value - nearestSnap) < snapTolerance
      value = nearestSnap
      digitPrecision = Math.floor(Math.log(largeSpacing) / Math.log(10))
      precision = Math.pow(10, digitPrecision)
      return util.floatToString(value, precision)

    digitPrecision = Math.floor(Math.log(pixelWidth) / Math.log(10))
    precision = Math.pow(10, digitPrecision)

    return util.floatToString(value, precision)

  handleTranslateChange: (x, y) ->
    @transformedFn.domainTranslate.valueString = @snap(x)
    @transformedFn.rangeTranslate.valueString  = @snap(y)

  handleScaleChange: (x, y) ->
    @transformedFn.domainScale.valueString = @snap(x - @transformedFn.domainTranslate.getValue())
    @transformedFn.rangeScale.valueString  = @snap(y - @transformedFn.rangeTranslate.getValue())

  render: ->
    R.span {},
      R.PointControlView {
        x: @transformedFn.domainTranslate.getValue()
        y: @transformedFn.rangeTranslate.getValue()
        onChange: @handleTranslateChange
      }
      R.PointControlView {
        x: @transformedFn.domainTranslate.getValue() + @transformedFn.domainScale.getValue()
        y: @transformedFn.rangeTranslate.getValue()  + @transformedFn.rangeScale.getValue()
        onChange: @handleScaleChange
      }




R.create "PointControlView",
  propTypes:
    x: Number
    y: Number
    onChange: Function

  getDefaultProps: -> {
    onChange: ->
  }

  handleMouseDown: (e) ->
    UI.preventDefault(e)

    container = @getDOMNode().closest(".PlotContainer")
    rect = container.getBoundingClientRect()

    UI.dragging = {
      onMove: (e) =>
        bounds = @lookup("fn").bounds

        x = (e.clientX - rect.left) / rect.width
        y = (e.clientY - rect.top)  / rect.height

        x = util.lerp(x, 0, 1, bounds.xMin, bounds.xMax)
        y = util.lerp(y, 1, 0, bounds.yMin, bounds.yMax)

        @onChange(x, y)
    }


  style: ->
    bounds = @lookup("fn").bounds
    top  = util.lerp(@y, bounds.yMin, bounds.yMax, 100, 0) + "%"
    left = util.lerp(@x, bounds.xMin, bounds.xMax, 0, 100) + "%"
    return {top, left}

  render: ->
    R.div {
      className: "PointControl"
      style: @style()
      onMouseDown: @handleMouseDown
    }