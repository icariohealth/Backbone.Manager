expect = chai.expect

# Keep '@sinon sandboxed' to every test, use 'sinon' to bypass
beforeEach ->
  @sinon = sinon.sandbox.create()
afterEach ->
  @sinon.restore()

describe 'Backbone.Manager', ->
  describe 'constructor', ->
    beforeEach ->
      @router = new Backbone.Router()

    it 'should call initialize', ->
      initSpy = @sinon.spy Backbone.Manager.prototype, 'initialize'

      new Backbone.Manager @router

      expect(initSpy).to.have.been.called

  describe '#_parseStates', ->
    it "should throw error if transitionMethod for a state isn't defined", ->
      manager = Backbone.Manager.extend
        states:
          'test': {}

      expect(manager.bind null, @router).to.throw Error
    it ''
