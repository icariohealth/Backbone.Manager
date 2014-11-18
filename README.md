# Backbone.Manager
[![Build Status](http://img.shields.io/travis/novu/Backbone.Manager.svg?style=flat)](https://travis-ci.org/novu/Backbone.Manager)
[![Coverage Status](http://img.shields.io/coveralls/novu/Backbone.Manager.svg?style=flat)](https://coveralls.io/r/novu/Backbone.Manager?branch=master)
[![Dependency Status](http://img.shields.io/david/novu/backbone.manager.svg?style=flat)](https://david-dm.org/novu/backbone.manager#info=devDependencies)
[![devDependency Status](http://img.shields.io/david/dev/novu/backbone.manager.svg?style=flat)](https://david-dm.org/novu/backbone.manager#info=devDependencies)

Backbone.Manager is a state-based routing/control manager for Backbone. It removes direct dependency on the router, and instead provides a standard control mechanism for url updates and state-change handling. It can be used for large state changes that involve url updates and moving between major view controllers, or for small state changes to do things like flash div content.

#### Goals
* Intuitive state change
* Differentiate between pageload and triggered changes
* Remove temptation of view<->router relationships
* Automatic state change from clicked anchors
* Programmatic state change ability

This:
```coffee
UsersRouter = Backbone.Router.extend
  routes:
    'users/:id': 'showUser'

  initialize: (options) ->
    _.bindAll @, 'switchToUser'

    @listenTo Backbone, 'showUser', @switchToUser
```
is now organized into this:  
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
    'load:users.detail': 'prepareUser'
    'transition': 'logToAnalytics'
    
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
  logToAnalytics: ->
    # ...
```

## States
The `states` definition is the foundation of the Manager. It consists of state names paired with definitions for that state. States basically fall into one of two categories:
- [Directly-related to an url](#states-with-url-definitions)
- [Completely independent from urls](#states-without-url-definitions)

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
### States with `url` definitions
These are able to be triggered via:
* Initial Pageload
* Window.popstate of '/users/1'
* `Backbone.Manager.go('users.detail',[1])`
* `Backbone.Manager.goByUrl('/users/1')`
* Direct `data-bb-state` trigger: `<a data-bb-state="users.detail([1])">`
* Inferred `data-bb-state` trigger: `<a data-bb-state href="/users/1">`

---
### States __without__ `url` definitions

These are able to be triggered via:
* Programmatic: `Backbone.Manager.go('users.detail',[1])`
* `data-bb-state` definition: `<a data-bb-state="users.detail([1])">`

---
### `loadMethod` *optional*
```coffee
states:
  'users.detail':
    url: 'users/:id'
    loadMethod: 'callback' # String representing method name for callback
```
Callback used immediately upon load of the page, when the page url matches defined url (User navigates directly). Url must be defined to activate.
```coffee
# Arguments are built from url params, passed straight from the Router
callback: (id, searchString) ->
```
---
### `transitionMethod`
Callback used when any non-loadMethod related state change occurs. Functionality can be affected by passing [transitionOptions](#transitionoptions).
#### When `url` Is Defined
```coffee
states:
  'users.detail.books.detail':
    url: 'users/:a/books/:b'
    transitionMethod: 'callback' # String representing method name for callback
```
Before the `transitionMethod` is triggered, A `router.navigate` will occur with the state's url. **Note: currently anything inside of and including the optional matcher (`()`'s) in the state url are removed first.**

Callback method takes the params in order from the url, then provides the searchString (provided because of the router, usually null), and finally an options object containing the populated url. So:

trigger | callback method
------- | -------------------------
`Backbone.Manager.go('users.detail.books.detail',[1,2])` | `callback(1,2,null,{url: 'users/1/books/2'})`
`Backbone.Manager.go('users.detail.books.detail',{b:2,a:1})`<br>(args order **not important**) | `callback(1,2,null,{url: 'users/1/books/2'})`
`<a data-bb-state="users.detail.books.detail([1,2])">` | `callback(1,2,null,{url: 'users/1/books/2'})`
`<a data-bb-state="users.detail.books.detail({b:2,a:1})">`<br>(args order **not important**) | `callback(1,2,null,{url: 'users/1/books/2'})`
`Backbone.Manager.goByUrl('/users/1/books/2')` | `callback(1,2,null,{url: 'users/1/books/2'})`
`<a data-bb-state href="/users/1/books/2">` | `callback(1,2,null,{url: 'users/1/books/2'})`
#### When `url` Is *NOT* Defined
```coffee
states:
  'users.detail.books.detail':
    transitionMethod: 'callback' # String representing method name for callback
```
Callback method takes the params in order as passed. Order is important, even when an object is used for the args. So:

trigger | callback method
------- | -------------------------
`Backbone.Manager.go('users.detail.books.detail',[1,2])` | `callback(1,2)`
`Backbone.Manager.go('users.detail.books.detail',{b:2,a:1})`<br>(args order **important**) | `callback(2,1)`<br>**values taken in order**
`<a data-bb-state="users.detail.books.detail([1,2])">` | `callback(1,2)`
`<a data-bb-state="users.detail.books.detail({b:2,a:1})">`<br>(args order **important**) | `callback(2,1)`<br>**values taken in order**

#### transitionOptions
Functionality of how the transition will occur can be controlled by passing in transitionOptions. These options can be passed directly using `go` or `goByUrl`, or also by setting [data-bb-options](#data-bb-options) on an anchor.

**Currently supported options:**

name | description
---- | -------------------------
navigate | (boolean, default: *true*) If set to false, will not update the url when the transition is occurs, even if the url is provided for the state.

## The `'*'` State
The `'*'` is reserved as a final matcher for states. When the `data-bb-state` watcher attempts to perform a state transition for a state that hasn't been defined, it will fallback to a `'*'` state definition. Here is an example of how to use it:
```coffee
Backbone.Manager.extend
  states:
    '*':
      url: '*url'
      transitionMethod: 'defaultTransition'
  defaultTransition: (url) ->
    # ...
```

**Important:** If this is declared, it should be done within the very **first manager** created, and as the very **first state** definition. This is so that it ends up being placed in the bottom of the handlers stack within Backbone.History. When a Manager is created, Backbone.Manager inserts each url handler into the shared router as it progresses through the States definition... from the top down. The Router then works from the top down in its handlers when it's searching for a match. This is a Backbone.Router limitation.

## Events
Backbone.Manager will trigger state specific and general events as the transition and load methods are being processed. These are async calls, so the callbacks aren't guaranteed to have completed before the `post` events are triggered. Here are the following events that are triggered:

event | description
----- | -----------
load | incoming page load call for any state
load:\[state] (args) | incoming page load call for the [state]<br>(args) are the url params provided by the router
transition | incoming transition call for any state
transition:[state] | incoming transition call for the [state]
exit | state is transitioning out of the current Manager, into a different one

## Triggering State Change
There are four different ways to trigger a state change within Backbone.Manager:
### Initial Pageload
Triggered immediately upon load of the page, when the page url matches defined url (User navigates directly). Url must be defined to activate. This will trigger the [loadMethod](#loadmethod-optional) associated with the url.

---
### Window.popstate
Typically occurs when the user uses the back button. This will trigger the [transitionMethod](#transitionmethod) associated with the url.

---
### `Backbone.Manager.go(stateName, args[, transitionOptions])`
The programmatic way of triggering state changes.
**Example Usage:**
```coffee
events:
  'click dd': 'showUser'
showUser: ->
  Backbone.Manager.go('users.detail', {id:1}, {navigate: true})
```
params:
* stateName
* args: [] or {}
  * see [transitionMethod](#transitionmethod) for details on what happens with the args
* _(optional)_ transitionOptions (Object containing the options defined in [transitionOptions](#transitionoptions))


---
### `Backbone.Manager.goByUrl(url [, transitionOptions])`
The programmatic way of triggering state changes via url matching.
**Example Usage:**
```coffee
events:
  'click dd': 'showUser'
showUser: ->
  Backbone.Manager.goByUrl('/users/1', {navigate: true})
```
params:
* url (tested against url matchers defined in states, will use * state if none are found)
* _(optional)_ transitionOptions (Object containing the options defined in [transitionOptions](#transitionoptions))

---
### Click on `<a data-bb-state>`
The `data-bb-state` attribute is watched for by Backbone.Manager on all anchor tag clicks that bubble up to document. If event propagation is disabled or preventDefault gets set on that event, then Backbone.Manager will not trigger.

**Example Usages:**
```html
<a data-bb-state='users.detail([1])'/>
<a data-bb-state='users.detail({id:1})'/>
<a data-bb-state href='/users/1'/>
```
The format for the `data-bb-state` value is `'statename([args]or{args})'`, where the args are passed to the callback as described in [transitionMethod](#transitionmethod).

The first two examples are explicit state calls, but the third uses the url to infer the state (it actually calls `goByUrl`). The explicit triggers in the examples above will trigger the `users.detail.transitionMethod` callback. To use the inferred trigger, `data-bb-state` must be defined on the anchor and it must have an `href` url defined.

#### `data-bb-options`
You can add the `data-bb-options` attribute to your anchor to allow passing of the [transitionOptions](#transitionoptions) in the form of valid JSON.

**Example Usage:**
```html
<a data-bb-state='users.detail([1])' data-bb-options='{"navigate": false}'/>
```

## Additional Resources
* [Slides (v0.1.5)](http://slides.com/johnathonsanders/backbone-manager)

##Contributors
* PR's should only contain changes to .coffee files, the release js will be built later
* Run `gulp` to autocompile coffeescript (both src and test/src) into /out for testing
* Open `test/test-runner.html` to run the in-browser test suite, or run `npm test` for headless.

## Change Log
### 1.0
* Add [transitionOptions](#transitionoptions) to `go` and `goByUrl`... supports `navigate` currently to allow pushState bypass
* Support `data-bb-options` attribute to specify transitionOptions from anchor tags

### 0.2.4
* Bugfix: `go` still requires args of some sort even if url contains no params
* Bugfix: `go` breaks in ie8 if no arguments are provided

### 0.2.3
* Bugfix: `goByUrl` dies if there is a state that doesn't have a url defined

### 0.2.2
* Bugfix: Managers in wrong order after `goByUrl` runs

### 0.2.1
* Bugfix: Managers are being traversed in the wrong order for `goByUrl`

### 0.2.0
* __Breaking:__ Move from conventional `<a href>`-to-state translation to direct url matching. This means that old conventional `data-bb-state` triggers for states without url definitions will no longer work.
* Added `Backbone.Manager.goByUrl` to back `data-bb-state` href functionality

### 0.1.6
* __Breaking:__ Removed pre/post events... there was no guarantee of pre since it was async

### 0.1.5
* Bugfix: Param matcher isn't excluding `(`

### 0.1.4
* Bugfix: Use currentTarget instead of target for anchor state changes - @jmcnevin
