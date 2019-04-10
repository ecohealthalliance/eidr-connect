module.exports = function () {
  var ENABLE_PROFILING = process.env.ENABLE_PROFILING || false;
  var IRLib = require('incident-resolution');
  var _ = require('underscore');
  self.onmessage = function({data}) {
    try {
      var event = data;
      var baseIncidents = [];
      var constrainingIncidents = _.clone(event.constrainingIncidents) || [];
      (event.incidents || []).map(function(incident) {
        if (incident.constraining) {
          constrainingIncidents.push(incident);
        } else {
          baseIncidents.push(incident);
        }
      });
      if (ENABLE_PROFILING) console.time('remove outliers');
      var incidentsWithoutOutliers = IRLib.removeOutlierIncidents(baseIncidents, constrainingIncidents, event.params || {});
      if (ENABLE_PROFILING) console.timeEnd('remove outliers');
      if (ENABLE_PROFILING) console.time('create supplemental incidents');
      var supplementalIncidents = IRLib.createSupplementalIncidents(incidentsWithoutOutliers, constrainingIncidents);
      if (ENABLE_PROFILING) console.timeEnd('create supplemental incidents');
      if (ENABLE_PROFILING) console.time('create differentials');
      var allDifferentials = IRLib.convertAllIncidentsToDifferentials(incidentsWithoutOutliers).concat(supplementalIncidents);
      if (ENABLE_PROFILING) {
        console.log("baseIncidents: " + baseIncidents.length);
        console.log("constrainingIncidents: " + constrainingIncidents.length);
        console.log("incidentsWithoutOutliers: " + incidentsWithoutOutliers.length);
        console.log("supplementalIncidents: " + supplementalIncidents.length);
      }
      var differentials = _.where(allDifferentials, {
        type: event.incidentType || 'cases'
      }).filter(function(differential) {
        if(!event.resolvedDateRange) return true;
        if (differential.startDate > event.resolvedDateRange.end) {
          return false;
        }
        if (differential.endDate < event.resolvedDateRange.start) {
          return false;
        }
        return true;
      }).map(function(differential) {
        if (event.resolvedDateRange) {
          differential = differential.truncated(event.resolvedDateRange);
        }
        return differential;
      }).filter(function(differential) {
        return differential.duration > 0;
      });
      var subIntervals = IRLib.differentialIncidentsToSubIntervals(differentials);
      if (ENABLE_PROFILING) console.timeEnd('create differentials');
      if (ENABLE_PROFILING) console.time('resolve');
      IRLib.extendSubIntervalsWithValues(differentials, subIntervals);
      if (ENABLE_PROFILING) console.timeEnd('resolve');
      subIntervals.forEach(function(subInterval){
        subInterval.originalIncidentIds = [];
        subInterval.incidentIds.forEach(function(incidentId){
          differentials[incidentId].originalIncidents.forEach(function(originalIncident){
            subInterval.originalIncidentIds.push(event.incidents.indexOf(originalIncident));
          });
        });
      });
      return postMessage({
        result: subIntervals
      });
    } catch (error) {
      return postMessage({
        error: error.toString()
      });
    }
  };
};