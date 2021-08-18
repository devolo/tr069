import argparse
import json
import paho.mqtt.client as mqtt
from datetime import datetime
from elasticsearch import Elasticsearch

class mqttuserdata:
    elasticIndex = ""
    mqttChannel = ""

# just add some data to the result
def add_data(mydata, prefix, result):
    data = {prefix:mydata}
    result.update(data)
    return result

# iterate over the list
def interate_list(mylist, prefix, result):
    for i in range(len(mylist)):
        if (isinstance(mylist[i], list)):
            result = interate_list(mylist[i], prefix+"["+str(i)+"]", result)
        elif (isinstance(mylist[i], dict)):
            result = interate_dict(mylist[i], prefix+"["+str(i)+"]", result)
        else:
            result = add_data(mylist[i], prefix+"["+str(i)+"]", result)
    return result

# iterate over the dictionary
def interate_dict(mydict, prefix, result):
    for element in mydict:
        if (isinstance(mydict[element], dict)):
            result = interate_dict(mydict[element], prefix+"."+element, result)
        elif (isinstance(mydict[element], list)):
            result = interate_list(mydict[element], prefix+"."+element, result)
        else:
            result = add_data(mydict[element],  prefix+"."+element, result)
    return result

# elasticsearch can not very well handle nested JSON objects; generate a flat obj
def flaten_json(payload):
    result = json.loads('{}')
    for myentry in payload:
        if (isinstance(payload[myentry], dict)):
            result = interate_dict(payload[myentry], myentry, result)
        elif (isinstance(payload[myentry], list)):
            result = interate_list(payload[myentry], myentry, result)
        else:
            result = add_data(payload[myentry], myentry, result)
    return result

# callback for when the client receives a CONNACK response from the server.
def on_connect(client, userdata, flags, rc):
    print("Connected with result code "+str(rc))
    # Subscribing in on_connect() means that if we lose the connection and
    # reconnect then subscriptions will be renewed.
    client.subscribe(userdata.mqttChannel)

# callback for when a PUBLISH message is received from the server.
def on_message(client, userdata, msg):
    # Decode UTF-8 bytes to Unicode, and convert single quotes
    # to double quotes to make it valid JSON string
    json_string=msg.payload.decode('utf8').replace("'", '"')
    mybody=json.loads(json_string)
    mybody.update({"rx_time": datetime.utcnow()})
    try:
        # push to the index
        es.index(mqttuserdata.elasticIndex, doc_type="json", body=flaten_json(mybody))
        print("RX      : "+userdata.elasticIndex+" "+msg.topic+" "+json_string)

    except:
        print("Ignoring: "+userdata.elasticIndex+" "+msg.topic+" "+json_string)

###########
# mainline
###########
parser = argparse.ArgumentParser(description='Simple mqtt2elasticsearch datapump')
parser.add_argument('--broker-port', dest="mqttPort", action='store', type=int, default=1883, choices=range(1000, 65535), help="MQTT broker port.")
parser.add_argument('--elastic-port', dest="elasticPort",  action='store', type=int, default=9200, choices=range(1000, 65535), help="elasticsearch port.")
parser.add_argument('--broker-name', dest="mqttBroker", action='store', default="localhost", help="Name of the MQTT broker.")
parser.add_argument('--channel', dest="mqttChannel", action='store', default="#", help="Name of the MQTT channel to subsctibe to.")
parser.add_argument('--elastic-name', dest="elasticServer", action='store', default="localhost", help="Name of the elasticsearch server.")
parser.add_argument('--index', dest="elasticIndex", action='store', default="my-index", help="Name of the elasticsearch index to store the data to.")
args = parser.parse_args()

mqttuserdata.elasticIndex = args.elasticIndex
mqttuserdata.mqttChannel = args.mqttChannel

es = Elasticsearch([{'host':args.elasticServer,'port':args.elasticPort}])

client = mqtt.Client(userdata=mqttuserdata)
client.on_connect = on_connect
client.on_message = on_message
client.connect(args.mqttBroker,args.mqttPort, 60)

client.loop_forever()
