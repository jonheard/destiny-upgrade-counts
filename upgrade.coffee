#knockout object to hold all the different data
class Item
  constructor: (data)->
    ko.mapping.fromJS(data, {}, @)
    @material_list = ko.computed( =>
      list = []
      for talentNodes in @json["Response"]["data"]["talentNodes"]()
        for material in talentNodes.materialsToUpgrade()
          #name and other details is stored under definitions. Then the instance for you is under data.
          #This is so you always have the details for what you are displaying. If parts is in the data list
          #50 times you only see general details for parts once instead of 50. Helps on space?
          material["name"] = @json["Response"]["definitions"]["items"][material.itemHash()]["itemName"]()
          list.push(material)
      list
    )

    @materials = ko.computed( =>
      group = @group_by(@material_list(), "name")
      group
    )

    @getStat = (statName) ->
      if @instance.stats?
        for stat in @instance.stats()
          if DEFS.stats[stat.statHash()].statName == statName
            return stat
        return undefined
      else
        undefined

    @material_names = ko.computed( =>
      clean_list = {}
      #count for each material
      #store the over all total too. We could count this on the way out as well.
      for name, ms of @materials()
        total = 0
        for m in ms
          total = total+ m.count()
        clean_list[name] = total

      clean_list
    )

    @material_array = ko.computed( =>
      array= ({name: name, total: total} for name, total of @material_names())
      array
    )
  group_by: (array, key) ->
    items = {}
    for item in array
      if item[key]
        (items[item[key]] or= []).push item
    items

  displayName: ->
    name = "#{@data.itemName()} #{@damageType()}: #{@bucket.bucketName()}"
    name += " Vault" if @vault()
    name

  check_vault: ->
    !@vault()

  materialsByTier: ->
    #memoize
    materialByTier = {}
    for hash in @json.Response.data.materialItemHashes()
      item = @json.Response.definitions.items[hash]
      materialByTier[item.tierTypeName()] or= []
      materialByTier[item.tierTypeName()].push(item.itemName())
    materialByTier

  damageType: ->
    if @instance.damageType?  && upgrader.damageTypes[@instance.damageType()] != "None"
      upgrader.damageTypes[@instance.damageType()]
    else
      ""

  primaryStat: ->
    if @instance.primaryStat?
      @instance.primaryStat.value()
    else
      ""
  csv: (stats_header, material_name_list)->
    item_csv = [@data.itemName(), @damageType(), @data.itemTypeName(), @data.tierTypeName(), @data.qualityLevel(), @primaryStat()]
    stat_csv = []
    for stat in stats_header
      found_stat = (instace_stat for instace_stat in  @instance.stats() when instace_stat.statHash() == stat)[0]
      if found_stat
        stat_csv[stats_header.indexOf(stat)] = found_stat.value()
      else
        stat_csv[stats_header.indexOf(stat)] = ""
    perk_string = ""
    first = true
    for perk in @instance.perks()
      unless first
        perk_string += ", "
      perk_string += "#{@json.Response.definitions.perks[perk.perkHash()].displayName()}"
      first = false
    mat_data = []
    for name in material_name_list
      count = 0
      if @material_names()[name]
        count = @material_names()[name]
      mat_data.push(count)

    string = item_csv.concat(stat_csv, ["\"#{perk_string}\""], mat_data).join()
    string

#knockout object to hold the totals to update display
class Totals
  constructor: ->
    @names = ko.observableArray([])
    # group names and totals. I could not figure out how to loop over names in the
    # knockout html and access the data still
    @list = ko.computed( =>
      [name, @[name]()] for name in @names()
    )
  count: (name) =>
    if @[name]
      @[name]()
    else
      0
  add: (name,count) =>
    # if we already have it add it. If not create observable. Add list to name as a key.
    if @[name]
      @[name](@[name]()+count)
    else
      @[name] = ko.observable(count)
      @names.push(name)

