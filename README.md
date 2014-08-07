#Backbone.Manager#
[![devDependency Status](http://img.shields.io/david/dev/novu/backbone.manager.svg?style=flat)](https://david-dm.org/novu/backbone.manager#info=devDependencies)

*README Currently In Progress*

---
##Structure##
```
states:
  a:
    url: 'a/b' (Not allowed to be a regex at this time)
```      
##Usage##
Backbone.Manager.extend

##For Contributors##
* PR's should only contain changes to .coffee files, the release js will be built later
* Run `gulp` to autocompile coffeescript (both src and test/src) into /out for testing
* Open `test/test-runner.html` to run the in-browser test suite... Mocha isn't currently configured to be run headless
