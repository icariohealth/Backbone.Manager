expect = chai.expect

stubEventMethod = (method) ->
  cachedMethod = Backbone.Events[method]
  @sinon.stub Backbone.Events, method, ->
    cachedMethod.apply @, arguments

# Keep '@sinon' sandboxed to every test, use 'sinon' to bypass
beforeEach ->
  @sinon = sinon.sandbox.create()
afterEach ->
  @sinon.restore()

describe 'Backbone.Manager', ->
  describe 'go()', ->
    it 'should call the managerQueue with state change request', ->
      triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

      Backbone.Manager.go 'test', [1,2]

      expect(triggerStub).to.have.been.calledWith 'test', [1,2]

  describe 'config.urlToStateParser', ->
    it 'should build a simple state from simple plural url', ->
      stateObject = Backbone.Manager.config.urlToStateParser('/test')

      expect(stateObject.state).to.equal 'test'

    it 'should build a detail state from simple url with id', ->
      stateObject = Backbone.Manager.config.urlToStateParser('/test/1')

      expect(stateObject.state).to.equal 'test.detail'

    it 'should build a complex detail state from complex url with multiple ids', ->
      stateObject = Backbone.Manager.config.urlToStateParser('/testa/1/testb/2')

      expect(stateObject.state).to.equal 'testa.detail.testb.detail'

    it 'should return args with ids from url with multiple ids, in order', ->
      stateObject = Backbone.Manager.config.urlToStateParser('/a/1/b/2/c/3/d/4')

      expect(stateObject.args).to.eql ['1','2','3','4']

