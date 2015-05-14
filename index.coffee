edgy= angular.module 'edgy',[]
edgy.directive 'viewer',($window)->
  replace: yes
  transclude: yes
  template: '<main ng-transclude></main>'
  controller: ($scope,$element)->
    $scope.zoom?= 8
    $scope.width?= 32
    $scope.height?= 48

    $scope.sync?= off
    $scope.color?= 'black'

    $scope.save= ->
      {width,height}= $scope

      svgElement= $element.find 'svg'
      div= angular.element('<div />').append $element.find('svg').clone yes
      div.find('svg').attr {width,height}
      div.find('rect').remove()
      div.find('clipPath').remove()
      div.find('g').removeAttr 'clip-path'

      image= new Image
      image.src= 'data:image/svg+xml;base64,'+btoa div[0].innerHTML
      image.onload= ->
        context= $window.document.createElement('canvas').getContext '2d'
        context.canvas.width= $scope.width
        context.canvas.height= $scope.height
        context.drawImage image,0,0
        $window.open context.canvas.toDataURL()

edgy.factory 'Sound',($window)->
  AudioContext= ($window.AudioContext or $window.webkitAudioContext)

  class Sound
    constructor: (url)->
      return this unless AudioContext?

      xhr= new XMLHttpRequest
      xhr.open 'GET',url,yes
      xhr.responseType= 'arraybuffer'
      xhr.send()
      xhr.onload= =>
        @pcm= new AudioContext
        @pcm.decodeAudioData xhr.response,(buffer)=>
          @source= buffer
    play: ->
      return this unless AudioContext?
      return if @coolTime?

      source= @pcm.createBufferSource();
      source.buffer= @source
      source.connect @pcm.destination
      source.start 0
      @coolTime= yes
      setTimeout (=> @coolTime= null),100

  Sound

edgy.factory 'Art',($window,$rootScope,Sound)->
  class Art extends HistoryJson
    constructor: (@svgElement)->
      super()

      @foreground= angular.element(@svgElement).find 'g'
      @putSound= new Sound 'data:audio/wav;base64,UklGRogBAABXQVZFZm10IBAAAAABAAEAIlYAACJWAAABAAgAZGF0YWQBAACAh4mLjpCSlJaYmpyeoKGjpaeoqqyqpaGcmJSQjIiEgH15e3l4dnRzcXBubGtrbW9xc3V2eHp7fX+BgoSFh4mKjI2PkZKUlZaWlpWVlZSUlJOTk5OSkpKSkZGRkJCQkI+Pj4+Ojo6Ojo6Ojo6Ojo6Ojo2NjY2NjY2NjY2MjIyMjIyMjIyLi4uKiomJiYiIh4eHhoaGhYWFhISEg4OFhISEg4ODgoKCgYGBgYGBgYGBgYGBgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgA=='

      @colors= []
      @position= {}

    remind: ->
      return if @coolTime
      @coolTime= yes
      $window.setTimeout (=> @coolTime= no),250

      {colors,position}= this
      @add {colors,position}

    update: (@width,@height,@zoom,@color,sync)->
      element= angular.element @svgElement

      element.attr {width,height}
      element.attr 
        'version': '1.1'
        'xmlns': 'http://www.w3.org/2000/svg'
        'xmlns:xlink': 'http://www.w3.org/1999/xlink'
        'shape-rendering': 'crispEdges'
        'viewBox': "0 0 #{@width} #{@height}"

      {width,height}= @svgElement.parentNode.getBoundingClientRect()
      scaleX= @width/ width* 100* @zoom
      scaleY= @height/ height* 100* @zoom
      element.css
        width: scaleX+'%'
        height: scaleY+'%'

      validColor= @oldColor? && @color?
      changedColor= validColor && @color isnt @oldColor
      if changedColor && sync
        @colors[@colors.indexOf @oldColor]= @color if @oldColor in @colors
      @oldColor= @color

      @remind() if changedColor && sync

    render: ->
      @foreground.empty()

      paths= {}
      for x,line of @position
        for y,i of line
          color= @colors[i]

          paths[color]?= ''
          paths[color]+= 'M'+x+','+y+'h1v1h-1Z'

      for color,d of paths
        path= $window.document.createElementNS 'http://www.w3.org/2000/svg','path'
        path.setAttributeNS null,'fill',color
        path.setAttributeNS null,'d',d

        @foreground.append angular.element path

      $rootScope.undo= =>
        @undo(true)
        @render()

      $rootScope.redo= =>
        @redo(true)
        @render()

      return

    stroke: (point,pointPrev)->
      return if (isNaN point.x) or (isNaN point.y)
      {x,y}= point

      if @color?
        @colors.push @color unless @color in @colors
        i= @colors.indexOf @color

      @put i,x,y

      if pointPrev?
        @put i,point.x,point.y for point in @getPoints point,pointPrev

      @putSound.play() if @color?
      @render()

    put: (i,x,y)->
      @position[x]?= {}
      if @color?
        @position[x][y]= i
      else
        delete @position[x][y]

    get: (point)->
      color= null

      i= @position[point.x]?[point.y]
      color= @colors[i] if i?

      color

    getPoints: (next,prev)->
      points= []

      i= 0
      {x,y}= next
      until x is prev.x and y is prev.y
        x++ if x< prev.x
        x-- if x> prev.x
        y++ if y< prev.y
        y-- if y> prev.y
        points.push {x,y}

        i++
        break if i>100

      points

    getPoint: (event,scope)->
      {x,y,width,height}= @getOffset event

      x= ~~(x/ width* scope.width)
      y= ~~(y/ height* scope.height)

      point= {x,y}

    getOffset: (event)->
      {layerX,layerY,offsetX,offsetY}= event
      {scrollTop,scrollLeft}= @svgElement.parentNode
      {width,height}= @svgElement.getBoundingClientRect()

      x= layerX ? offsetX
      x+= scrollLeft

      y= layerY ? offsetY
      y+= scrollTop

      offset= {x,y,width,height}

  Art

