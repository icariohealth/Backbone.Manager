jsdom = require('jsdom');
window = jsdom.jsdom('<html><head><script></script></head><body></body></html>').parentWindow;
global.document = window.document;
global.addEventListener = window.addEventListener;
global.$ = require('jquery');

global._ = require('underscore');
global.Backbone = require('backbone');

chai = require('chai');
sinon = require('sinon');
sinonChai = require('sinon-chai');
expect = chai.expect;
chai.use(sinonChai);

require('../out/backbone.manager.js');
require('../out/backbone.manager_test.js');
