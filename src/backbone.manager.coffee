((Backbone, _, $, window) ->
  managers = []
  managerQueue = _.extend {}, Backbone.Events
  onloadUrl = window.location.href

  cachedParamMatcher = /[:*]([^(:)/]+)/g
  cachedOptionalMatcher = /\(.*\)/g

  currentManager = null

  # Manager(router) - router will be where the history navigation is pushed through
  #
  #  When state change is triggered:
  #    - router navigate occurs if the state has an url
  #    - appropriate pre events (load/transition) are triggered, both generic and state specific
  #    - make call to method
  #    - appropriate post events (load/transition) are triggered, both generic and state specific
  #
  #  Triggered Events:
  #    load                - incoming page load call for any state
  #    load:[state] (params) - incoming page load call for the [state]
  #
  #    transition          - incoming transition call for all states
  #    transition:[state]  - incoming transition call for the [state]
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
    #   'transition:users': 'showAlert'
    # }
    events: {}

    constructor: (router, options) ->
      managers.push @
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
          templateUrl = stateOptions.url.replace cachedOptionalMatcher, '' # drop all '()'s for the urlAsTemplate
          stateOptions._urlAsTemplate = _.template templateUrl, null, {interpolate: cachedParamMatcher}
          stateOptions._urlAsRegex = @router._routeToRegExp stateOptions.url

          # Register the urls into the router
          @router.route stateOptions._urlAsRegex, stateKey, =>
            @_routeCallbackChooser stateKey, stateOptions, Array.apply(null, arguments)
            return

        # Start listening for our state transition calls
        @listenTo managerQueue, stateKey, (params, transitionOptions) =>
          @_handleTransitionCallback stateKey, stateOptions, params, transitionOptions
          return
      return

    _routeCallbackChooser: (stateKey, stateOptions, params) ->

      # Only run loadCallback if this is truly the very first callback from the pageload popstate
      # In other cases, Backbone.history has already potentially changed the url for router nav,
      # so we check against it
      if onloadUrl and @_getWindowHref() is onloadUrl # todo: verify this works cross browser & w/ hash
        @_handleLoadCallback stateKey, stateOptions, params
      else
        @_handleTransitionCallback stateKey, stateOptions, params, {}, historyHasUpdated = true

      onloadUrl = null
      return

    _handleLoadCallback: (stateKey, stateOptions, params) ->
      currentManager = @

      if stateOptions.loadMethod
        @trigger 'load'
        @trigger 'load:'+stateKey, params

        @[stateOptions.loadMethod].apply this, params
      return

    # Reached in two ways:
    #  1) Callback from router route handle
    #    a) params is an array from the route callback
    #  2) bb-state change callback
    #    a) params is what the user has provided declaratively, or it's parsed from the link url
    #
    # Anytime params is an array, its last value will be always assumed to be queryParams string
    _handleTransitionCallback: (stateKey, stateOptions, params, transitionOptions = {}, historyHasUpdated = false) ->
      transitionOptions.navigate ?= true

      if currentManager and currentManager isnt @
        currentManager.trigger 'exit'
      currentManager = @

      @trigger 'transition'
      @trigger 'transition:'+stateKey

      if stateOptions.url

        # params is an array when:
        #   1) It comes from a route callback
        #   2) Is passed as array in bb-route directive
        #   3) Is interpolated from a link with a url defined
        if params instanceof Array

          paramsObject = _.object stateOptions._urlParams, params

          queryParams = _.last params

          # Perform the opposite of routes hash and fill in url parameters with data
          url = stateOptions._urlAsTemplate paramsObject
          if queryParams
            url += '?'+queryParams

          if not historyHasUpdated and transitionOptions.navigate
            @router.navigate url

          data = _.map _.initial(params), String # Drop the last value, representing the queryParams
          data.push queryParams                  # and now re-add, avoids casting queryParam null to string

        else if params instanceof Object # params is allowed to be an object for bb-state directives

          # Perform the opposite of routes hash and fill in url parameters with data
          url = stateOptions._urlAsTemplate params

          if not historyHasUpdated and transitionOptions.navigate
            @router.navigate url

          data = @router._extractParameters stateOptions._urlAsRegex, url # Use router to guarantee param order

        else
          throw new Error 'Params are only supported as an object or array if state.url is defined'

        options =
          url: url
        data.push options
      else
        # non-url driven states mean we pass data right through
        data = params

      @[stateOptions.transitionMethod].apply this, data
      return

    _parseEvents: ->
      _.each _.keys(@events), (eventName) =>
        @on eventName, @[@events[eventName]]
        return
      return

    _parseStateFromUrl: (url) ->
      stateKey = _.find _.keys(@states), (stateKey) => @states[stateKey]._urlAsRegex?.test(url)

      if stateKey
        data = @router._extractParameters @states[stateKey]._urlAsRegex, url

        return {
          state: stateKey
          params: data
        }

      return

    # for test stubs
    _getWindowHref: -> window?.location.href

    @go: (state, params, transitionOptions) ->
      unless params
        params = []
      managerQueue.trigger state, params, transitionOptions

    # a simple string w/o '/' will be treated as relative, just like anchor hrefs
    @goByUrl: (url, transitionOptions) ->
      urlParser = document.createElement 'a'
      urlParser.href = url
      path = urlParser.pathname.replace(/^\//, '')+urlParser.search

      parsedUrl = null
      _.find managers.slice().reverse(), (manager) -> return parsedUrl = manager._parseStateFromUrl(path)

      if parsedUrl
        state = parsedUrl.state
        params = parsedUrl.params
      else
        state = '*'
        params = [path]

      Manager.go state, params, transitionOptions

    @extend: Backbone.Model.extend # can't access Backbone's closure-scoped `extend` directly

    @config: {} # For the future

  Backbone.Manager = Manager

  _watchForStateChange = (event) ->
    unless event.isDefaultPrevented()
      $target = $ event.currentTarget
      stateAttr = $target.attr 'data-bb-state'
      transitionOptions = $target.attr('data-bb-options') || '{}'
      event.preventDefault()

      if stateAttr is ''
        Manager.goByUrl event.currentTarget.href, JSON.parse(transitionOptions)
      else

        # parse the passed info
        stateInfo = stateAttr.split('(', 2)
        state = stateInfo[0]
        params = []

        if stateInfo.length > 1 and stateInfo[1].length > 2 # basically if there's anything in the ()'s
          params = JSON.parse(stateInfo[1].slice 0, stateInfo[1].indexOf(')'))

        if params instanceof Array
          params.push null # this represents the query params value to the callback, which routers always append now

      managerQueue.trigger state, params, JSON.parse(transitionOptions)
    return

  $(window.document).on 'click', 'a[data-bb-state]', (event) -> _watchForStateChange event

  `/* gulp-strip-release */`
  Backbone.Manager._testAccessor =
    overrideOnloadUrl: (override) -> onloadUrl = override
    managers: managers
    managerQueue: managerQueue
    _watchForStateChange: _watchForStateChange
  `/* end-gulp-strip-release */`
  return
)(Backbone, _, $, window)
