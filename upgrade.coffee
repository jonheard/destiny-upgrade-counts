#knockout object to hold all the different data
class Item
  constructor: (data)->
    ko.mapping.fromJS(data, {}, @)
#knockout object to hold the totals to update display
class Totals
  constructor: ->
    @names = ko.observableArray([])
    # group names and totals. I could not figure out how to loop over names in the
    # knockout html and access the data still
    @list = ko.computed( =>
      [name, @[name]()] for name in @names()
    )
  add: (name,count) =>
    # if we already have it add it. If not create observable. Add list to name as a key.
    if @[name]
      @[name](@[name]()+count)
    else
      @[name] = ko.observable(count)
      @names.push(name)

class Upgrader
  baseInventoryUrl: "http://www.bungie.net/Platform/Destiny/1/Account/ACCOUNT_ID_SUB/Character/CHARACTER_ID_SUB/Inventory/IIID_SUB/?lc=en&fmt=true&lcin=true&definitions=true"
  constructor: ->
    @accountID = null
    @characterID = null
    @items = ko.observableArray()
    @totals = new Totals
    @setIDs()
    @processItems()
    @error = ko.observable(false)

  processItems: ->
    # use bungie js model to key the values. Just a double loop of arrays
    for item in tempModel.inventory.buckets.Equippable
      for object in item.items
        @addItem(object.itemHash, object.itemInstanceId, {"instance": object, "data": DEFS["items"][object.itemHash]})

  setIDs: ->
    #simple regex.
    matches = window.location.pathname.match(/(.+)\/(\d+)\/(\d+)/)
    @accountID = matches[2]
    @characterID = matches[3]
  #turn [{x: 5, y:6}, {x:5, y:7}}] in to {5: [{x: 5, y:6}, {x:5, y:7}}}
  #usefully for grouping items over different arrays
  group_by: (array, key) ->
    items = {}
    for item in array
      (items[item[key]] or= []).push item
    items

  addItem: (hashid, iiid, base_object) =>
    url = @baseInventoryUrl.replace("ACCOUNT_ID_SUB", @accountID).replace("CHARACTER_ID_SUB", @characterID).replace("IIID_SUB", iiid)

    $.ajax({
      url: url, type: "GET",
      beforeSend: (xhr) ->
        #setup headers
        #Accept Might not be needed. I noticed this was used in the bungie requests
        xhr.setRequestHeader('Accept', "application/json, text/javascript, */*; q=0.01")
        #This are mostly auth headers. API token and other needed values.
        for key,value of bungieNetPlatform.getHeaders()
          xhr.setRequestHeader(key, value)
    }).done (item_json) =>
      material_list = []
      for talentNodes in item_json["Response"]["data"]["talentNodes"]
        for material in talentNodes.materialsToUpgrade
          #name and other details is stored under definitions. Then the instance for you is under data.
          #This is so you always have the details for what you are displaying. If parts is in the data list
          #50 times you only see general details for parts once instead of 50. Helps on space?
          material["name"] = item_json["Response"]["definitions"]["items"][material.itemHash]["itemName"]
          material_list.push(material)
      #should look like {"Helium Filaments": [...], "Ascendant Energy": [..]}
      materials = @group_by(material_list, "name")
      #storing data to use for later.
      base_object["json"] = item_json
      base_object["material"] = materials
      clean_list = {}
      #like ruby's inject. count for each material
      #store the over all total too. We could count this on the way out as well.
      for name, ms of materials
        total = 0
        total = total+ m.count for m in ms
        @totals.add(name,total)
        clean_list[name] = total
      clean_array = ({name: name, total: total} for name, total of clean_list)
      base_object["material_names"] = clean_list
      base_object["material_array"] = clean_array
      @items.push(new Item(base_object))

window.upgrader = new Upgrader
unless $('.upgrader')[0]
  $(".nav_top").append("<li class='upgrader' style='width:300px;clear:left;background-color:white;min-height:10px;max-height:550px;overflow-x:auto'>
    <div style='height:20px'>
      <a href='#' onclick='$(\"#upgrader-data\").toggle();return false;'>UPGRADES</a>
    </div>
    <span id='upgrader-data'>
      <ul class='totals' data-bind='foreach: totals.list()'>
        <li data-bind=\"text: $data[0]+': '+$data[1]\"></li>
      </ul>
      <ul class='totals' data-bind='foreach: items'>
        <!-- ko if: material_array()[0] -->
          <li class='item' style='border-bottom: solid 1px'>
            <span data-bind='text: data.itemName()'></span>
            <ul data-bind='foreach: material_array()'>
              <li style='color:#B5B7A4;background-color:#4D5F5F' data-bind=\"text: name()+': '+total()\"></li>
            </ul>
          </li>
        <!-- /ko -->
      </ul>
    </span>
  </li>")
  #bind my object to my new dom element
  ko.applyBindings(window.upgrader, $('.upgrader')[0])
