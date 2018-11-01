solverExport = require('javascript-lp-solver')
_ = require('underscore')
# When the solver is imported for the browser it uses the global namespace
# instead of exporting a handle.
if _.isEmpty solverExport
  Solver = solver
else
  Solver = solverExport

module.exports = Solver
