cp = require 'child_process'
FeedParser = require('feedparser')
fs = require('fs')
xml2json = require('xml2json')
# readability = require('readability')

# model
mongolian = require 'mongolian'
ObjectId = require("mongolian").ObjectId
server = new mongolian()

db = server.db('feed')
col = db.collection('article')
col.ensureIndex(link:1)

get_text = (url,fn)->
  cp.exec 'python gettext.py '+url,(err,stdout,stderr)->
    fn stderr, stdout

# for LDR
# download from http://reader.livedoor.com/export/opml
opml = JSON.parse xml2json.toJson fs.readFileSync('export.xml').toString()

feeds = []
(dump = (obj)->
  if obj instanceof Array
    dump i for i in obj
  else if obj.outline?
    dump(obj.outline)
  else
    feeds.push obj
)(opml.opml.body.outline.outline)

parser = new FeedParser()
parser.on 'article', (data)->
  # console.log data
  col.findOne {link:data.link},(e,item)->
    return if e
    if item
      # console.log 'already exist:', data.title,data.link
    else
      col.insert data, -> console.log 'save done'
      console.log 'add:',data.title, data.link

loo = (items)->
  setTimeout ->
    f = items.shift()
    console.log f.title
    get_text f.xmlUrl,(err,data)->
      json =  JSON.parse xml2json.toJson data
      for k,v of json
        console.log k

      # parser.parseString data
      # console.log data
    loo items
  , 1 * 1000

console.log 'start'
loo feeds
