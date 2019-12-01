#!/usr/bin/env python
# -*- coding: utf-8 -*- 

from datetime import datetime, timedelta
import httplib
import urllib
import random, string
import sys
import socket


#helper to calculate signautre
def sign_request(Key, Text):
   from hashlib import sha1
   import hmac

   hashed = hmac.new(Key, Text, sha1)

   return hashed.hexdigest().upper()

#check input parameter length
if len(sys.argv)<3:
   print "usage: stun-con-req-test.py ip port"
   sys.exit()

address = sys.argv[1]
port= sys.argv[2]

data = {}

data['ts']=str((datetime.now()+timedelta(seconds=1)).strftime("%s"))
data['id']=str(random.randint(1000,9999))
data['un']='Admin'
data['cn']=''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(16))

Key = 'devolo'
Text = data['ts'] + data['id'] + data['un'] + data['cn']

data['sig']=sign_request(Key, Text)


url_string = 'http://'+address+':'+port+'?ts='+data['ts']+'&id='+data['id']+'&un='+data['un']+'&cn='+data['cn']+'&sig='+data['sig']

m='GET '+url_string+' HTTP/1.1\r\n'

print(m)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('0.0.0.0', 3478))

sock.sendto(m, (address, int(port)))
sock.sendto(m, (address, int(port)))
sock.sendto(m, (address, int(port)))
#sock.sendto(m, (address, int(port)))


