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

  describe 'goByUrl()', ->
    afterEach ->
      Backbone.Manager._testAccessor.managers.pop()

    it "should pass query params with the path", ->
      manager = Object.create Backbone.Manager.prototype
      Backbone.Manager._testAccessor.managers.push manager
      managerStub = @sinon.stub(manager, '_parseStateFromUrl')

      @sinon.stub Backbone.Manager, 'go'

      Backbone.Manager.goByUrl '/abc?a=b'

      expect(managerStub).to.have.been.calledWith 'abc?a=b'

    it 'should trigger pass parsed info from the manager to go', ->
      manager = Object.create Backbone.Manager.prototype
      @sinon.stub(manager, '_parseStateFromUrl').returns
        state: 'a.detail.b.detail'
        args: ['1', '2', '']
      Backbone.Manager._testAccessor.managers.push manager
      triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

      Backbone.Manager.goByUrl 'http://a.com/a/1/b/2'

      expect(triggerStub).to.have.been.calledWith 'a.detail.b.detail', ['1', '2', '']

    it 'should trigger the * state and pass the pathname if there are no matching states', ->
      manager = Object.create Backbone.Manager.prototype
      @sinon.stub(manager, '_parseStateFromUrl').returns undefined
      Backbone.Manager._testAccessor.managers.push manager

      triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

      Backbone.Manager.goByUrl 'http://a.com/a/1/b/2'

      expect(triggerStub).to.have.been.calledWith '*', ['a/1/b/2']

    it 'should trigger the lastly created matching manager first', ->
      manager1 = Object.create Backbone.Manager.prototype
      manager1Parse = @sinon.stub(manager1, '_parseStateFromUrl').returns
        state: 'a.detail.b.detail'
        args: ['1', '2', '']
      Backbone.Manager._testAccessor.managers.push manager1

      manager2 = Object.create Backbone.Manager.prototype
      @sinon.stub(manager2, '_parseStateFromUrl').returns
        state: 'a.detail.b.detail'
        args: ['1', '2', '']
      Backbone.Manager._testAccessor.managers.push manager2

      @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

      Backbone.Manager.goByUrl 'http://a.com/a/1/b/2'

      expect(manager1Parse).to.not.have.been.called
      Backbone.Manager._testAccessor.managers.pop()

    it 'should not reverse actual managers array', ->
      manager1 = Object.create Backbone.Manager.prototype
      manager1.id = 1
      @sinon.stub(manager1, '_parseStateFromUrl').returns undefined
      Backbone.Manager._testAccessor.managers.push manager1

      manager2 = Object.create Backbone.Manager.prototype
      manager2.id = 2
      @sinon.stub(manager2, '_parseStateFromUrl').returns undefined
      Backbone.Manager._testAccessor.managers.push manager2

      @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

      Backbone.Manager.goByUrl 'http://a.com/a/1/b/2'
      expect(Backbone.Manager._testAccessor.managers[0].id).to.equal manager1.id
      Backbone.Manager._testAccessor.managers.pop()


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

      it 'should remove optional surrounds for url template', ->
        manager = new (Backbone.Manager.extend
          states:
            test:
              transitionMethod: 'a'
              url: 'a/:a_id/b(/:b_id)'
        )(@router)

        obj =
          a_id: 1

        expect(manager.states.test._urlAsTemplate(obj)).to.equal 'a/1/b'

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

    it 'should trigger generic and specific load events in that order', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger')
      triggerSpy.withArgs 'load'
      triggerSpy.withArgs 'load:testState'

      manager._handleLoadCallback('testState', {loadMethod: 'test'})

      expect(triggerSpy.withArgs 'load:testState').to.have.been.calledAfter triggerSpy.withArgs 'load'

    it 'should trigger load event before callback', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger').withArgs 'load'
      callbackSpy = @sinon.spy manager, 'test'

      manager._handleLoadCallback('testState', {loadMethod: 'test'})

      expect(triggerSpy).to.have.been.calledBefore callbackSpy

  describe '_handleTransitionCallback()', ->
    it 'should trigger exit event if previous state was in a fdifferent manager', ->
      managerFirst = new (Backbone.Manager.extend
        test: ->
      )(@router)
      managerSecond = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(managerFirst, 'trigger').withArgs 'exit'

      managerFirst._handleTransitionCallback('testState', {transitionMethod: 'test'})
      managerSecond._handleTransitionCallback('testState', {transitionMethod: 'test'})

      expect(triggerSpy).to.have.been.calledOnce

    it 'should trigger generic and specific transition events in that order', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger')
      triggerSpy.withArgs 'transition'
      triggerSpy.withArgs 'transition:testState'

      manager._handleTransitionCallback('testState', {transitionMethod: 'test'})

      expect(triggerSpy.withArgs 'transition:testState').to.have.been.calledAfter triggerSpy.withArgs 'transition'

    it 'should trigger transition before callback', ->
      manager = new (Backbone.Manager.extend
        test: ->
      )(@router)

      triggerSpy = @sinon.spy(manager, 'trigger').withArgs 'transition'
      callbackSpy = @sinon.spy manager, 'test'

      manager._handleTransitionCallback('testState', {transitionMethod: 'test'})

      expect(triggerSpy).to.have.been.calledBefore callbackSpy

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

          manager._handleTransitionCallback 'test', manager.states.test, [1,2,3,4, null]

          expect(navigateStub).to.have.been.calledWith 'a/1/b/2/c/3/d/4'

        it 'should not fire navigate if historyHasUpdated', ->
          manager = new @managerProto @router

          navigateStub = @sinon.stub @router, 'navigate'

          manager._handleTransitionCallback 'test', manager.states.test, [1,2,3,4,null], historyHasUpdated = true

          expect(navigateStub).to.not.have.been.called

        it 'should hand correct args to callback in order, mimicking router params callback', ->
          manager = new @managerProto @router

          callbackSpy = @sinon.spy manager, 'test'

          manager._handleTransitionCallback 'test', manager.states.test, [1,2,3,4,null]

          expect(callbackSpy).to.have.been.calledWithExactly '1', '2', '3', '4', null, sinon.match.object

        it 'should not hand a stringified null to callback if args had one', ->
          manager = new @managerProto @router

          callbackSpy = @sinon.spy manager, 'test'

          manager._handleTransitionCallback 'test', manager.states.test, [1,2,3,4,null]

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

  describe '_parseStateFromUrl()', ->
    beforeEach ->
      @manager = new (Backbone.Manager.extend
        states:
          test:
            transitionMethod: 'a'
            url: 'a/:a_id/b/:b_id'
      )(@router)

    it 'should return undefined if no match found', ->
      expect(@manager._parseStateFromUrl('/abc')).to.equal undefined

    it 'should return object when match found', ->
      parsedObject = @manager._parseStateFromUrl 'a/1/b/2?c=d'

      expect(parsedObject).to.deep.equal
        state: 'test'
        args: ['1','2','c=d']

    it 'should use router._extractParameters to get args', ->
      @extractParamsSpy = @sinon.spy @router, '_extractParameters'

      @manager._parseStateFromUrl 'a/1/b/2?c=d'

      expect(@extractParamsSpy).to.have.been.called

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
          currentTarget: $("<a data-bb-state href='http://a.com/a/1/b/2'/>")[0]

      it 'should run goByUrl()', ->
        goByUrlStub = @sinon.stub Backbone.Manager, 'goByUrl'

        Backbone.Manager._testAccessor._watchForStateChange @mockEvent

        expect(goByUrlStub).to.have.been.calledWith 'http://a.com/a/1/b/2'

    context 'bb-state has value', ->
      it 'must add null to end of args for callback', ->
        @mockEvent =
          preventDefault: ->
          isDefaultPrevented: -> false
          currentTarget: $("<a data-bb-state='a.detail([1])' href='http://a.com/a/1/b/2'/>")[0]

        triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

        Backbone.Manager._testAccessor._watchForStateChange @mockEvent

        expect(triggerStub).to.have.been.calledWith 'a.detail', [1, null]

      it 'should pass [null] if bb-state has value but passing empty parenthesis', ->
        @mockEvent =
          preventDefault: ->
          isDefaultPrevented: -> false
          currentTarget: $("<a data-bb-state='a.b()'/>")[0]

        triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

        Backbone.Manager._testAccessor._watchForStateChange @mockEvent

        expect(triggerStub).to.have.been.calledWith 'a.b', [null]

      it 'should pass [null] if bb-state has value but no parenthesis', ->
        @mockEvent =
          preventDefault: ->
          isDefaultPrevented: -> false
          currentTarget: $("<a data-bb-state='a.b'/>")[0]

        triggerStub = @sinon.stub Backbone.Manager._testAccessor.managerQueue, 'trigger'

        Backbone.Manager._testAccessor._watchForStateChange @mockEvent

        expect(triggerStub).to.have.been.calledWith 'a.b', [null]

