#!/usr/bin/env python
#-*- encoding:utf-8 -*-
import sys,urllib2
from time import sleep,mktime
from datetime import datetime

import feedparser
import pykf
from pymongo import Connection
from pyquery import PyQuery as pq

reload(sys)
sys.setdefaultencoding('utf-8')

#db
connection = Connection()
feed = connection.feed
article = feed.article

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


def save_entry(src):
    f = feedparser.parse(src["xmlUrl"])
    for e in f['entries']:
        item = article.find_one({"link":e.link.encode('utf8')})
        if not item:
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