describe 'Backbone.Manager.prototype', ->
  beforeEach ->
    @router = new Backbone.Router()
  afterEach ->
    delete @router

  describe 'constructor', ->
    it 'should call initialize', ->
      initSpy = @sinon.spy Backbone.Manager.prototype, 'initialize'

      new Backbone.Manager @router

      expect(initSpy).to.have.been.called

  describe '_parseStates()', ->
    it "should throw error if transitionMethod for a state isn't defined", ->
      manager = Backbone.Manager.extend
        states:
          test: {}

      expect(-> new manager @router).to.throw /transitionMethod/

    it 'should listen for event related to state', ->
      cachedListenTo = Backbone.Events.listenTo
      listenToStub = @sinon.stub Backbone.Events, 'listenTo', ->
        cachedListenTo.apply @, arguments

      new (Backbone.Manager.extend
        states:
          test:
            transitionMethod: 'a'
            url: 'a/:a_id/b/:b_id'
      )(@router)

      expect(listenToStub).to.have.been.calledWith sinon.match.any, 'test', sinon.match.any

    context 'state url defined', ->
      it 'should throw error if url is regex', ->
        manager = Backbone.Manager.extend
          states:
            test:
              transitionMethod: 'a'
              url: /^(.*?)\/open$/

        expect(-> new manager @router).to.throw /not allowed to have a RegExp url/

      it 'should store the correct url params', ->
        manager = new (Backbone.Manager.extend
          states:
            test:
              transitionMethod: 'a'
              url: 'a/:a_id/b/:b_id'
        )(@router)

        expect(manager.states.test._urlParams).to.have.members ['a_id','b_id']

      it 'should build a url template able to replace params from object', ->
        manager = new (Backbone.Manager.extend
          states:
            test:
              transitionMethod: 'a'
              url: 'a/:a_id/b/:b_id'
        )(@router)

        obj =
          a_id: 1
          b_id: 2

        expect(manager.states.test._urlAsTemplate(obj)).to.equal 'a/1/b/2'

      it 'should set regex from url, built same as router', ->
        manager = new (Backbone.Manager.extend
          states:
            test:
              transitionMethod: 'a'
              url: 'a/:a_id/b/:b_id'
        )(@router)

        expect(manager.states.test._urlAsRegex+'').to.equal @router._routeToRegExp(manager.states.test.url)+''

      it 'should register regex url inside router', ->
        routeSpy = @sinon.spy @router, 'route'

        manager = new (Backbone.Manager.extend
          states:
            test:
              transitionMethod: 'a'
              url: 'a/:a_id/b/:b_id'
        )(@router)

        expect(routeSpy).to.have.been.calledWith manager.states.test._urlAsRegex

  describe '_routeCallbackChooser()', ->
    beforeEach ->
      Backbone.Manager._testAccessor.overrideOnloadUrl 'http://base.com'

    it 'should not call loadCallback if pageload url is different from current url', ->
      manager = new (Backbone.Manager.extend
        _getWindowHref: -> 'http://other.com'
      )(@router)

      loadCallbackStub = @sinon.stub manager, '_handleLoadCallback'
      @sinon.stub manager, '_handleTransitionCallback'

      manager._routeCallbackChooser '', {}

      expect(loadCallbackStub).to.not.have.been.called

    it 'should call transitionCallback if pageload url is different from current url', ->
      manager = new (Backbone.Manager.extend
        _getWindowHref: -> 'http://other.com'
      )(@router)

      transitionCallbackStub = @sinon.stub manager, '_handleTransitionCallback'

      manager._routeCallbackChooser '', {}

      expect(transitionCallbackStub).to.have.been.called

    it 'should call loadCallback if pageload url is current url, but only once', ->
      manager = new (Backbone.Manager.extend
        _getWindowHref: -> 'http://base.com'
      )(@router)

      loadCallbackStub = @sinon.stub manager, '_handleLoadCallback'
      @sinon.stub manager, '_handleTransitionCallback'

      manager._routeCallbackChooser()
      manager._routeCallbackChooser()

      expect(loadCallbackStub).to.have.been.calledOnce

  describe '_handleLoadCallback()', ->
    it "should not throw error if loadMethod for a state isn't defined", ->
      manager = new Backbone.Manager @router

      expect(-> manager._handleLoadCallback('', {})).not.to.throw Error

    it 'should trigger generic and specific pre-events in that order', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger')
      triggerSpy.withArgs 'pre-load'
      triggerSpy.withArgs 'pre-load:testState'

      manager._handleLoadCallback('testState', {loadMethod: 'test'})

      expect(triggerSpy.withArgs 'pre-load:testState').to.have.been.calledAfter triggerSpy.withArgs 'pre-load'

    it 'should trigger pre-event before callback', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger').withArgs 'pre-load'
      callbackSpy = @sinon.spy manager, 'test'

      manager._handleLoadCallback('testState', {loadMethod: 'test'})

      expect(triggerSpy).to.have.been.calledBefore callbackSpy

    it 'should trigger specific and generic post-events in that order', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger')
      triggerSpy.withArgs 'post-load'
      triggerSpy.withArgs 'post-load:testState'

      manager._handleLoadCallback('testState', {loadMethod: 'test'})

      expect(triggerSpy.withArgs 'post-load:testState').to.have.been.calledBefore triggerSpy.withArgs 'post-load'

    it 'should trigger post-event after callback', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger').withArgs 'post-load'
      callbackSpy = @sinon.spy manager, 'test'

      manager._handleLoadCallback('testState', {loadMethod: 'test'})

      expect(triggerSpy).to.have.been.calledAfter callbackSpy

  describe '_handleTransitionCallback()', ->
    it 'should trigger generic and specific pre-events in that order', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger')
      triggerSpy.withArgs 'pre-transition'
      triggerSpy.withArgs 'pre-transition:testState'

      manager._handleTransitionCallback('testState', {transitionMethod: 'test'})

      expect(triggerSpy.withArgs 'pre-transition:testState').to.have.been.calledAfter triggerSpy.withArgs 'pre-transition'

    it 'should trigger pre-event before callback', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger').withArgs 'pre-transition'
      callbackSpy = @sinon.spy manager, 'test'

      manager._handleTransitionCallback('testState', {transitionMethod: 'test'})

      expect(triggerSpy).to.have.been.calledBefore callbackSpy

    it 'should trigger specific and generic post-events in that order', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger')
      triggerSpy.withArgs 'post-transition'
      triggerSpy.withArgs 'post-transition:testState'

      manager._handleTransitionCallback('testState', {transitionMethod: 'test'})

      expect(triggerSpy.withArgs 'post-transition:testState').to.have.been.calledBefore triggerSpy.withArgs 'post-transition'

    it 'should trigger post-event after callback', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger').withArgs 'post-transition'
      callbackSpy = @sinon.spy manager, 'test'

      manager._handleTransitionCallback('testState', {transitionMethod: 'test'})

      expect(triggerSpy).to.have.been.calledAfter callbackSpy

    context 'state url defined', ->
      before ->
        @managerProto = Backbone.Manager.extend
          states:
            test:
              url: 'a/:id_1/b/:id_2/c/:id_3/d/:id_4'
              transitionMethod: 'test'
          test: ->

      context 'args is Array', ->
        it 'should maintain order from array into url', ->
          manager = new @managerProto @router

          navigateStub = @sinon.stub @router, 'navigate'

          manager._handleTransitionCallback 'test', manager.states.test, [1,2,3,4]

          expect(navigateStub).to.have.been.calledWith 'a/1/b/2/c/3/d/4'

        it 'should not fire navigate if historyHasUpdated', ->
          manager = new @managerProto @router

          navigateStub = @sinon.stub @router, 'navigate'

          manager._handleTransitionCallback 'test', manager.states.test, [1,2,3,4], historyHasUpdated = true

          expect(navigateStub).to.not.have.been.called

        it 'should hand correct args to callback in order, mimicking router params callback', ->
          manager = new @managerProto @router

          callbackSpy = @sinon.spy manager, 'test'

          manager._handleTransitionCallback 'test', manager.states.test, [1,2,3,4]

          expect(callbackSpy).to.have.been.calledWithExactly '1', '2', '3', '4', null, sinon.match.object

      context 'args is Object', ->
        before ->
          @argObj =
            id_2: 2
            id_4: 4
            id_1: 1
            id_3: 3

        it 'should maintain order from args in url', ->
          manager = new @managerProto @router

          navigateStub = @sinon.stub @router, 'navigate'

          manager._handleTransitionCallback 'test', manager.states.test, @argObj

          expect(navigateStub).to.have.been.calledWith 'a/1/b/2/c/3/d/4'

        it 'should maintain order from args in url', ->
          manager = new @managerProto @router

          navigateStub = @sinon.stub @router, 'navigate'

          manager._handleTransitionCallback 'test', manager.states.test, @argObj, historyHasUpdated = true

          expect(navigateStub).to.not.have.been.called

        it 'should hand correct args to callback in order', ->
          manager = new @managerProto @router

          callbackSpy = @sinon.spy manager, 'test'

          manager._handleTransitionCallback 'test', manager.states.test, @argObj

          expect(callbackSpy).to.have.been.calledWith '1', '2', '3', '4', null, sinon.match.object

  describe '_parseEvents()', ->
    it 'should bind to key as event, value as callback', ->
      cachedOn = Backbone.Events.on
      onStub = @sinon.stub Backbone.Events, 'on', ->
        cachedOn.apply @, arguments

      manager = new (Backbone.Manager.extend
        events:
          testEvent: 'testFunc'
        testFunc: ->
      )(@router)

      expect(onStub).to.have.been.calledWith 'testEvent', manager.testFunc

describe 'Backbone.Manager Closure Scope', ->
  describe '_watchForStateChange()', ->
    it 'should do nothing if event is marked preventDefault', ->
      triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

      Backbone.Manager._testAccessor._watchForStateChange {isDefaultPrevented: -> true}

      expect(triggerStub).to.not.have.been.called

    context 'no bb-state value', ->
      beforeEach ->
        @mockEvent =
          preventDefault: ->
          isDefaultPrevented: -> false
          target: $("<a x-bb-state='' href='http://a.com/a/1/b/2'/>")[0]

      it 'should trigger state based on convention if it exists', ->
        triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

        Backbone.Manager._testAccessor.managerQueue._events['a.detail.b.detail'] = {}
        Backbone.Manager._testAccessor._watchForStateChange @mockEvent
        delete Backbone.Manager._testAccessor.managerQueue._events['a.detail.b.detail']

        expect(triggerStub).to.have.been.calledWith 'a.detail.b.detail', ['1', '2']

      it 'should trigger the * state and pass the pathname if there are no matching states', ->
        triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

        Backbone.Manager._testAccessor._watchForStateChange @mockEvent

        expect(triggerStub).to.have.been.calledWith '*', ['/a/1/b/2']