edgy.directive 'art',(Art,$window,$rootScope)->
  require: '^viewer'
  replace: yes
  template: '''
    <svg ng-attr-width="{{width}}" ng-attr-height="{{height}}">
      <defs>
        <pattern id="background" width="1" height="1" patternUnits="userSpaceOnUse">
          <path transform="scale(.25)" fill="rgba(0,0,0,0.05)" d="M0,0h1v1h-1ZM3,0h1v1h-1ZM2,1h2v1h-2ZM1,2h2v1h-2ZM0,3h2v1h-2Z"></path>
        </pattern>
      </defs>
      <rect id="canvas" fill="url(#background)" ng-attr-width="{{width}}" ng-attr-height="{{height}}"></rect>
      <clipPath id="clip">
        <use xlink:href="#canvas"/>
      </clipPath>
      <g clip-path="url(#clip)">
        
      </g>
    </svg>
  '''
  templateNamespace: 'svg'
  link: (scope,element,attrs)->
    art= new Art element[0]
    art.remind()

    scope.$watch ->
      {width,height,zoom,color,sync}= scope

      art.update width,height,zoom,color,sync
      art.render()
    ,true

    pointPrev= null
    element.on 'mousedown',(event)->
      return if event.which is 3
      event.preventDefault()

      point= art.getPoint event,scope
      art.stroke point
      pointPrev= point

    element.on 'mousemove',(event)->
      return unless pointPrev?

      point= art.getPoint event,scope
      art.stroke point,pointPrev
      pointPrev= point

    angular.element($window).on 'mouseup',(event)->
      return unless pointPrev?

      art.remind()

    angular.element($window).on 'mouseup',(event)->
      return unless pointPrev?

      point= art.getPoint event,scope
      art.stroke point,pointPrev if event.target is art.svgElement
      pointPrev= null

    element.on 'contextmenu',(event)->
      event.preventDefault()

      point= art.getPoint event,scope
      scope.$parent.color= art.get point
      scope.$parent.$apply()
