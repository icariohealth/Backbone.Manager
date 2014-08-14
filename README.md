# Backbone.Manager
[![Build Status](http://img.shields.io/travis/novu/Backbone.Manager.svg?style=flat)](https://travis-ci.org/novu/Backbone.Manager)
[![devDependency Status](http://img.shields.io/david/dev/novu/backbone.manager.svg?style=flat)](https://david-dm.org/novu/backbone.manager#info=devDependencies)

Backbone.Manager is a state-based routing/control manager for Backbone. It removes direct dependency on the router, and instead provides a standard control mechanism for url updates and state-change handling.

Turn this:
```coffee
UsersRouter = Backbone.Router.extend
  routes:
    'users/:id': 'showUser'

  initialize: (options) ->
    _.bindAll @, 'switchToUser'

    @listenTo Backbone, 'showUser', @switchToUser
```
Into this:  
```coffee
UsersManager = Backbone.Manager.extend
  states:
    'users.detail':
      url: 'users/:id'
      loadMethod: 'showUser'
      transitionMethod: 'switchToUser'
```

## Usage
A Backbone.Manager instance is created by providing a router _(required)_ to the constructor: `new Backbone.Manager(router)`. If you're creating multiple Manager instances, it's recommended to just share a single instance of a router between them.
#### Goals
* Intuitive state change
* Differentiate between pageload and triggered changes
* Remove temptation of view<->router relationships
* Conventional state change from anchor href's
* Programmatic state change ability

####Example
```coffee
UsersManager = Backbone.Manager.extend
  states:
    users:
      url: 'users'
      loadMethod: 'showUsers'
      transitionMethod: 'switchToUsers'
    'users.detail'
      url: 'users/:id'
      loadMethod: 'showUser'
      transitionMethod: 'switchToUser'

  events:
    'pre-load:users.detail': 'prepareUser'
    'post-transition': 'logInAnalytics'
    
  initialize: ->
    # ...
  showUsers: ->
    # ...
  switchToUsers: (searchString, options) ->
    # ...
  showUser: (id) ->
    # ...
  switchToUser: (id, searchString, options) ->
    # ...
  prepareUser: (id) ->
    # ...
  logInAnalytics: ->
    # ...
```


### States
The `states` definition is the foundation of the Manager. It consists of state names paired with definitions for that state. States basicaly fall into one of two categories:
- Directly-related to an url
- Completely independent from urls

Which category a state falls under is controlled by the state being provided with an url definition:
```coffee
states:
  urlState:
    url: '/states/:id'
    # etc
  nonUrlState:
    # etc
```
---
#### States with url definitions
These are able to be triggered via:
* Pageload: History.popstate of '/users/1'
* Programmatically: `Backbone.History.go('users.detail',[1])`
* `data-bb-state` definition: `<a data-bb-state="users.detail([1])">`
* Conventional `data-bb-state` trigger: `<a data-bb-state="" href="/users/1">`

For url-related states, there is a convention for state name that is helpful to follow, based on the url itself. The convention is not _required_, but without it you will not inherit the automatic conventional `data-bb-state` trigger. Here is how urls are conventionally translated to a state name:

Url            | State Name
-------------- | ----------
/users         | users
/users/1       | users.detail
/users/1/books | users.detail.books
/sections/1/2  | sections.detail.2 (not good*)

\* Never rely on convention for states associated with this type of url.

The url definition is essentially the same url you would define in a Router's `routes` definition. In fact, this url is passed through to the router. Param values that match through this url are passed into the necessary functions as a normal route's callback would be. **NOTE: Currently RegExp values are not supported**

#### States __without__ url definitions

These are able to be triggered via:
* Programmatically: `Backbone.History.go('users.detail',[1])`
* `data-bb-state` definition: `<a data-bb-state="users.detail([1])">`
* Conventional `data-bb-state` trigger: `<a data-bb-state="" href="/users/1">`

### The `'*'` State
The `'*'` is reserved as a final matcher for states. When the `data-bb-state` watcher attempts to perform a state transtion for a state that hasn't been defined, it will fallback to a `'*'` state definition. Here is an example of how to use it:
```coffee
Backbone.Manager.extend
  states:
    '*':
      url: '*url'
      transitionMethod: 'defaultTransition'
  defaultTransition: (url) ->
    # ...
```

**Important:** If this is declared, it should be done within the very **first manager** created, and as the very **first state** definition. This is so that it ends up being placed in the bottom of the handlers stack within Backbone.History. See [TODO Order Is Important](#OrderIsImportant) for more detail

##For Contributors##
* PR's should only contain changes to .coffee files, the release js will be built later
* Run `gulp` to autocompile coffeescript (both src and test/src) into /out for testing
* Open `test/test-runner.html` to run the in-browser test suite... Mocha isn't currently configured to be run headless
