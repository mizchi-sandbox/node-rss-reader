#!/usr/bin/env python
#-*- encoding:utf-8 -*-
import sys,urllib2
from time import sleep,mktime
from datetime import datetime

import feedparser
import pykf
from pymongo import Connection
from pyquery import PyQuery as pq
import MeCab

reload(sys)
sys.setdefaultencoding('utf-8')

#db
connection = Connection()
feed = connection.feed
article = feed.article
# article.drop()
# entry.ensure_index("link",1)
# entry.ensure_index("words",1)

mecab = MeCab.Tagger("-Ochasen")
def get_source_by_opml(fname):
    root = pq(filename=fname)
    outline = root("outline")
    src = [{
            "title": unify(outline.eq(i).attr("title")),
            "xmlUrl":outline.eq(i).attr("xmlUrl")
            }
           for i in range(outline.length)
           if outline.eq(i).attr("xmlUrl")]
    return src


def unify(text):
    c = pykf.guess(text)
    if c is pykf.EUC:
        try:
            return unicode(text,  'euc-jp',"ignore")
        except:
            return text
    elif c in (pykf.SJIS,  pykf.JIS):
        try:
            return unicode(text,  'sjis',"ignore")
        except:
            return text
        return text
    return text


def get_words(node):
    if not node.next:
        return [node.surface]
    return [node.surface] + get_words(node.next)

def searchable(item,name):
    try:
        words = []
        node = mecab.parseToNode( item[name].encode("utf-8") )
        words = get_words( node )[1:-1]
        item["#"+name] = words
    except :
        pass

def save_entry(src):
    f = feedparser.parse(src["xmlUrl"])
    for e in f['entries']:
        item = article.find_one({"link":e.link.encode('utf8')})
        if not item:
            searchable(e,'title')
            time_keywords = ["updated_parsed",'published_parsed',"created_parsed"]

            for k,v in e.iteritems():
                if type(v) in [str,unicode]: e[k]=unify(v)

            for kws in time_keywords:
                if kws in e:
                    e[kws] = datetime.fromtimestamp(mktime(e[kws]))
            e["src"] = src["title"]
            e["xmlUrl"] = src["xmlUrl"]
            e["unread"] = True
            try:
                # print e.title
                article.insert(e)
                print 'save',e.title
            except:
                print 'err',e.keys()
        else:
            print 'exist'
            # print 'exist',e.title

if __name__ == '__main__':
    src = get_source_by_opml('export.xml')
    for s in src:
        save_entry(s)
