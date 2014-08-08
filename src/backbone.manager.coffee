((Backbone, _, $, window) ->
  managerQueue = _.extend {}, Backbone.Events
  onloadUrl = window.location.href

  cachedParamMatcher = /[:*]([^:)/]+)/g
  cachedPathSegmentMatcher = /([^/]+)/g

  # Manager(router) - router will be where the history navigation is pushed through
  #
  #  When state change is triggered:
  #    - router navigate occurs if the state has an url
  #    - appropriate pre events (load/transition) are triggered, both generic and state specific
  #    - make call to method
  #    - appropriate post events (load/transition) are triggered, both generic and state specific
  #
  #  Triggered Events:
  #    pre-load                 - indicates incoming page load call for all states
  #    pre-load:[state] (args)  - indicates incoming page load call for the state
  #    post-load                - indicates incoming page load call completed for all states
  #    post-load:[state] (args) - indicates incoming page load call completed for the state
  #
  #    pre-transition          - indicates incoming transition call for all states
  #    pre-transition:[state]  - indicates incoming transition call for the state
  #    post-transition         - indicates transition call completed for all states
  #    post-transition:[state] - indicates transition call completed for the state
  #
  class Manager
    # state structure:
    # {
    #   'users': {
    #     url: 'users/:id' (optional)
    #     loadMethod: 'goUser' (optional) # functions like router, will be called with goUser({id: 1})
    #     transitionMethod: 'moveToUser'
    #   }
    # }
    #
    #
    states: {}

    # event structure based on defined Manager triggered events
    # {
    #   'pre-transition:users': 'showAlert'
    # }
    events: {}

    constructor: (router, options) ->
      @router = router
      _.extend @, Backbone.Events
      @_parseStates()
      @_parseEvents()
      @initialize options
      return

    # Empty by default. Override with custom logic
    initialize: ->

    _parseStates: ->
      _.each _.keys(@states), (stateKey) =>
        stateOptions = @states[stateKey]

        unless stateOptions.transitionMethod
          throw new Error stateKey+' needs transitionMethod definitions'

        if stateOptions.url
          if _.isRegExp stateOptions.url
            throw new Error stateKey+' is not allowed to have a RegExp url'

          stateOptions._urlParams = while matches = cachedParamMatcher.exec(stateOptions.url)
            matches[1]
          stateOptions._urlAsTemplate = _.template stateOptions.url, null, {interpolate: cachedParamMatcher}
          stateOptions._urlAsRegex = @router._routeToRegExp stateOptions.url

          # Register the urls into the router
          @router.route stateOptions._urlAsRegex, stateKey, =>
            @_routeCallbackChooser stateKey, stateOptions, Array.apply(null, arguments)
            return

        # Start listening for our state transition calls
        @listenTo managerQueue, stateKey, (args) =>
          @_handleTransitionCallback stateKey, stateOptions, args
          return
      return

    _routeCallbackChooser: (stateKey, stateOptions, args) ->

      # Only run loadCallback if this is truly the very first callback from the pageload popstate
      # In other cases, Backbone.history has already potentially changed the url for router nav,
      # so we check against it
      if onloadUrl and @_getWindowHref() is onloadUrl # todo: verify this works cross browser & w/ hash
        @_handleLoadCallback stateKey, stateOptions, args
      else
        @_handleTransitionCallback stateKey, stateOptions, args, historyHasUpdated = true

      onloadUrl = null
      return

    _handleLoadCallback: (stateKey, stateOptions, args) ->
      if stateOptions.loadMethod
        @trigger 'pre-load'
        @trigger 'pre-load:'+stateKey, args
        @[stateOptions.loadMethod].apply this, args
        @trigger 'post-load:'+stateKey, args
        @trigger 'post-load'
      return

    # Reached in two ways:
    #  1) Callback from router route handle
    #    a) args is an array from the route callback
    #  2) bb-state change callback
    #    a) args is what the user has provided declaratively, or it's parsed from the link url
    #
    # Anytime args is an array, its last value will be always assumed to be queryParams string
    _handleTransitionCallback: (stateKey, stateOptions, args, historyHasUpdated = false) ->
      @trigger 'pre-transition'
      @trigger 'pre-transition:'+stateKey

      if stateOptions.url
        # args is an array when:
        #   1) It comes from a route callback
        #   2) Is passed as array in bb-route directive
        #   3) Is interpolated from a link with a url defined
        if args instanceof Array

          argsObject = _.object stateOptions._urlParams, args

          # Perform the opposite of routes hash and fill in url parameters with data
          url = stateOptions._urlAsTemplate argsObject

          unless historyHasUpdated
            @router.navigate url

          data = _.map _.initial(args), String # Drop the last value, representing the queryParams
          data.push _.last(args)               # and now re-add, avoids casting queryParam null to string

        else if args instanceof Object # args is allowed to be an object for bb-state directives

          # Perform the opposite of routes hash and fill in url parameters with data
          url = stateOptions._urlAsTemplate args

          unless historyHasUpdated
            @router.navigate url

          data = @router._extractParameters stateOptions._urlAsRegex, url # Use router to guarantee param order
        else
          throw new Error 'Args are only supported as an object or array if state.url is defined'

        options =
          url: url
        data.push options
      else
        # non-url driven states mean we pass data right through
        data = args

      @[stateOptions.transitionMethod].apply this, data

      @trigger 'post-transition:'+stateKey
      @trigger 'post-transition'
      return

    _parseEvents: ->
      _.each _.keys(@events), (eventName) =>
        @on eventName, @[@events[eventName]]
        return
      return

    # for test stubs
    _getWindowHref: -> window?.location.href

    @go: (state, args) ->
      managerQueue.trigger state, args

    @extend: Backbone.Model.extend # todo: Be smarter about this later

    @config:
      # Expose in config to allow override
      # Expected to return {state: 'state', args:[]}
      urlToStateParser: (urlPath) ->
        stateObj =
          state: ''
          args: []
        segments = while matches = cachedPathSegmentMatcher.exec(urlPath)
          matches[1]

        _.each segments, (segment, i) ->
          if i % 2
            stateObj.args.push segments[i]
            stateObj.state += 'detail'
          else
            stateObj.state += segments[i]

          unless i is segments.length-1
            stateObj.state += '.'

        stateObj

  Backbone.Manager = Manager

  _watchForStateChange = (event) ->
    unless event.isDefaultPrevented()
      stateAttr = $(event.target).attr('data-bb-state')
      event.preventDefault()

      if stateAttr is ''

        # use convention to find state
        urlParser = document.createElement 'a'
        urlParser.href = event.target.href
        parsed = Backbone.Manager.config.urlToStateParser urlParser.pathname

        if managerQueue._events[parsed.state]
          state = parsed.state
          args = parsed.args
          args.push urlParser.search # Add query params, like the routers do # todo strip '?'
        else
          state = '*'
          args = [urlParser.pathname]
      else

        # parse the passed info
        stateInfo = stateAttr.split('(', 2)
        state = stateInfo[0]
        args = JSON.parse(stateInfo[1].slice 0, stateInfo[1].indexOf(')'))

        if args instanceof Array
          args.push null # this represents the query params value to the callback, which routers always append now

      managerQueue.trigger state, args
    return

  $(window.document).on 'click', 'a[data-bb-state]', (event) -> _watchForStateChange event

  `/* gulp-strip-release */`
  Backbone.Manager._testAccessor =
    overrideOnloadUrl: (override) -> onloadUrl = override
    managerQueue: managerQueue
    _watchForStateChange: _watchForStateChange
  `/* end-gulp-strip-release */`
  return
)(Backbone, _, $, window)
