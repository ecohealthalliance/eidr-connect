// Generated by CoffeeScript 1.12.7
(function() {
  var Solver, _, solverExport;

  solverExport = require('javascript-lp-solver');

  _ = require('underscore');

  if (_.isEmpty(solverExport)) {
    Solver = solver;
  } else {
    Solver = solverExport;
  }

  module.exports = Solver;

}).call(this);
