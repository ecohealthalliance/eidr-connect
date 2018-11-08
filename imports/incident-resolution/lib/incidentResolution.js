// Generated by CoffeeScript 1.12.7
(function() {
  var Endpoint, LocationTree, MILLIS_PER_DAY, Solver, SubInterval, _, convertAllIncidentsToDifferentials, createSupplementalIncidents, createSupplementalIncidentsSingleDisease, createSupplementalIncidentsSingleType, dailyRatesToActiveCases, differentialIncidentsToSubIntervals, enumerateDateRange, extendSubIntervalsWithValues, extendSubIntervalsWithValuesLP, extendSubIntervalsWithValuesTS, getContainedSubIntervals, getTopLevelSubIntervals, intervalToEndpoints, mapLocationsToMaxSubIntervals, mergeSubIntervals, removeOutlierIncidents, removeOutlierIncidentsSingleDisease, removeOutlierIncidentsSingleType, subIntervalsToActiveCases, subIntervalsToDailyRates, subIntervalsToLP, sum, topologicalSort;

  LocationTree = require('./LocationTree');

  Solver = require('./LPSolver');

  convertAllIncidentsToDifferentials = require('./convertAllIncidentsToDifferentials');

  _ = require('underscore');

  MILLIS_PER_DAY = 1000 * 60 * 60 * 24;

  SubInterval = (function() {
    function SubInterval(id1, start1, end1, location1, incidentIds1, __value) {
      this.id = id1;
      this.start = start1;
      this.end = end1;
      this.location = location1;
      this.incidentIds = incidentIds1;
      this.__value = __value != null ? __value : null;
      this.locationId = this.location.id;
      Object.defineProperty(this, 'value', {
        get: (function(_this) {
          return function() {
            return _this.__value;
          };
        })(this),
        enumerable: true,
        configurable: true
      });
      Object.defineProperty(this, 'duration', {
        get: (function(_this) {
          return function() {
            return (_this.end - _this.start) / MILLIS_PER_DAY;
          };
        })(this),
        enumerable: true,
        configurable: true
      });
    }

    SubInterval.prototype.setValue = function(__value) {
      this.__value = __value;
      return this.rate = this.__value / this.duration;
    };

    SubInterval.prototype.setRate = function(rate1) {
      this.rate = rate1;
      return this.__value = this.rate * this.duration;
    };

    return SubInterval;

  })();

  Endpoint = (function() {
    function Endpoint(isStart, offset, interval1) {
      this.isStart = isStart;
      this.offset = offset;
      this.interval = interval1;
    }

    return Endpoint;

  })();

  intervalToEndpoints = function(interval) {
    if (Number(interval.startDate) >= Number(interval.endDate)) {
      console.log(interval);
      throw new Error("Invalid interval: " + interval);
    }
    return [new Endpoint(true, Number(interval.startDate), interval), new Endpoint(false, Number(interval.endDate), interval)];
  };

  differentialIncidentsToSubIntervals = function(differentialIncidents) {
    var SELToIncidents, SELs, activeIntervals, end, endpoints, idx, incidentIds, key, locationId, locationTree, locationsById, priorEndpoint, ref, start, topLocations;
    if (differentialIncidents.length === 0) {
      return [];
    }
    endpoints = [];
    locationsById = {};
    differentialIncidents.forEach(function(incident, idx) {
      var j, len, location, ref;
      incident.id = idx;
      console.assert(incident.locations.length > 0);
      ref = incident.locations;
      for (j = 0, len = ref.length; j < len; j++) {
        location = ref[j];
        locationsById[location.id] = location;
      }
      return endpoints = endpoints.concat(intervalToEndpoints(incident));
    });
    endpoints = endpoints.sort(function(a, b) {
      if (a.offset < b.offset) {
        return -1;
      } else if (a.offset > b.offset) {
        return 1;
      } else if (a.isStart && !b.isStart) {
        return 1;
      } else if (!a.isStart && b.isStart) {
        return -1;
      } else {
        return 0;
      }
    });
    locationTree = LocationTree.from(_.values(locationsById));
    topLocations = locationTree.children.map(function(x) {
      return x.value;
    });
    priorEndpoint = endpoints[0];
    console.assert(priorEndpoint.isStart);
    SELToIncidents = {};
    activeIntervals = [priorEndpoint.interval];
    endpoints.slice(1).forEach(function(endpoint) {
      var interval, j, key, l, len, len1, len2, location, m, ref;
      if (priorEndpoint.offset !== endpoint.offset) {
        for (j = 0, len = topLocations.length; j < len; j++) {
          location = topLocations[j];
          key = priorEndpoint.offset + "," + endpoint.offset + "," + location.id;
          SELToIncidents[key] = SELToIncidents[key] || [];
        }
        for (l = 0, len1 = activeIntervals.length; l < len1; l++) {
          interval = activeIntervals[l];
          ref = interval.locations;
          for (m = 0, len2 = ref.length; m < len2; m++) {
            location = ref[m];
            key = priorEndpoint.offset + "," + endpoint.offset + "," + location.id;
            SELToIncidents[key] = _.uniq((SELToIncidents[key] || []).concat(interval.id));
          }
        }
      }
      if (endpoint.isStart) {
        activeIntervals.push(endpoint.interval);
      } else {
        activeIntervals = _.without(activeIntervals, endpoint.interval);
      }
      return priorEndpoint = endpoint;
    });
    SELs = [];
    idx = 0;
    for (key in SELToIncidents) {
      incidentIds = SELToIncidents[key];
      ref = key.split(','), start = ref[0], end = ref[1], locationId = ref[2];
      SELs.push(new SubInterval(idx, parseInt(start), parseInt(end), locationsById[locationId], incidentIds));
      idx++;
    }
    return SELs;
  };

  subIntervalsToLP = function(incidents, subIntervals) {
    var IncidentToSELs, SELToId, SEToLocationTree, SEToLocations, constraints, key, locations;
    IncidentToSELs = {};
    SEToLocations = {};
    SELToId = {};
    subIntervals.forEach(function(interval) {
      var end, incidentId, incidentIds, j, key, len, location, start;
      start = interval.start, end = interval.end, incidentIds = interval.incidentIds, location = interval.location;
      for (j = 0, len = incidentIds.length; j < len; j++) {
        incidentId = incidentIds[j];
        IncidentToSELs[incidentId] = (IncidentToSELs[incidentId] || []).concat(interval);
      }
      SELToId[start + "," + end + "," + location.id] = interval.id;
      key = start + "," + end;
      return SEToLocations[key] = (SEToLocations[key] || []).concat(location);
    });
    SEToLocationTree = {};
    for (key in SEToLocations) {
      locations = SEToLocations[key];
      SEToLocationTree[key] = LocationTree.from(locations);
    }
    constraints = [];
    incidents.forEach(function(incident, incidentId) {
      var duration, end, id, incidentRate, incidentSubs, j, len, mainConstraintVars, start, subInterval;
      mainConstraintVars = [];
      incidentSubs = IncidentToSELs[incidentId];
      if (!incidentSubs) {
        console.log("Error: No subintervals for", incidentId);
      }
      incidentRate = incident.count / incident.duration;
      for (j = 0, len = incidentSubs.length; j < len; j++) {
        subInterval = incidentSubs[j];
        id = subInterval.id, start = subInterval.start, end = subInterval.end, duration = subInterval.duration;
        constraints.push(((1 / duration).toFixed(12)) + " s" + id + " -1 abs" + id + " <= " + incidentRate);
        constraints.push(((1 / duration).toFixed(12)) + " s" + id + " 1 abs" + id + " >= " + incidentRate);
        mainConstraintVars.push("1 s" + id);
      }
      return constraints.push(mainConstraintVars.join(" ") + " >= " + incident.count);
    });
    subIntervals.forEach(function(arg) {
      var end, id, j, len, locationId, locationTree, node, ref, start, subLocConstraintVars, sublocSELId, sublocation;
      id = arg.id, start = arg.start, end = arg.end, locationId = arg.locationId;
      locationTree = SEToLocationTree[start + "," + end];
      subLocConstraintVars = ["1 s" + id];
      node = locationTree.getNodeById(locationId);
      ref = node.children;
      for (j = 0, len = ref.length; j < len; j++) {
        sublocation = ref[j];
        sublocSELId = SELToId[start + "," + end + "," + sublocation.value.id];
        subLocConstraintVars.push("-1 s" + sublocSELId);
      }
      return constraints.push(subLocConstraintVars.join(" ") + " >= 0");
    });
    return [
      "min: " + subIntervals.map(function(i, idx) {
        return "1 abs" + idx;
      }).join(" ")
    ].concat(constraints);
  };

  extendSubIntervalsWithValuesLP = function(incidents, subIntervals) {
    var key, model, results, solution, subId, subInterval, value;
    model = subIntervalsToLP(incidents, subIntervals);
    solution = Solver.Solve(Solver.ReformatLP(model));
    subIntervals.forEach(function(s) {
      return s.setValue(0);
    });
    results = [];
    for (key in solution) {
      value = solution[key];
      if (key.startsWith("s")) {
        subId = key.split("s")[1];
        subInterval = subIntervals[parseInt(subId)];
        results.push(subInterval.setValue(value));
      } else {
        results.push(void 0);
      }
    }
    return results;
  };

  topologicalSort = function(incomingNodesInit) {
    var incomingNodes, noIncomingNodes, nodeId, outgoingNodes, sortedIds;
    incomingNodes = incomingNodesInit.map(function(nodes) {
      return new Set(nodes);
    });
    outgoingNodes = incomingNodes.map(function() {
      return new Set();
    });
    incomingNodes.forEach(function(incomingIds, id) {
      return incomingIds.forEach(function(incomingId) {
        return outgoingNodes[incomingId].add(id);
      });
    });
    sortedIds = [];
    noIncomingNodes = [];
    incomingNodes.forEach(function(incomingNodes, id) {
      if (incomingNodes.size === 0) {
        return noIncomingNodes.push(id);
      }
    });
    while (noIncomingNodes.length > 0) {
      nodeId = noIncomingNodes.pop();
      sortedIds.push(nodeId);
      outgoingNodes[nodeId].forEach(function(outgoingNodeId) {
        var outgoingNodeIncomingNodes;
        outgoingNodeIncomingNodes = incomingNodes[outgoingNodeId];
        outgoingNodeIncomingNodes["delete"](nodeId);
        if (outgoingNodeIncomingNodes.size === 0) {
          return noIncomingNodes.push(outgoingNodeId);
        }
      });
      outgoingNodes[nodeId] = new Set();
    }
    console.assert(incomingNodes.every(function(nodes) {
      return nodes.size === 0;
    }));
    console.assert(outgoingNodes.every(function(nodes) {
      return nodes.size === 0;
    }));
    return sortedIds;
  };

  extendSubIntervalsWithValuesTS = function(differentialIncidents, subIntervals) {
    var IncidentToSELs, SELToId, SEToLocationTree, SEToLocations, id, incomingNodes, j, key, len, locations, sortedSubIntervalIds, subIntervalRates, subLocationTotal;
    IncidentToSELs = {};
    SEToLocations = {};
    SELToId = {};
    subIntervals.forEach(function(interval) {
      var end, incidentId, incidentIds, j, key, len, location, start;
      start = interval.start, end = interval.end, incidentIds = interval.incidentIds, location = interval.location;
      for (j = 0, len = incidentIds.length; j < len; j++) {
        incidentId = incidentIds[j];
        IncidentToSELs[incidentId] = (IncidentToSELs[incidentId] || []).concat(interval);
      }
      SELToId[start + "," + end + "," + location.id] = interval.id;
      key = start + "," + end;
      return SEToLocations[key] = (SEToLocations[key] || []).concat(location);
    });
    SEToLocationTree = {};
    for (key in SEToLocations) {
      locations = SEToLocations[key];
      SEToLocationTree[key] = LocationTree.from(locations);
    }
    subIntervalRates = subIntervals.map(function() {
      return [];
    });
    differentialIncidents.forEach(function(incident, incidentId) {
      var incidentSubs, j, len, results, subInterval;
      if (!incident) {
        return;
      }
      incidentSubs = IncidentToSELs[incidentId];
      if (!incidentSubs) {
        console.log("Error: No subintervals for", incidentId);
      }
      results = [];
      for (j = 0, len = incidentSubs.length; j < len; j++) {
        subInterval = incidentSubs[j];
        results.push(subIntervalRates[subInterval.id].push(incident.rate));
      }
      return results;
    });
    subIntervalRates = subIntervalRates.map(function(rates) {
      return _.max(rates.concat(0));
    });
    incomingNodes = [];
    subIntervals.forEach(function(arg) {
      var id;
      id = arg.id;
      return incomingNodes[id] = new Set();
    });
    subIntervals.forEach(function(arg) {
      var end, id, j, len, locationId, locationTree, ltNode, ref, results, start, sublocSubIntId, sublocation;
      id = arg.id, start = arg.start, end = arg.end, locationId = arg.locationId;
      locationTree = SEToLocationTree[start + "," + end];
      ltNode = locationTree.getNodeById(locationId);
      ref = ltNode.children;
      results = [];
      for (j = 0, len = ref.length; j < len; j++) {
        sublocation = ref[j];
        sublocSubIntId = SELToId[start + "," + end + "," + sublocation.value.id];
        results.push(incomingNodes[id].add(sublocSubIntId));
      }
      return results;
    });
    sortedSubIntervalIds = topologicalSort(incomingNodes);
    for (j = 0, len = sortedSubIntervalIds.length; j < len; j++) {
      id = sortedSubIntervalIds[j];
      subLocationTotal = 0;
      incomingNodes[id].forEach(function(incomingNodeId) {
        return subLocationTotal += subIntervalRates[incomingNodeId];
      });
      subIntervalRates[id] = Math.max(subIntervalRates[id], subLocationTotal);
    }
    return subIntervals.forEach(function(subInterval) {
      var duration, end, start;
      start = subInterval.start, end = subInterval.end, duration = subInterval.duration;
      return subInterval.setRate(subIntervalRates[subInterval.id]);
    });
  };

  extendSubIntervalsWithValues = function(incidents, subIntervals, method) {
    if (method == null) {
      method = "topologicalSort";
    }
    if (method === "topologicalSort") {
      return extendSubIntervalsWithValuesTS(incidents, subIntervals);
    } else {
      return extendSubIntervalsWithValuesLP(incidents, subIntervals);
    }
  };

  getContainedSubIntervals = function(containingIncident, subIntsGroupedAndSortedByStart) {
    var j, len, overlappingSubInts, ref, start, subIntervalGroup;
    overlappingSubInts = [];
    for (j = 0, len = subIntsGroupedAndSortedByStart.length; j < len; j++) {
      ref = subIntsGroupedAndSortedByStart[j], start = ref[0], subIntervalGroup = ref[1];
      if (start < Number(containingIncident.startDate)) {
        continue;
      }
      if (start >= Number(containingIncident.endDate)) {
        break;
      }
      overlappingSubInts = overlappingSubInts.concat(subIntervalGroup);
    }
    return overlappingSubInts.filter(function(subInt) {
      return LocationTree.locationContains(containingIncident.locations[0], subInt.location);
    });
  };

  getTopLevelSubIntervals = function(subInts) {
    var locationToSubInts, subIntsByTimeIntervals, tree;
    tree = LocationTree.from(subInts.map(function(x) {
      return x.location;
    }));
    subIntsByTimeIntervals = _.groupBy(subInts, function(subInt) {
      return subInt.start + "," + subInt.end;
    });
    locationToSubInts = _.groupBy(subInts, function(subInt) {
      return subInt.location.id;
    });
    return tree.children.reduce(function(sofar, locationNode) {
      return sofar.concat(locationToSubInts[locationNode.value.id]);
    }, []);
  };

  removeOutlierIncidents = function(originalIncidents, constrainingIncidents) {
    var analysableIncidents, diseases, nonAnalysableIncidents, result;
    nonAnalysableIncidents = [];
    analysableIncidents = [];
    originalIncidents.forEach(function(incident) {
      var analysable;
      analysable = incident.dateRange && (incident.cases || incident.deaths) > 0 && incident.type !== 'activeCount' && incident.locations.length > 0;
      if (analysable) {
        return analysableIncidents.push(incident);
      } else {
        return nonAnalysableIncidents.push(incident);
      }
    });
    result = [];
    diseases = _.chain(analysableIncidents).map(function(x) {
      var ref;
      return (ref = x.resolvedDisease) != null ? ref.id : void 0;
    }).uniq().value();
    diseases.forEach(function(disease) {
      var diseaseMatch;
      diseaseMatch = function(x) {
        var ref;
        return ((ref = x.resolvedDisease) != null ? ref.id : void 0) === disease;
      };
      return result = result.concat(removeOutlierIncidentsSingleDisease(analysableIncidents.filter(diseaseMatch), constrainingIncidents.filter(diseaseMatch)));
    });
    return result.concat(nonAnalysableIncidents);
  };

  removeOutlierIncidentsSingleDisease = function(originalIncidents, constrainingIncidents) {
    var incidents, partitions, resultingConfirmed, resultingDeaths, resultingIncidents;
    incidents = convertAllIncidentsToDifferentials(originalIncidents);
    constrainingIncidents = convertAllIncidentsToDifferentials(constrainingIncidents.filter(function(incident) {
      return !incident.min;
    }));
    partitions = {
      "cases": {
        "confirmed": [],
        "unconfirmed": []
      },
      "deaths": {
        "confirmed": [],
        "unconfirmed": []
      }
    };
    incidents.forEach(function(incident) {
      var status;
      status = incident.status === "confirmed" ? "confirmed" : "unconfirmed";
      return partitions[incident.type][status].push(incident);
    });
    resultingIncidents = [];
    resultingIncidents = removeOutlierIncidentsSingleType(resultingIncidents.concat(partitions["deaths"]["confirmed"]), constrainingIncidents);
    resultingDeaths = removeOutlierIncidentsSingleType(resultingIncidents.concat(partitions["deaths"]["unconfirmed"]), constrainingIncidents.filter(function(x) {
      return x.status !== "confirmed";
    }));
    resultingConfirmed = removeOutlierIncidentsSingleType(resultingIncidents.concat(partitions["cases"]["confirmed"]), constrainingIncidents.filter(function(x) {
      return x.type === "cases";
    }));
    resultingIncidents = removeOutlierIncidentsSingleType(_.union(resultingDeaths, resultingConfirmed, partitions["cases"]["unconfirmed"]), constrainingIncidents.filter(function(x) {
      return x.type === "cases" && x.status !== "confirmed";
    }));
    return _.chain(resultingIncidents).filter(function(x) {
      return !x.__virtualIncident;
    }).pluck('originalIncidents').flatten(true).value();
  };

  removeOutlierIncidentsSingleType = function(incidents, constrainingIncidents) {
    var constrainingSubIntervals, constrainingSubIntervalsByIncident, excessCounts, incidentsByLocationId, intersectionsByIncident, iteration, locationIdToParent, myLocationTree, nextLayer, nodeLayer, subIntervals, subIntsByStart;
    incidentsByLocationId = _.groupBy(incidents, function(x) {
      return x.locations[0].id;
    });
    myLocationTree = LocationTree.from(incidents.map(function(x) {
      return x.locations[0];
    }));
    locationIdToParent = myLocationTree.makeIdToParentMap();
    nodeLayer = myLocationTree.children;
    while (nodeLayer.length > 0) {
      nextLayer = [];
      nodeLayer.forEach(function(node) {
        var idx90thPercentile, incident90thPercentile, incidentGroup, incidentsToKeep, locationId, parent, results, sortedIncidents;
        nextLayer = nextLayer.concat(node.children);
        locationId = node.value.id;
        incidentGroup = incidentsByLocationId[locationId];
        results = [];
        while (true) {
          if (incidentGroup.length >= 10) {
            sortedIncidents = _.sortBy(incidentGroup, 'rate');
            idx90thPercentile = Math.floor((sortedIncidents.length - 1) * .9);
            incident90thPercentile = sortedIncidents[idx90thPercentile];
            incidentsToKeep = sortedIncidents.slice(0, idx90thPercentile);
            sortedIncidents.slice(idx90thPercentile).forEach(function(incident) {
              if (incident.rate < incident90thPercentile.rate * 10) {
                return incidentsToKeep.push(incident);
              }
            });
            incidentsByLocationId[node.value.id] = incidentsToKeep;
            break;
          }
          parent = locationIdToParent[locationId];
          if (parent.value === 'ROOT') {
            break;
          } else {
            locationId = parent.value.id;
            results.push(incidentGroup = incidentGroup.concat(incidentsByLocationId[locationId]));
          }
        }
        return results;
      });
      nodeLayer = nextLayer;
    }
    incidents = _.chain(incidentsByLocationId).values().flatten(true).uniq().value();
    constrainingIncidents = constrainingIncidents.concat(incidents.filter(function(x) {
      return x.cumulative && x.count >= 1;
    }).map(function(x) {
      var result;
      result = Object.create(x);
      result.count = Math.floor(x.count * 1.3);
      return result;
    }));
    constrainingIncidents = _.chain(constrainingIncidents).map(function(x) {
      return x.locations.map(function(loc) {
        var y;
        y = Object.create(x);
        y.locations = [loc];
        return y;
      });
    }).flatten().value();
    incidents = incidents.concat(constrainingIncidents.map(function(x) {
      return x.clone({
        count: 0,
        __virtualIncident: true
      });
    }));
    iteration = 0;
    subIntervals = differentialIncidentsToSubIntervals(incidents);
    subIntsByStart = _.chain(subIntervals).groupBy('start').pairs().map(function(arg) {
      var start, subIntGroup;
      start = arg[0], subIntGroup = arg[1];
      return [parseInt(start), subIntGroup];
    }).sortBy(function(x) {
      return x[0];
    }).value();
    constrainingSubIntervalsByIncident = constrainingIncidents.map(function() {
      return [];
    });
    constrainingSubIntervals = differentialIncidentsToSubIntervals(constrainingIncidents);
    constrainingSubIntervals.forEach(function(subInterval) {
      return subInterval.incidentIds.forEach(function(incidentId) {
        return constrainingSubIntervalsByIncident[incidentId].push(subInterval);
      });
    });
    intersectionsByIncident = constrainingSubIntervalsByIncident.map(function(subIntervalGroup) {
      return _.intersection.apply(null, subIntervalGroup.map(function(subInterval) {
        return subInterval.incidentIds;
      }));
    });
    constrainingIncidents = _.zip(constrainingIncidents, intersectionsByIncident).map(function(arg, incidentId) {
      var constrainingIncident, intersection, remove;
      constrainingIncident = arg[0], intersection = arg[1];
      remove = false;
      _.without(intersection, incidentId).forEach(function(containingIncidentId) {
        if (constrainingIncidents[containingIncidentId].count < constrainingIncident.count) {
          return remove = true;
        }
      });
      if (!remove) {
        return Object.create(constrainingIncident);
      }
    }).filter(function(x) {
      return x;
    });
    constrainingIncidents.forEach(function(cIncident) {
      cIncident.containedSubIntervals = getContainedSubIntervals(cIncident, subIntsByStart);
      return cIncident.topLevelSubIntervals = getTopLevelSubIntervals(cIncident.containedSubIntervals);
    });
    while (incidents.length > 0) {
      subIntervals.forEach(function(subInt) {
        var duration, end, incident, incidentId, incidentIds, j, k, len, lowerMedian, sortedValues, start, v, valueLastIndex, values, valuesByIncident;
        start = subInt.start, end = subInt.end, incidentIds = subInt.incidentIds, duration = subInt.duration;
        valuesByIncident = {};
        for (j = 0, len = incidentIds.length; j < len; j++) {
          incidentId = incidentIds[j];
          incident = incidents[incidentId];
          if (!incident || incident.__virtualIncident) {
            continue;
          }
          valuesByIncident[incidentId] = incident.rate * duration;
        }
        values = _.values(valuesByIncident).concat([0]);
        sortedValues = values.sort();
        lowerMedian = sortedValues[Math.ceil(values.length / 2) - 1];
        subInt.__valuesByIncident = valuesByIncident;
        subInt.__CASIMByIncident = _.object((function() {
          var results;
          results = [];
          for (k in valuesByIncident) {
            v = valuesByIncident[k];
            results.push([k, Math.max(0, v - lowerMedian)]);
          }
          return results;
        })());
        valueLastIndex = {};
        sortedValues.forEach(function(value, index) {
          return valueLastIndex[value] = index;
        });
        return subInt.__marginalValueByIncident = _.object((function() {
          var results;
          results = [];
          for (k in valuesByIncident) {
            v = valuesByIncident[k];
            results.push([k, v - sortedValues[valueLastIndex[v] - 1]]);
          }
          return results;
        })());
      });
      extendSubIntervalsWithValues(incidents, subIntervals);
      excessCounts = 0;
      constrainingIncidents.forEach(function(cIncident) {
        var containedSubInts, difference, incidentId, incidentToMarginalValue, incidentToTotalCASIM, incidentToTotalValue, incidentsRemoved, incidentsSortedByCASIM, j, l, len, len1, len2, m, marginalValueByIncident, marginalValueRemoved, ref, ref1, resolvedSum, results, subInterval, value;
        containedSubInts = cIncident.containedSubIntervals;
        resolvedSum = sum(cIncident.topLevelSubIntervals.map(function(subInt) {
          return subInt.value;
        }));
        difference = resolvedSum - cIncident.count;
        if (difference > 0) {
          excessCounts += 1;
          if (iteration === 0) {
            incidentToTotalValue = {};
            for (j = 0, len = containedSubInts.length; j < len; j++) {
              subInterval = containedSubInts[j];
              ref = subInterval.__valuesByIncident;
              for (incidentId in ref) {
                value = ref[incidentId];
                incidentToTotalValue[incidentId] = (incidentToTotalValue[incidentId] || 0) + value;
              }
            }
            incidentsRemoved = false;
            for (incidentId in incidentToTotalValue) {
              value = incidentToTotalValue[incidentId];
              if (value > cIncident.count) {
                incidents[parseInt(incidentId)] = null;
                incidentsRemoved = true;
              }
            }
            if (incidentsRemoved) {
              return;
            }
          }
          incidentToTotalCASIM = {};
          incidentToMarginalValue = {};
          for (l = 0, len1 = containedSubInts.length; l < len1; l++) {
            subInterval = containedSubInts[l];
            marginalValueByIncident = subInterval.__marginalValueByIncident;
            ref1 = subInterval.__CASIMByIncident;
            for (incidentId in ref1) {
              value = ref1[incidentId];
              incidentToTotalCASIM[incidentId] = (incidentToTotalCASIM[incidentId] || 0) + value;
              incidentToMarginalValue[incidentId] = (incidentToMarginalValue[incidentId] || 0) + marginalValueByIncident[incidentId];
            }
          }
          incidentsSortedByCASIM = _.chain(incidentToTotalCASIM).pairs().map(function(arg) {
            var k, v;
            k = arg[0], v = arg[1];
            return [parseInt(k), v];
          }).sortBy(function(x) {
            return -x[1];
          }).map(function(x) {
            return x[0];
          }).value();
          marginalValueRemoved = 0;
          results = [];
          for (m = 0, len2 = incidentsSortedByCASIM.length; m < len2; m++) {
            incidentId = incidentsSortedByCASIM[m];
            incidents[incidentId] = null;
            marginalValueRemoved += incidentToMarginalValue[incidentId];
            if (marginalValueRemoved >= difference) {
              break;
            } else {
              results.push(void 0);
            }
          }
          return results;
        }
      });
      if (excessCounts === 0) {
        break;
      }
      iteration++;
    }
    return incidents.filter(function(x) {
      return x;
    });
  };

  mergeSubIntervals = function(subIntervals) {
    return subIntervals.reduce(function(sofar, subInterval) {
      var prev;
      prev = sofar.slice(-1)[0];
      if (prev && prev.end === subInterval.start) {
        prev.end = subInterval.end;
        return sofar;
      } else {
        return sofar.concat(Object.create(subInterval));
      }
    }, []);
  };

  createSupplementalIncidents = function(incidents, targetIncidents) {
    var diseases, result;
    result = [];
    diseases = _.chain(incidents.concat(targetIncidents)).map(function(x) {
      var ref;
      return (ref = x.resolvedDisease) != null ? ref.id : void 0;
    }).uniq().value();
    diseases.forEach(function(disease) {
      var diseaseMatch;
      diseaseMatch = function(x) {
        var ref;
        return ((ref = x.resolvedDisease) != null ? ref.id : void 0) === disease;
      };
      return result = result.concat(createSupplementalIncidentsSingleDisease(incidents.filter(diseaseMatch), targetIncidents.filter(diseaseMatch)));
    });
    return result;
  };

  createSupplementalIncidentsSingleDisease = function(incidents, targetIncidents) {
    incidents = convertAllIncidentsToDifferentials(incidents);
    targetIncidents = convertAllIncidentsToDifferentials(targetIncidents.filter(function(incident) {
      return !incident.max;
    }));
    return createSupplementalIncidentsSingleType(_.where(incidents, {
      type: "cases"
    }), _.where(targetIncidents, {
      type: "cases"
    })).concat(createSupplementalIncidentsSingleType(_.where(incidents, {
      type: "deaths"
    }), _.where(targetIncidents, {
      type: "deaths"
    })));
  };

  createSupplementalIncidentsSingleType = function(incidents, targetIncidents) {
    var subIntervals, subIntsByStart, supplementalIncidents;
    supplementalIncidents = [];
    incidents = incidents.concat(targetIncidents.map(function(x) {
      return x.clone({
        count: 0,
        __virtualIncident: true
      });
    }));
    subIntervals = differentialIncidentsToSubIntervals(incidents);
    extendSubIntervalsWithValues(incidents, subIntervals);
    subIntsByStart = _.chain(subIntervals).groupBy('start').pairs().map(function(arg) {
      var start, subIntGroup;
      start = arg[0], subIntGroup = arg[1];
      return [parseInt(start), subIntGroup];
    }).sortBy(function(x) {
      return x[0];
    }).value();
    targetIncidents.forEach(function(targetIncident) {
      var containedSubInts, containedTopLevelSubIntervals, firstStartDate, floorRate, j, lastEndDate, len, nextRateDifference, nextSubInt, ref, ref1, remainingCountDifference, resolvedSum, subInt, subIntsSortedByRate, supplementedSubIntervals, totalNewSubIntDuration;
      containedSubInts = getContainedSubIntervals(targetIncident, subIntsByStart);
      supplementedSubIntervals = [];
      if (containedSubInts.length === 0) {
        targetIncident.locations.forEach(function(TILocation) {
          return supplementedSubIntervals.push(new SubInterval(Number(targetIncident.startDate), Number(targetIncident.endDate), [TILocation], [targetIncident._id], targetIncident.count / targetIncident.locations.length));
        });
      } else {
        firstStartDate = _.max(containedSubInts, function(s) {
          return Number(s.endDate);
        });
        if (Number(targetIncident.startDate) < firstStartDate) {
          targetIncident.locations.forEach(function(TILocation) {
            return supplementedSubIntervals.push(new SubInterval(Number(targetIncident.startDate), firstStartDate, [TILocation], [targetIncident._id], 0));
          });
        }
        lastEndDate = _.min(containedSubInts, function(s) {
          return Number(s.startDate);
        });
        if (Number(targetIncident.endDate) > lastEndDate) {
          targetIncident.locations.forEach(function(TILocation) {
            return supplementedSubIntervals.push(new SubInterval(lastEndDate, Number(targetIncident.endDate), [TILocation], [targetIncident._id], 0));
          });
        }
      }
      containedTopLevelSubIntervals = getTopLevelSubIntervals(containedSubInts);
      resolvedSum = sum(containedTopLevelSubIntervals.map(function(subInt) {
        return subInt.value;
      }));
      remainingCountDifference = targetIncident.count - resolvedSum;
      if (remainingCountDifference <= 0) {
        return;
      }
      subIntsSortedByRate = _.sortBy(containedTopLevelSubIntervals, 'rate');
      floorRate = 0;
      ref = _.zip(subIntsSortedByRate, subIntsSortedByRate.slice(1));
      for (j = 0, len = ref.length; j < len; j++) {
        ref1 = ref[j], subInt = ref1[0], nextSubInt = ref1[1];
        supplementedSubIntervals.push(subInt);
        totalNewSubIntDuration = sum(supplementedSubIntervals.map(function(supSubInt) {
          return supSubInt.duration;
        }));
        if (!nextSubInt) {
          floorRate += remainingCountDifference / totalNewSubIntDuration;
          break;
        }
        nextRateDifference = nextSubInt.rate - subInt.rate;
        if (nextRateDifference * totalNewSubIntDuration >= remainingCountDifference) {
          floorRate += remainingCountDifference / totalNewSubIntDuration;
          break;
        } else {
          remainingCountDifference -= nextRateDifference * totalNewSubIntDuration;
          floorRate = nextSubInt.rate;
        }
      }
      if (floorRate > 0) {
        return supplementalIncidents = supplementalIncidents.concat(mergeSubIntervals(supplementedSubIntervals).map(function(subInt) {
          var duration, end, start;
          start = subInt.start, end = subInt.end, duration = subInt.duration;
          return targetIncident.clone({
            count: floorRate * duration,
            startDate: new Date(start),
            endDate: new Date(end)
          });
        }));
      }
    });
    return supplementalIncidents;
  };

  sum = function(list) {
    return list.reduce(function(sofar, x) {
      return sofar + x;
    }, 0);
  };

  enumerateDateRange = function(start, end) {
    var current, result;
    current = new Date(start);
    end = new Date(end);
    result = [];
    while (current < end) {
      result.push(new Date(current));
      current.setUTCDate(current.getUTCDate() + 1);
      current = new Date(current.toISOString().split('T')[0]);
    }
    return result;
  };

  subIntervalsToDailyRates = function(subIntervals) {
    var dailyRates;
    dailyRates = {};
    subIntervals.forEach(function(subInterval) {
      return enumerateDateRange(subInterval.start, subInterval.end).forEach(function(date) {
        var day;
        day = date.toISOString().split('T')[0];
        return dailyRates[day] = (dailyRates[day] || 0) + subInterval.rate;
      });
    });
    return _.sortBy(_.pairs(dailyRates), function(x) {
      return x[0];
    });
  };

  dailyRatesToActiveCases = function(dailyRates, dailyDecayRate, dateWindow) {
    var activeCases, activeCasesByDay, firstRateDay, startDate;
    startDate = new Date(dateWindow.startDate).toISOString().split('T')[0];
    activeCases = 0;
    firstRateDay = dailyRates.length > 0 ? dailyRates[0][0] : startDate;
    dailyRates = _.object(dailyRates);
    return activeCasesByDay = enumerateDateRange(Math.min(new Date(startDate), new Date(firstRateDay)), dateWindow.endDate).map(function(date) {
      var day, rate;
      day = date.toISOString().split('T')[0];
      rate = dailyRates[day] || 0;
      activeCases = activeCases * dailyDecayRate + rate;
      return [day, activeCases];
    }).filter(function(arg) {
      var day, noop;
      day = arg[0], noop = arg[1];
      return day >= startDate;
    });
  };

  subIntervalsToActiveCases = function(subIntervals, dailyDecayRate, dateWindow) {
    return dailyRatesToActiveCases(subIntervalsToDailyRates(subIntervals), dailyDecayRate, dateWindow);
  };

  mapLocationsToMaxSubIntervals = function(locationTree, subIntervals) {
    var j, l, len, len1, len2, locToSubintervals, location, m, ref, ref1, subInterval, subLocation;
    locToSubintervals = {};
    ref = locationTree.locations();
    for (j = 0, len = ref.length; j < len; j++) {
      location = ref[j];
      locToSubintervals[location.id] = [];
    }
    ref1 = locationTree.locations();
    for (l = 0, len1 = ref1.length; l < len1; l++) {
      location = ref1[l];
      for (m = 0, len2 = subIntervals.length; m < len2; m++) {
        subInterval = subIntervals[m];
        subLocation = subInterval.location;
        if (LocationTree.locationContains(location, subLocation)) {
          locToSubintervals[location.id].push(subInterval);
        }
      }
    }
    return _.chain(locToSubintervals).pairs().map((function(_this) {
      return function(arg) {
        var group, groupedLocSubIntervals, locId, locSubIntervals, maxSubintervals, subIntervalGroup, subIntervalGroupTree;
        locId = arg[0], locSubIntervals = arg[1];
        location = locationTree.getLocationById(locId);
        groupedLocSubIntervals = _.groupBy(locSubIntervals, 'start');
        maxSubintervals = [];
        for (group in groupedLocSubIntervals) {
          subIntervalGroup = groupedLocSubIntervals[group];
          subIntervalGroupTree = LocationTree.from(subIntervalGroup.map(function(x) {
            return x.location;
          }));
          subIntervalGroupTree.children.forEach(function(locationNode) {
            return maxSubintervals.push(_.max(subIntervalGroup, function(subInterval) {
              if (locationNode.value.id === subInterval.location.id) {
                return subInterval.value;
              } else {
                return 0;
              }
            }));
          });
        }
        return [locId, maxSubintervals];
      };
    })(this)).object().value();
  };

  module.exports = {
    intervalToEndpoints: intervalToEndpoints,
    differentialIncidentsToSubIntervals: differentialIncidentsToSubIntervals,
    subIntervalsToLP: subIntervalsToLP,
    extendSubIntervalsWithValues: extendSubIntervalsWithValues,
    removeOutlierIncidents: removeOutlierIncidents,
    createSupplementalIncidents: createSupplementalIncidents,
    subIntervalsToActiveCases: subIntervalsToActiveCases,
    dailyRatesToActiveCases: dailyRatesToActiveCases,
    subIntervalsToDailyRates: subIntervalsToDailyRates,
    enumerateDateRange: enumerateDateRange,
    mapLocationsToMaxSubIntervals: mapLocationsToMaxSubIntervals,
    convertAllIncidentsToDifferentials: convertAllIncidentsToDifferentials,
    LocationTree: LocationTree
  };

}).call(this);
