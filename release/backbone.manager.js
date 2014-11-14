/**
 * Backbone.Manager - State-Based Routing/Control Manager for Backbone
 * @version v0.2.1
 * @link https://github.com/novu/backbone.manager
 * @author Johnathon Sanders
 * @license MIT
 */
(function(Backbone, _, $, window) {
  var Manager, cachedParamMatcher, currentManager, managerQueue, managers, onloadUrl, _watchForStateChange;
  managers = [];
  managerQueue = _.extend({}, Backbone.Events);
  onloadUrl = window.location.href;
  cachedParamMatcher = /[:*]([^(:)/]+)/g;
  currentManager = null;
  Manager = (function() {
    Manager.prototype.states = {};

    Manager.prototype.events = {};

    function Manager(router, options) {
      managers.push(this);
      this.router = router;
      _.extend(this, Backbone.Events);
      this._parseStates();
      this._parseEvents();
      this.initialize(options);
      return;
    }

    Manager.prototype.initialize = function() {};

    Manager.prototype._parseStates = function() {
      _.each(_.keys(this.states), (function(_this) {
        return function(stateKey) {
          var matches, stateOptions, templateUrl;
          stateOptions = _this.states[stateKey];
          if (!stateOptions.transitionMethod) {
            throw new Error(stateKey + ' needs transitionMethod definitions');
          }
          if (stateOptions.url) {
            if (_.isRegExp(stateOptions.url)) {
              throw new Error(stateKey + ' is not allowed to have a RegExp url');
            }
            stateOptions._urlParams = (function() {
              var _results;
              _results = [];
              while (matches = cachedParamMatcher.exec(stateOptions.url)) {
                _results.push(matches[1]);
              }
              return _results;
            })();
            templateUrl = stateOptions.url.replace(/\(.*\)/g, '');
            stateOptions._urlAsTemplate = _.template(templateUrl, null, {
              interpolate: cachedParamMatcher
            });
            stateOptions._urlAsRegex = _this.router._routeToRegExp(stateOptions.url);
            _this.router.route(stateOptions._urlAsRegex, stateKey, function() {
              _this._routeCallbackChooser(stateKey, stateOptions, Array.apply(null, arguments));
            });
          }
          return _this.listenTo(managerQueue, stateKey, function(args) {
            _this._handleTransitionCallback(stateKey, stateOptions, args);
          });
        };
      })(this));
    };

    Manager.prototype._routeCallbackChooser = function(stateKey, stateOptions, args) {
      var historyHasUpdated;
      if (onloadUrl && this._getWindowHref() === onloadUrl) {
        this._handleLoadCallback(stateKey, stateOptions, args);
      } else {
        this._handleTransitionCallback(stateKey, stateOptions, args, historyHasUpdated = true);
      }
      onloadUrl = null;
    };

    Manager.prototype._handleLoadCallback = function(stateKey, stateOptions, args) {
      currentManager = this;
      if (stateOptions.loadMethod) {
        this.trigger('load');
        this.trigger('load:' + stateKey, args);
        this[stateOptions.loadMethod].apply(this, args);
      }
    };

    Manager.prototype._handleTransitionCallback = function(stateKey, stateOptions, args, historyHasUpdated) {
      var argsObject, data, options, url;
      if (historyHasUpdated == null) {
        historyHasUpdated = false;
      }
      if (currentManager && currentManager !== this) {
        currentManager.trigger('exit');
      }
      currentManager = this;
      this.trigger('transition');
      this.trigger('transition:' + stateKey);
      if (stateOptions.url) {
        if (args instanceof Array) {
          argsObject = _.object(stateOptions._urlParams, args);
          url = stateOptions._urlAsTemplate(argsObject);
          if (!historyHasUpdated) {
            this.router.navigate(url);
          }
          data = _.map(_.initial(args), String);
          data.push(_.last(args));
        } else if (args instanceof Object) {
          url = stateOptions._urlAsTemplate(args);
          if (!historyHasUpdated) {
            this.router.navigate(url);
          }
          data = this.router._extractParameters(stateOptions._urlAsRegex, url);
        } else {
          throw new Error('Args are only supported as an object or array if state.url is defined');
        }
        options = {
          url: url
        };
        data.push(options);
      } else {
        data = args;
      }
      this[stateOptions.transitionMethod].apply(this, data);
    };

    Manager.prototype._parseEvents = function() {
      _.each(_.keys(this.events), (function(_this) {
        return function(eventName) {
          _this.on(eventName, _this[_this.events[eventName]]);
        };
      })(this));
    };

    Manager.prototype._parseStateFromUrl = function(url) {
      var data, stateKey;
      stateKey = _.find(_.keys(this.states), (function(_this) {
        return function(stateKey) {
          return _this.states[stateKey]._urlAsRegex.test(url);
        };
      })(this));
      if (stateKey) {
        data = this.router._extractParameters(this.states[stateKey]._urlAsRegex, url);
        return {
          state: stateKey,
          args: data
        };
      }
    };

    Manager.prototype._getWindowHref = function() {
      return window != null ? window.location.href : void 0;
    };

    Manager.go = function(state, args) {
      return managerQueue.trigger(state, args);
    };

    Manager.goByUrl = function(url) {
      var args, parsedUrl, path, state, urlParser;
      urlParser = document.createElement('a');
      urlParser.href = url;
      path = urlParser.pathname.replace(/^\//, '') + urlParser.search;
      parsedUrl = null;
      _.find(managers.reverse(), function(manager) {
        return parsedUrl = manager._parseStateFromUrl(path);
      });
      if (parsedUrl) {
        state = parsedUrl.state;
        args = parsedUrl.args;
      } else {
        state = '*';
        args = [path];
      }
      return Manager.go(state, args);
    };

    Manager.extend = Backbone.Model.extend;

    Manager.config = {};

    return Manager;

  })();
  Backbone.Manager = Manager;
  _watchForStateChange = function(event) {
    var args, state, stateAttr, stateInfo;
    if (!event.isDefaultPrevented()) {
      stateAttr = $(event.currentTarget).attr('data-bb-state');
      event.preventDefault();
      if (stateAttr === '') {
        Manager.goByUrl(event.currentTarget.href);
      } else {
        stateInfo = stateAttr.split('(', 2);
        state = stateInfo[0];
        args = [];
        if (stateInfo.length > 1 && stateInfo[1].length > 2) {
          args = JSON.parse(stateInfo[1].slice(0, stateInfo[1].indexOf(')')));
        }
        if (args instanceof Array) {
          args.push(null);
        }
      }
      managerQueue.trigger(state, args);
    }
  };
  $(window.document).on('click', 'a[data-bb-state]', function(event) {
    return _watchForStateChange(event);
  });
;
})(Backbone, _, $, window);
