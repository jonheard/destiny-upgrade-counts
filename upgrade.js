// Generated by CoffeeScript 1.8.0
(function() {
  var Item, Totals, Upgrader,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  Item = (function() {
    function Item(data) {
      ko.mapping.fromJS(data, {}, this);
    }

    return Item;

  })();

  Totals = (function() {
    function Totals() {
      this.add = __bind(this.add, this);
      this.names = ko.observableArray([]);
      this.list = ko.computed((function(_this) {
        return function() {
          var name, _i, _len, _ref, _results;
          _ref = _this.names();
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            name = _ref[_i];
            _results.push([name, _this[name]()]);
          }
          return _results;
        };
      })(this));
    }

    Totals.prototype.add = function(name, count) {
      if (this[name]) {
        return this[name](this[name]() + count);
      } else {
        this[name] = ko.observable(count);
        return this.names.push(name);
      }
    };

    return Totals;

  })();

  Upgrader = (function() {
    Upgrader.prototype.baseInventoryUrl = "http://www.bungie.net/Platform/Destiny/1/Account/ACCOUNT_ID_SUB/Character/CHARACTER_ID_SUB/Inventory/IIID_SUB/?lc=en&fmt=true&lcin=true&definitions=true";

    function Upgrader() {
      this.addItem = __bind(this.addItem, this);
      this.accountID = null;
      this.characterID = null;
      this.items = ko.observableArray();
      this.totals = new Totals;
      this.setIDs();
      this.processItems();
    }

    Upgrader.prototype.processItems = function() {
      var item, object, _i, _len, _ref, _results;
      _ref = tempModel.inventory.buckets.Equippable;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        _results.push((function() {
          var _j, _len1, _ref1, _results1;
          _ref1 = item.items;
          _results1 = [];
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            object = _ref1[_j];
            _results1.push(this.addItem(object.itemHash, object.itemInstanceId, {
              "instance": object,
              "data": DEFS["items"][object.itemHash]
            }));
          }
          return _results1;
        }).call(this));
      }
      return _results;
    };

    Upgrader.prototype.setIDs = function() {
      var matches;
      matches = window.location.pathname.match(/(.+)\/(\d+)\/(\d+)/);
      this.accountID = matches[2];
      return this.characterID = matches[3];
    };

    Upgrader.prototype.group_by = function(array, key) {
      var item, items, _i, _len, _name;
      items = {};
      for (_i = 0, _len = array.length; _i < _len; _i++) {
        item = array[_i];
        (items[_name = item[key]] || (items[_name] = [])).push(item);
      }
      return items;
    };

    Upgrader.prototype.addItem = function(hashid, iiid, base_object) {
      var url;
      url = this.baseInventoryUrl.replace("ACCOUNT_ID_SUB", this.accountID).replace("CHARACTER_ID_SUB", this.characterID).replace("IIID_SUB", iiid);
      return $.ajax({
        url: url,
        type: "GET",
        beforeSend: function(xhr) {
          var key, value, _ref, _results;
          xhr.setRequestHeader('Accept', "application/json, text/javascript, */*; q=0.01");
          _ref = bungieNetPlatform.getHeaders();
          _results = [];
          for (key in _ref) {
            value = _ref[key];
            _results.push(xhr.setRequestHeader(key, value));
          }
          return _results;
        }
      }).done((function(_this) {
        return function(item_json) {
          var clean_array, clean_list, m, material, material_list, materials, ms, name, talentNodes, total, _i, _j, _k, _len, _len1, _len2, _ref, _ref1;
          material_list = [];
          _ref = item_json["Response"]["data"]["talentNodes"];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            talentNodes = _ref[_i];
            _ref1 = talentNodes.materialsToUpgrade;
            for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
              material = _ref1[_j];
              material["name"] = item_json["Response"]["definitions"]["items"][material.itemHash]["itemName"];
              material_list.push(material);
            }
          }
          materials = _this.group_by(material_list, "name");
          base_object["json"] = item_json;
          base_object["material"] = materials;
          clean_list = {};
          for (name in materials) {
            ms = materials[name];
            total = 0;
            for (_k = 0, _len2 = ms.length; _k < _len2; _k++) {
              m = ms[_k];
              total = total + m.count;
            }
            _this.totals.add(name, total);
            clean_list[name] = total;
          }
          clean_array = (function() {
            var _results;
            _results = [];
            for (name in clean_list) {
              total = clean_list[name];
              _results.push({
                name: name,
                total: total
              });
            }
            return _results;
          })();
          base_object["material_names"] = clean_list;
          base_object["material_array"] = clean_array;
          return _this.items.push(new Item(base_object));
        };
      })(this));
    };

    return Upgrader;

  })();

  window.upgrader = new Upgrader;

  $(".nav_top").append("<li class='upgrader' style='width:300px;clear:left;background-color:white;min-height:10px;max-height:550px;overflow-x:auto'> <div style='height:20px'> <a href='#' onclick='$(\"#upgrader-data\").toggle();return false;'>UPGRADES</a> </div> <span id='upgrader-data'> <ul class='totals' data-bind='foreach: totals.list()'> <li data-bind=\"text: $data[0]+': '+$data[1]\"></li> </ul> <ul class='totals' data-bind='foreach: items'> <!-- ko if: material_array()[0] --> <li class='item' style='border-bottom: solid 1px'> <span data-bind='text: data.itemName()'></span> <ul data-bind='foreach: material_array()'> <li style='color:#B5B7A4;background-color:#4D5F5F' data-bind=\"text: name()+': '+total()\"></li> </ul> </li> <!-- /ko --> </ul> </span> </li>");

  ko.applyBindings(window.upgrader, $('.upgrader')[0]);

}).call(this);
