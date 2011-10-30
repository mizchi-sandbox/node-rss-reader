# def func
bind = (text,obj={})->
  if typeof text is "object"
    obj["data-bind"] = (k+":"+v for k,v of text)[0]
  else
    obj["data-bind"] = text
  obj
# template
div class:"container-fluid",->
  # ul class:"tabs",->
  #   li -> a class:'brand',href:"/",-> "RSS reader"
  #   li class:'active',-> a href:"#",->'home'
  #   li -> a href:"#",-> 'Profile'
  #   li -> a href:"#",-> 'Messages'
  #   li -> a href:"#",-> 'Settings'
  #   li -> a href:"#",-> 'Contact'

  div class:"sidebar",->
    # div "data-bind":"template: 'sidebar'"
    div bind template: "'sidebar'"
    script id:'sidebar',type:"text/html",->
      h5 '未読'
      ul id:"side-menu",->
        text "{{each(i,val) sources}}"
        li ->
          text "{{if i==view.source_cursor()}}"
          h2 '${val.src} [${cnt}]'
          text "{{else}}"
          p '${val.src} [${cnt}]'
          text "{{/if}}"
        text "{{/each}}"

  div class:"content",style:'height:1000px;overflow:hidden;',->
    h2 bind text:'context',{id:"source_title"}
    div bind template:"'articles-tmpl'"
    script id:'articles-tmpl',type:"text/html",->
      ul id:"articles",->
        text "{{each(i,e) entries}}"
        li ->
          p ->
            text "{{if i==view.cursor()}}"
            h3 class:"selected",-> a href:(h "${link}"),target:'_brank',-> h "${title}"
            p -> h "${src} : ${updated} "
            p class:'summary', -> "{{html summary}}"
            text "{{else}}"
            h3 -> a href:(h "${link}"),target:'_brank' ,-> h "${title}"
            text "{{/if}}"
        # p -> "no"
        text "{{/each}}"
    div style:"height:1300px;"