class Upgrader
  baseInventoryUrl: window.location.protocol+"//www.bungie.net/Platform/Destiny/ACCOUNT_TYPE_SUB/Account/ACCOUNT_ID_SUB/Character/CHARACTER_ID_SUB/Inventory/IIID_SUB/?lc=en&fmt=true&lcin=true&definitions=true"
  vaultInventoryUrl: window.location.protocol+"//www.bungie.net/Platform/Destiny/ACCOUNT_TYPE_SUB/MyAccount/Character/CHARACTER_ID_SUB/Vendor/VENDOR_ID/?lc=en&fmt=true&lcin=true&definitions=true"
  constructor: ->
    @accountID = null
    @characterID = ko.observable(null)
    @accountType = null
    @pageLoading= ko.observable(false)
    @items = ko.observableArray()
    @ownedTotals = new Totals
    @vaultLoaded = ko.observable(false) # can be computed if any items have vault
    @displayVault = ko.observable(false)
    @error = ko.observable(false)
    @damageTypes =  new Array(Object.keys(Globals.DamageType).length)
    for damage, index of Globals.DamageType
      @damageTypes[index] = damage

    @setIDs()
    setInterval(=>
      loading = bnet._pageController.isLoadingPage
      if loading != @pageLoading()
        @pageLoading(loading)
    , 500)

    @pageLoadingChange = ko.computed =>
      #if the value changes from from true to false
      #the page should be done loading.
      if !@pageLoading()
        @setIDs()
        @reset()

    @totals = ko.computed =>
      total = new Totals
      for item in @items() when @displayVault() || !item.vault()
        for name, count of item.material_names()
          total.add(name,count)
      total

    @itemsCSV = ko.computed( ()=>
      header = ["Name", "Damage", "Type", "Tier", "Quality Level", "Primary Stat"]
      stats_header = []
      for id, data of DEFS.stats
        stats_header.push(parseInt(id,10))
        header.push(data.statName)
      mat_names = @total_object().names()
      header.push("Perks")
      header = header.concat(mat_names)
      csv = [header.join()]
      for item in @items()
        if ["BUCKET_HEAD", "BUCKET_ARMS", "BUCKET_CHEST", "BUCKET_LEGS","BUCKET_VAULT_ARMOR", "BUCKET_VAULT_WEAPONS", "BUCKET_SPECIAL_WEAPON","BUCKET_HEAVY_WEAPON","BUCKET_PRIMARY_WEAPON"].indexOf(item.bucket.bucketIdentifier())>=0
          csv.push(item.csv(stats_header, mat_names))
      csv.join("\n")
    )

  reset: ->
    @items([])
    @ownedTotals = new Totals
    @vaultLoaded(false)
    @displayVault(false)
    @error(false)
    try
      @processItems()
      @venderTimeout = setInterval(=>
        @processVault()
      , 600)
    catch error
      @error("There was a problem loading the site: #{error}")


  total_object: ->
    @totals()

  processVault: ->
    vendor_id = null
    if DEFS.vendorDetails
      for id, obj of DEFS.vendorDetails
        vendor_id = id
    if vendor_id
      clearInterval(@venderTimeout)
      @vaultLoaded(true)
      url = @vaultInventoryUrl.replace("CHARACTER_ID_SUB", @characterID()).replace("VENDOR_ID", vendor_id).replace("ACCOUNT_TYPE_SUB", @accountType)
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
        for bucket in item_json["Response"]["data"]["inventoryBuckets"]
          for item in bucket.items
            datas = item_json["Response"]["definitions"]["items"][item.itemHash]
            if @ownedTotals[datas.itemName]
              @ownedTotals.add(datas.itemName, item.stackSize)

            @addItem(item.itemInstanceId, {"vault": true, "data": datas, "instance":item, "bucket": item_json["Response"]["definitions"]["buckets"][bucket.bucketHash]})
    else

  processItems: ->
    # use bungie js model to key the values. Just a double loop of arrays
    for item in tempModel.equippables
      for object in item.items
        data = DEFS["items"][object.itemHash]
        @addItem(object.itemInstanceId, {"vault": false, "instance": object, "data": data, "bucket": DEFS['buckets'][data.bucketTypeHash]})
    #equipped only
    #
    #for bucket in tempModel.inventory.buckets.Item
    #  if DEFS.buckets[bucket.bucketHash].bucketIdentifier == "BUCKET_MATERIALS"
    #    for item in bucket.items
    #      name = DEFS["items"][item.itemHash].itemName
    #      @ownedTotals.add(name, item.stackSize)

  setIDs: ->
    #simple regex.
    matches = window.location.pathname.match(/(.+)(\d+)\/(\d+)\/(\d+)/)
    @accountType = matches[2]
    @accountID = matches[3]
    @characterID(matches[4])

  addItem: (iiid, base_object) =>
    url = @baseInventoryUrl.replace("ACCOUNT_ID_SUB", @accountID).replace("CHARACTER_ID_SUB", @characterID()).replace("IIID_SUB", iiid).replace("ACCOUNT_TYPE_SUB", @accountType)

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
      base_object["json"] = item_json
      @items.push(new Item(base_object))

