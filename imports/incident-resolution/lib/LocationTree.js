// Generated by CoffeeScript 1.12.7
(function() {
  var LocationTree, locationContains, locationsToLocationTree, regionToCountries,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  regionToCountries = require('../regionToCountries.json');

  locationContains = function(locationA, locationB) {
    var containmentLevel, featureCode, i, len, prop, props, ref, ref1;
    props = ['countryName', 'admin1Name', 'admin2Name'];
    if (locationA.id === locationB.id) {
      return true;
    }
    if (locationA.id === "6295630") {
      return true;
    }
    if (locationA.id in regionToCountries) {
      return ref = locationB.countryCode, indexOf.call(regionToCountries[locationA.id].countryISOs, ref) >= 0;
    }
    featureCode = locationA.featureCode || "";
    if (featureCode.startsWith("PCL")) {
      containmentLevel = 1;
    } else if (featureCode.startsWith("ADM1")) {
      containmentLevel = 2;
    } else if (featureCode.startsWith("ADM2")) {
      containmentLevel = 3;
    } else {
      return false;
    }
    ref1 = props.slice(0, containmentLevel);
    for (i = 0, len = ref1.length; i < len; i++) {
      prop = ref1[i];
      if (!(prop in locationB) || locationB[prop] === '') {
        return false;
      }
      if (locationA[prop] !== locationB[prop]) {
        return false;
      }
    }
    return true;
  };

  locationsToLocationTree = function(locations) {
    var locationTree;
    locationTree = new LocationTree("ROOT");
    locations.forEach(function(location) {
      var child, contained, i, idx, len, node, ref, ref1, uncontained;
      node = locationTree.search(location);
      if (((ref = node.value) != null ? ref.id : void 0) === location.id) {
        return;
      }
      contained = [];
      uncontained = [];
      ref1 = node.children;
      for (idx = i = 0, len = ref1.length; i < len; idx = ++i) {
        child = ref1[idx];
        if (locationContains(location, child.value)) {
          contained.push(child);
        } else {
          uncontained.push(child);
        }
      }
      if (contained.length > 0) {
        return node.children = uncontained.concat(new LocationTree(location, contained));
      } else {
        return node.children.push(new LocationTree(location));
      }
    });
    return locationTree;
  };

  LocationTree = (function() {
    function LocationTree(value, children) {
      var ref;
      this.value = value;
      this.children = children != null ? children : [];
      if (this.value !== "ROOT") {
        if (!((ref = this.value) != null ? ref.id : void 0)) {
          console.log(this.value);
          throw new Error("Invalid location");
        }
      }
    }

    LocationTree.prototype.search = function(location) {
      var containingNode, i, len, ref, subtree;
      if (this.value === "ROOT" || locationContains(this.value, location)) {
        ref = this.children;
        for (i = 0, len = ref.length; i < len; i++) {
          subtree = ref[i];
          containingNode = subtree.search(location);
          if (containingNode) {
            return containingNode;
          }
        }
        return this;
      } else {
        return null;
      }
    };

    LocationTree.prototype.getNodeById = function(locationId) {
      var i, len, ref, result, subTree;
      if (!locationId) {
        return null;
      }
      if (this.value.id === locationId) {
        return this;
      } else {
        ref = this.children;
        for (i = 0, len = ref.length; i < len; i++) {
          subTree = ref[i];
          result = subTree.getNodeById(locationId);
          if (result) {
            return result;
          }
        }
      }
      return null;
    };

    LocationTree.prototype.getLocationById = function(locationId) {
      var ref;
      return (ref = this.getNodeById(locationId)) != null ? ref.value : void 0;
    };

    LocationTree.prototype.contains = function(location) {
      return locationContains(this.value, location);
    };

    LocationTree.prototype.locations = function(location) {
      var i, len, ref, result, subTree;
      result = [this.value];
      if (this.value === "ROOT") {
        result = [];
      }
      ref = this.children;
      for (i = 0, len = ref.length; i < len; i++) {
        subTree = ref[i];
        result = result.concat(subTree.locations());
      }
      return result;
    };

    LocationTree.prototype.makeIdToParentMap = function(sofar) {
      var result;
      if (sofar == null) {
        sofar = null;
      }
      result = sofar || {};
      this.children.map((function(_this) {
        return function(child) {
          result = child.makeIdToParentMap(result);
          return result[child.value.id] = _this;
        };
      })(this));
      return result;
    };

    LocationTree.prototype.toJSON = function(transformationFunction) {
      if (transformationFunction == null) {
        transformationFunction = function(x) {
          return x;
        };
      }
      return transformationFunction({
        value: this.value,
        children: this.children.map(function(child) {
          return child.toJSON(transformationFunction);
        })
      });
    };

    return LocationTree;

  })();

  LocationTree.from = locationsToLocationTree;

  LocationTree.locationContains = locationContains;

  module.exports = LocationTree;

}).call(this);
