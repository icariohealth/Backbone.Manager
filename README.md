# Backbone.Manager
[![Build Status](http://img.shields.io/travis/novu/Backbone.Manager.svg?style=flat)](https://travis-ci.org/novu/Backbone.Manager)
[![devDependency Status](http://img.shields.io/david/dev/novu/backbone.manager.svg?style=flat)](https://david-dm.org/novu/backbone.manager#info=devDependencies)

Backbone.Manager is a state-based routing/control manager for Backbone. It removes direct dependency on the router, and instead provides a standard control mechanism for url updates and state-change handling.

## Usage
A Backbone.Manager instance is created by providing a router _(required)_ to the constructor: `new Backbone.Manager(router)`. If you're creating multiple Manager instances, It's recommended to just share a single instance of a router between them.
#### Goals
* Intuitive state Change

### States
The `states` definition is the foundation of the Manager. It consists of state names paired with definitions for that state. States basicaly fall into one of two categories:
- Directly-related to an url
- Completely independent from urls

Which category a state falls under is controlled by the state being provided with an url definition:
```
states:
  urlState:
    url: '/states/:id'
    # etc
  nonUrlState:
    #etc
```
#### States with url defintions
For url-related states, there is a convention for state name that is helpful to follow, based on the url itself. The convention is not _required_, but without it you will not inherit any automatic triggering (described later). Urls are conventionally associated as follows:

Url            | State Name
-------------- | ----------
/users         | users
/users/1       | users.detail
/users/1/books | users.detail.books
/sections/1/2  | sections.detail.2 (not good*)

\* Never rely on convention for states associated with this type of url.

The url definition is essentially the same url you would define in a Router's `routes` definition. In fact, this url is passed through to the router. Param values that match through this url are passed into the necessary functions as a normal route's callback would be. **NOTE: Currently RegExp values are not supported**
####An Example
```
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
####Usage Details

## API     

##For Contributors##
* PR's should only contain changes to .coffee files, the release js will be built later
* Run `gulp` to autocompile coffeescript (both src and test/src) into /out for testing
* Open `test/test-runner.html` to run the in-browser test suite... Mocha isn't currently configured to be run headless
