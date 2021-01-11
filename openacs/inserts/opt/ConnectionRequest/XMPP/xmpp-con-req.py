#!/usr/bin/python

import sys 
import xmpp 

#ACS user beim prosody
username="acs" 
password="devolo" 

#XMPP server is 'xmpp' in our internal network, telco0 to externals
server = ('xmpp.public', 5222)
domain="xmpp.public"
resource=""

agent="cpe@xmpp.public/my_fixed_xmpp_resource"

crs_username="Admin" 
crs_password="devolo" 
iq_id="2342" 

def send_notify(conn):
    iq = xmpp.Iq(to = agent, frm=username + "@" + domain + resource, typ="get")
    iq.setID(iq_id)
    cr = iq.addChild(name = "connectionRequest", namespace="urn:broadband-forum-org:cwmp:xmppConnReq-1-0")
    cr.addChild(name = "username").setData(crs_username)
    cr.addChild(name = "password").setData(crs_password)
    conn.send(iq) 

def iq_handler(conn, iq):
    if iq.getID() == iq_id:
        sys.exit(0) 

jid = xmpp.JID(username + "@" + domain) 
connection = xmpp.Client(domain) 
connection.connect(server = server)
result = connection.auth(jid.getNode(), password, resource) 
connection.RegisterHandler("iq", iq_handler) 
send_notify(connection) 

while connection.Process(1):
    pass
