require('zappa') ->
  @io.set( "log level", 1 )

  dbname = 'test'
  mongolian = require 'mongolian'
  server = new mongolian()
  db = server.db 'feed'
  article = db.collection 'article'

  cp = require 'child_process'
  request = require 'request'
  readability = require 'readability'
  # express setting
  @use "static",@app.router
    , @express.cookieParser()
    , @express.session
      secret: "mykey"
      cookie: { maxAge: 86400 * 1000 }
    , @express.methodOverride()
    , @express.bodyParser()
    , @express.favicon()
  @set 'views', __dirname + '/views'
  @enable 'serve jquery'

  @shared "/shared.js":->
    r = window ? global
    r.d = (e)-> console.log e

  @client '/bootstrap.js': ->
    window.ck = CoffeeKup
    window.Article = ->

    class Article
      constructor:(obj)->
        @title = ko.observable obj.title
        @link = ko.observable obj.link
        @updated = ko.observable obj.updated
        @src = ko.observable obj.src
        @summary = ko.observable (obj.summary_detail?.value or "")

    window.view =
      context : ko.observable 'All Articles'
      page : ko.observable 1
      entries : ko.observableArray []
      cursor : ko.observable 0
      sources : ko.observableArray []
      source_cursor : ko.observable null
      add : (obj)->
        @entries.push new Article(obj)

      click_pager :(event)->
        t = event.target
        n = parseInt $(t).text()
        $("div.pagination li").removeClass 'active'
        $(t).parent().addClass 'active'
        # view.reload page:n,unread:true
        soc.emit 'reload', page:n,unread:true

      open_source:(event)->
        t = event.target
        url = parseInt $(t).attr 'href'
        @reload {link:url,page:1}

    view.selected_entry = ko.dependentObservable ->
      return view.entries()[view.cursor()]

    view.selected_source = ko.dependentObservable ->
      return view.sources()[view.source_cursor()]

    # open in background-tab
    window.open = (url, name) ->
      return native_open(url, name)  if url == undefined
      a = document.createElement("a")
      a.href = url
      a.target = name  if name
      event = document.createEvent("MouseEvents")
      event.initMouseEvent "click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 1, null
      a.dispatchEvent event
      true

    document.addEventListener "click", ((evt) ->
      if evt.target.href and evt.target.target == "_blank"
        evt.preventDefault()
        window.open evt.target.href, "_blank"
    ), false



  @client '/index.js': ->
    window.soc = @connect()
    self = @
    @on reload: ->
      d 'get items'
      view.entries []
      view.add i for i in @data
      # view.selected_entry view.entries[0]

    @on get_fullpage: ->
      console.log @data
      view.loading.summary @data.content
      view.loading = null
      $("html,body").animate({scrollTop: $(".selected").offset().top },0)

    # view.scraper_lock = false
    @on get_unread: ->
      console.log "start loading"
      view.sources []
      view.sources.push i for i in @data
      $("html,body").animate({scrollTop: 0 },0)
      # view.source_cursor 0

    ((bindings)->
      for k,v of bindings
        $(window).bind 'keydown', k , v
    )(
      j: (e)->
        if view.cursor() < view.entries().length-1
          view.cursor view.cursor()+1
          $("div.content").scrollTop($("div.content").scrollTop()+$(".selected").offset().top )
      k: (e)->
        if view.cursor() > 0
          view.cursor view.cursor()-1
          $("div.content").scrollTop($("div.content").scrollTop()+$(".selected").offset().top )
      s: (e)->
        if view.source_cursor() is null
          view.source_cursor 0
        else
          soc.emit 'done_reading',xmlUrl:view.selected_source().xmlUrl
          view.selected_source().cnt = 0
          view.source_cursor view.source_cursor()+1
        view.cursor 0
        view.context view.selected_source().src
        if $(".selected").length
          $("div.content").scrollTop($("h2#source_title").scrollTop()+$(".selected").offset().top )
        soc.emit 'reload',xmlUrl:view.selected_source().xmlUrl

      r: (e)->
        soc.emit 'get_unread',{}
      a: (e)->
        if view.source_cursor() is null
          view.source_cursor 0
        else
          soc.emit 'done_reading',xmlUrl:view.selected_source().xmlUrl
          view.selected_source().cnt = 0
          view.source_cursor view.source_cursor()-1
        view.cursor 0
        view.context view.selected_source().src
        if $(".selected").length
          $("div.content").scrollTop($("h2#source_title").scrollTop()+$(".selected").offset().top )
        soc.emit 'reload',xmlUrl:view.selected_source().xmlUrl
      g: (e)->
        url = view.selected_entry().link()
        unless view.loading
          view.loading = view.selected_entry()
          soc.emit 'get_fullpage',url:url
        else
          d 'onload another'

      o : (e)->
        window.open(view.selected_entry().link())
    )


    $ =>
      ko.applyBindings view
      @emit 'get_unread',{}
      @emit 'reload',{unread:true}

  ### ROOTING ###
  @get '/': ->
    @render index:
      title: 'my app'

  ### WebSocket ###
  @on connection: ->
    # article.find({unread:true}).sort(updated_parsed:-1).limit(20).toArray (e,items)=>
    #   @emit 'reload',items

  @on reload: ->
    query = {}
    query.unread = @data.unread or true
    query.xmlUrl = @data.xmlUrl if @data.xmlUrl
    page = @data.page or 1
    article.find(query).skip((page-1)*100).sort(updated_parsed:-1).limit(100).toArray (e,items)=>
    # article.find(xmlUrl:"http://bogusne.ws/index.rdf").skip((page-1)*20).sort(updated_parsed:-1).limit(20).toArray (e,items)=>
      d @data
      d query
      @emit 'reload',items

  @on done_reading: ->
    article.find(unread:true,xmlUrl:@data.xmlUrl).toArray (e,items)=>
      for i in items
        i.unread = false
        article.save i


  global.scraper_lock = false
  @on get_unread: ->
    article.find(unread:true).toArray (e,items)=>
      ret = []
      for i in items
        xmls = ret.map (i)-> i.xmlUrl
        if xmls.indexOf(i.xmlUrl) < 0
          i.cnt = 1
          ret.push {cnt:i.cnt,xmlUrl:i.xmlUrl,src:i.src}
        else
          ret[xmls.indexOf(i.xmlUrl)].cnt++
      d ret
      @emit "get_unread",ret

    unless global.scraper_lock
      d 'scraper working!'
      global.scraper_lock = true
      cp.exec "python crawler.py",(err,stdout,stderr)->
        console.log 'load done'
        global.scraper_lock = false
    else
      d 'scraper locked'


  @on get_fullpage: ->
    console.log '=========='
    url = @data.url
    console.log url
    self = @
    request uri:url ,(err,response,body )->
      readability.parse body, url, (result)->
        unless result.error
          self.emit 'get_fullpage',result
        else
          self.emit 'get_fullpage',content:body
