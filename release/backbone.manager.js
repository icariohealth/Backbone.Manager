/**
 * Backbone.Manager - State-Based Routing/Control Manager for Backbone
 * @version v1.0.1
 * @link https://github.com/novu/backbone.manager
 * @author Johnathon Sanders
 * @license MIT
 */
(function(Backbone, _, $, window) {
  var Manager, cachedOptionalMatcher, cachedParamMatcher, currentManager, managerQueue, managers, onloadUrl, _watchForStateChange;
  managers = [];
  managerQueue = _.extend({}, Backbone.Events);
  onloadUrl = window.location.href;
  cachedParamMatcher = /[:*]([^(:)/]+)/g;
  cachedOptionalMatcher = /\(.*\)/g;
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
            templateUrl = stateOptions.url.replace(cachedOptionalMatcher, '');
            stateOptions._urlAsTemplate = _.template(templateUrl, null, {
              interpolate: cachedParamMatcher
            });
            stateOptions._urlAsRegex = _this.router._routeToRegExp(stateOptions.url);
            _this.router.route(stateOptions._urlAsRegex, stateKey, function() {
              _this._routeCallbackChooser(stateKey, stateOptions, Array.apply(null, arguments));
            });
          }
          return _this.listenTo(managerQueue, stateKey, function(params, transitionOptions) {
            _this._handleTransitionCallback(stateKey, stateOptions, params, transitionOptions);
          });
        };
      })(this));
    };

    Manager.prototype._routeCallbackChooser = function(stateKey, stateOptions, params) {
      var historyHasUpdated;
      if (onloadUrl && this._getWindowHref() === onloadUrl) {
        this._handleLoadCallback(stateKey, stateOptions, params);
      } else {
        this._handleTransitionCallback(stateKey, stateOptions, params, {}, historyHasUpdated = true);
      }
      onloadUrl = null;
    };

    Manager.prototype._handleLoadCallback = function(stateKey, stateOptions, params) {
      currentManager = this;
      if (stateOptions.loadMethod) {
        this.trigger('load');
        this.trigger('load:' + stateKey, params);
        this[stateOptions.loadMethod].apply(this, params);
      }
    };

    Manager.prototype._handleTransitionCallback = function(stateKey, stateOptions, params, transitionOptions, historyHasUpdated) {
      var data, options, paramsObject, queryParams, url;
      if (transitionOptions == null) {
        transitionOptions = {};
      }
      if (historyHasUpdated == null) {
        historyHasUpdated = false;
      }
      if (transitionOptions.navigate == null) {
        transitionOptions.navigate = true;
      }
      if (currentManager && currentManager !== this) {
        currentManager.trigger('exit');
      }
      currentManager = this;
      this.trigger('transition');
      this.trigger('transition:' + stateKey);
      if (stateOptions.url) {
        if (params instanceof Array) {
          paramsObject = _.object(stateOptions._urlParams, params);
          queryParams = _.last(params);
          url = stateOptions._urlAsTemplate(paramsObject);
          if (queryParams) {
            url += '?' + queryParams;
          }
          if (!historyHasUpdated && transitionOptions.navigate) {
            this.router.navigate(url);
          }
          data = _.map(_.initial(params), String);
          data.push(queryParams);
        } else if (params instanceof Object) {
          url = stateOptions._urlAsTemplate(params);
          if (!historyHasUpdated && transitionOptions.navigate) {
            this.router.navigate(url);
          }
          data = this.router._extractParameters(stateOptions._urlAsRegex, url);
        } else {
          throw new Error('Params are only supported as an object or array if state.url is defined');
        }
        options = {
          url: url
        };
        data.push(options);
      } else {
        data = params;
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
          var _ref;
          return (_ref = _this.states[stateKey]._urlAsRegex) != null ? _ref.test(url) : void 0;
        };
      })(this));
      if (stateKey) {
        data = this.router._extractParameters(this.states[stateKey]._urlAsRegex, url);
        return {
          state: stateKey,
          params: data
        };
      }
    };

    Manager.prototype._getWindowHref = function() {
      return window != null ? window.location.href : void 0;
    };

    Manager.go = function(state, params, transitionOptions) {
      if (!params) {
        params = [];
      }
      return managerQueue.trigger(state, params, transitionOptions);
    };

    Manager.goByUrl = function(url, transitionOptions) {
      var params, parsedUrl, path, state, urlParser;
      urlParser = document.createElement('a');
      urlParser.href = url;
      path = urlParser.pathname.replace(/^\//, '') + urlParser.search;
      parsedUrl = null;
      _.find(managers.slice().reverse(), function(manager) {
        return parsedUrl = manager._parseStateFromUrl(path);
      });
      if (parsedUrl) {
        state = parsedUrl.state;
        params = parsedUrl.params;
      } else {
        state = '*';
        params = [path];
      }
      return Manager.go(state, params, transitionOptions);
    };

    Manager.extend = Backbone.Model.extend;

    Manager.config = {};

    return Manager;

  })();
  Backbone.Manager = Manager;
  _watchForStateChange = function(event) {
    var $target, params, state, stateAttr, stateInfo, transitionOptions;
    if (!event.isDefaultPrevented()) {
      $target = $(event.currentTarget);
      stateAttr = $target.attr('data-bb-state');
      transitionOptions = $target.attr('data-bb-options') || '{}';
      event.preventDefault();
      if (stateAttr === '') {
        Manager.goByUrl(event.currentTarget.href, JSON.parse(transitionOptions));
      } else {
        stateInfo = stateAttr.split('(', 2);
        state = stateInfo[0];
        params = [];
        if (stateInfo.length > 1 && stateInfo[1].length > 2) {
          params = JSON.parse(stateInfo[1].slice(0, stateInfo[1].indexOf(')')));
        }
        if (params instanceof Array) {
          params.push(null);
        }
      }
      managerQueue.trigger(state, params, JSON.parse(transitionOptions));
    }
  };
  $(window.document).on('click', 'a[data-bb-state]', function(event) {
    return _watchForStateChange(event);
  });
;
})(Backbone, _, $, window);
