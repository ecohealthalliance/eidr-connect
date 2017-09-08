import solverExport from 'javascript-lp-solver'
# When the solver is imported for the browser it uses the global namespace
# instead of exporting a handle.
if _.isEmpty solverExport
  Solver = solver
else
  Solver = solverExport

export default Solver