window.upgrader = new Upgrader

unless $('.upgrader')[0]
  colors =
    primary: '#21252B'
    secondary: '#2D3137'
    tertiary: '#393F45'

  $(".nav_top").append("
  <style>
    .upgrader {
      width: 300px;
      min-height: 10px;
      max-height: 550px;
      clear: left;
      background-color: #{colors.primary};
      color: #fff;
      padding: 0 .5em;
      overflow-x: auto;
      border-bottom: #{colors.primary} solid 1px;
      border-radius: 0 0 0 5px;
    }
    .upgrader .header {
      height: 20px;
      padding: .5em 0;
    }
    .upgrader .header span {
      cursor: pointer;
      float: left;
    }
    .upgrader .header label {
      float: right;
    }
    .upgrader .totals {
      background: #{colors.secondary};
      border-radius: 5px;
      padding: .5em;
    }
    .upgrader .item {
      background: #{colors.secondary};
      border-radius: 5px;
      margin:.5em 0;
    }
    .upgrader .item span {
      padding: .25em .5em;
      display: inline-block;
    }
    .upgrader .item ul {
      background: #{colors.tertiary};
      border-radius: 0 0 5px 5px;
      padding:.25em .5em;
    }
  </style>
  <li class='upgrader'>
    <div class='header'>
      <!-- ko ifnot: error -->
        <span onclick='$(\"#upgrader-data\").toggle();return false;'>
          UPGRADES
        </span>
        <label>
          <input type='checkbox' data-bind='checked: displayVault, attr: {disabled: !vaultLoaded()}' />
          <!-- ko ifnot: vaultLoaded()-->
            Click Gear for Vault
          <!-- /ko -->
          <!-- ko if: vaultLoaded()-->
            Include Vault
          <!-- /ko -->
        </label>
      <!-- /ko -->
      <!-- ko if: error -->
        <span data-bind='text: error'></span>
      <!-- /ko -->
    </div>
    <span id='upgrader-data' data-bind='ifnot: error'>
      <ul>
        <li class='item'>
          <span>Total counts(owned)</span>
          <ul class='totals' data-bind='foreach: totals().list()'>
            <li data-bind=\"text: $data[0]+': '+$data[1]+'('+$parent.ownedTotals.count($data[0])+')'\"></li>
          </ul>
        </li>
      </ul>
      <ul class='item-totals' data-bind='foreach: items'>
        <!-- ko if:(material_array()[0] && ($parent.displayVault() || !vault())) -->
          <li class='item'>
            <span data-bind='text: displayName()'></span>
            <ul data-bind='foreach: material_array()'>
              <li data-bind=\"text: name+': '+total\"></li>
            </ul>
          </li>
        <!-- /ko -->
      </ul>

      <span onclick='$(\"#upgrader-data\").hide();$(\"#itemsCSV\").show();return false;'>
        CSV ->
      </span>
    </span>
    <span id='itemsCSV'>
      <span onclick='$(\"#upgrader-data\").show();$(\"#itemsCSV\").hide();return false;'>
        <- Back to Display
      </span>
      <pre data-bind='text: itemsCSV()'></pre>
    </span>
  </li>")
  $('#itemsCSV').hide()
  #bind my object to my new dom element
  ko.applyBindings(window.upgrader, $('.upgrader')[0])

