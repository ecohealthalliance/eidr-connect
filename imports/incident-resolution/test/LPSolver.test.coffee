import { chai } from 'meteor/practicalmeteor:chai'
import Solver from '../lib/LPSolver'

describe 'Linear Program Solver', ->

  it 'can handle negative numbers, decimals and missing variables', ->
    model = """
      max: -1 s0 2000000 s1 1600 s2
      30 s1 -20 s2 <= 300
      -0.3334 s0 -5 s1 10 s2 <= -110
      0 s0 30 s1 .5 s2 <= 400
      1 s1 >= -5
      """.split('\n').filter (x)->x
    model = Solver.ReformatLP(model)
    # Note that variables with a zero value are not listed
    Solver.Solve(model)

  it 'the lp solver balances counts', ->
    # a simple model of 3 subintervals over two overlapping incident intervals
    # will only allocate cases to two of the subintervals rather than
    # distributing them evenly.
    # This model demonstrates a technique where min and max rate variables
    # are added for each interval then their difference is minimized as a
    # low weight objective so that the counts will be allocated evenly
    # if it doesn't intefere with the main objective.
    model = """
      min: 1 a 2 b 1 c 0.01 max1 -0.01 min1 0.01 max2 -0.01 min2
      1 a 1 b >= 12
      1 a -1 max1 <= 0
      1 b -1 max1 <= 0
      1 a -1 min1 >= 0
      1 b -1 min1 >= 0
      1 b 1 c >= 12
      1 b -1 max2 <= 0
      1 c -1 max2 <= 0
      1 b -1 min2 >= 0
      1 c -1 min2 >= 0
      1 a >= 0
      1 b >= 0
      1 c >= 0
      """.split('\n').filter (x)->x
    model = Solver.ReformatLP(model)
    result = Solver.Solve(model)
    chai.assert.equal(result.a, result.b, result.c)
