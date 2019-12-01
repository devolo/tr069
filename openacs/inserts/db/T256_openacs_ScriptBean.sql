-- MySQL dump 10.13  Distrib 5.7.27, for Linux (x86_64)
--
-- Host: localhost    Database: ACS
-- ------------------------------------------------------
-- Server version	5.7.27-0ubuntu0.18.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

USE ACS;
--
-- Table structure for table `ScriptBean`
--

DROP TABLE IF EXISTS `ScriptBean`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ScriptBean` (
  `name` varchar(250) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL,
  `script` longblob,
  `description` varchar(250) CHARACTER SET latin1 COLLATE latin1_bin DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ScriptBean`
--

LOCK TABLES `ScriptBean` WRITE;
/*!40000 ALTER TABLE `ScriptBean` DISABLE KEYS */;
INSERT INTO `ScriptBean` VALUES ('0 BOOTSTRAP',_binary 'call(\"__GPVof\", name=\"Device.ManagementServer.Username\");\r\n\r\nvar array = response[0].value.split(\"|\")\r\nvar ftype = array[0]\r\nvar cmdkey = cpe.Inform.DeviceId.SerialNumber+\"_\"+ftype;\r\nvar filename = cmdkey+\".file\";\r\nvar user = \"Admin\";\r\nvar pass = \"devolo\";\r\nvar delay = 0;\r\n\r\nvar url = \'http://telco0.public/protected/\'+filename;\r\n\r\n//****** LOGS ***************************************************************\r\nxMessage = xLogPrefix + \' Uploading \"\' + ftype;\r\nxMessage += xLogPrefix + \' to: \' +url;\r\nxMessage += xLogPrefix + \' Command Key: \' + cmdkey;\r\n//******* ACTION ************************************************************\r\ntry{\r\n   var response = cpe.Upload(cmdkey, ftype, url, user, pass, delay);\r\n   logger(xMessage);\r\n   logger (xLogPrefix + \" StartTime = \"+ response.StartTime);\r\n   logger (xLogPrefix + \" CompleteTime = \" + response.CompleteTime);\r\n   logger (xLogPrefix + \" status = \" + response.Status);\r\n} catch(e) {\r\n   logger(xLogPrefix + \" \" + e.message);\r\n}\r\n',''),('7 TRANSFER COMPLETE',_binary 'call(\"__GPVof\", name=\"Device.ManagementServer.Username\");\r\nvar array = response[0].value.split(\"|\");\r\nvar acsurl = array[1];\r\n\r\nvar result = acsurl+\"|{ \"\r\nvar i = 0\r\nfor(var propertyName in cpe.TransferComplete) {\r\n   if ( i > 0 ) {\r\n       result = result + \", \";\r\n   }\r\n   i = i + 1;\r\n   result = result + \" \\\"\"+propertyName+\"\\\" : \\\"\"+cpe.TransferComplete[propertyName]+\"\\\" \";\r\n}\r\n\r\nresult = result + \"}\";\r\n\r\nlogger(xLogPrefix + \" Result: \" + result);\r\n\r\ntry{\r\n       call(\"__SPVof\", key=\"Device.ManagementServer.Username\", value= result, type=\"xsd:string\",cmdk=\"dummy_string\");    \r\n} catch(e){\r\n       logger(xLogPrefix + \" \" + e.message);\r\n}\r\n',''),('Default',_binary 'logger(\"\\n*************************************************************************\");\r\n\r\nvar response = new Array();\r\n\r\ncall(\"__PrintDeviceInfo\");\r\n\r\nvar sEvent;\r\nvar sCommandKey;\r\n\r\nfor( event_number=0; event_number<=cpe.Inform.Event.length-1; event_number++ ) {\r\n    sEvent = cpe.Inform.Event[event_number].EventCode;\r\n    sCommandKey = cpe.Inform.Event[event_number].CommandKey;\r\n\r\n    var call_event = \"False\"\r\n    switch ( sEvent ) {\r\n        case \"0 BOOTSTRAP\":\r\n           call_event = \"True\";\r\n        break;\r\n        case \"7 TRANSFER COMPLETE\":\r\n           call_event = \"True\";\r\n        break;\r\n        case \"M Upload\":\r\n           call_event = \"True\";\r\n        break;\r\n    }\r\n\r\n    if ( call_event == \"True\" ) {\r\n       logger(xLogPrefix + \">>>> \"+sEvent+\" <<<<\");\r\n       call( sEvent );\r\n       logger(xLogPrefix + \">>>> \"+sEvent+\" END <<<<\");\r\n   } else {\r\n       logger(xLogPrefix + \">>>> IGNORING \"+sEvent+\" <<<<\");\r\n       logger(xLogPrefix + \">>>> \"+sEvent+\" END <<<<\");\r\n   }\r\n}\r\nlogger(\"\\n*************************************************************************\");','Default Skript that presents the Inform Message from the CPE and allows to call other Skripts depending on the event'),('M Upload',_binary 'call(\"__GPVof\", name=\"Device.ManagementServer.Username\");\r\nvar array = response[0].value.split(\"|\")\r\n\r\ntry{\r\n       call(\"__SPVof\", key=\"Device.ManagementServer.Username\", value=array[1], type=\"xsd:string\",cmdk=\"dummy_string\");    \r\n} catch(e) {\r\n       logger(xLogPrefix + \" \" + e.message);\r\n}\r\n\r\ntry{\r\n       call(\"__SPVof\", key=\"Device.ManagementServer.URL\", value=array[0], type=\"xsd:string\",cmdk=\"dummy_string\");    \r\n} catch(e) {\r\n       logger(xLogPrefix + \" \" + e.message);\r\n}\r\n',''),('__GPVof',_binary '// Remember to add the \".\" to the end of a partial key\r\n// call this script with  call(\"__GPVof\", name=\"Device.\");\r\n\r\n//******* LOG *******************************************************************\r\nxMessage = xLogPrefix + \' Getting Values from: \' + name;\r\n\r\n//******* ACTION ****************************************************************\r\nparameters = new Array();\r\nparameters.push(this.name)\r\n\r\ntry{\r\n    response = cpe.GetParameterValues(parameters);\r\n    logger(xMessage);\r\n\r\n    for(i=0;i<response.length;i++){\r\n        logger(xLogPrefix + \" --> \" + response[i].name + \" = \" + response[i].value);\r\n     }\r\n\r\n} catch(e) {\r\n   logger(xLogPrefix + \" \" + e.message);\r\n}\r\n',''),('__PrintDeviceInfo',_binary '// Get Serial Number and create Log-Prefix from Inform sent by device\r\n// Serial Number\r\nvar xLogPrefix = \"\\n* \"+cpe.Inform.DeviceId.SerialNumber+ \" \";\r\n\r\nxMessage = xLogPrefix + \" DeviceId:\";\r\nxMessage += xLogPrefix + \"    Manufacturer:  \" + cpe.Inform.DeviceId.Manufacturer;\r\nxMessage += xLogPrefix + \"    OUI:           \" + cpe.Inform.DeviceId.OUI;\r\nxMessage += xLogPrefix + \"    ProductClass:  \" + cpe.Inform.DeviceId.ProductClass;\r\nxMessage += xLogPrefix + \"    SerialNumber:  \" + cpe.Inform.DeviceId.SerialNumber;\r\nxMessage += xLogPrefix + \" Misc:\";\r\nxMessage += xLogPrefix + \"    MaxEnvelopes:  \" + cpe.Inform.MaxEnvelopes;\r\nxMessage += xLogPrefix + \"    RetryCount:    \" + cpe.Inform.RetryCount;\r\nxMessage += xLogPrefix + \"    CurrentTime:   \" + cpe.Inform.CurrentTime;\r\n\r\n// ------------------------------------------------------------------------------\r\n// Events\r\nxMessage += xLogPrefix + \" Events:\";\r\nfor (i = 0; i <= cpe.Inform.Event.length - 1; i++) {\r\n    xMessage += xLogPrefix + cpe.Inform.Event[i].EventCode + \" [\" + cpe.Inform.Event[i].CommandKey + \"]\";\r\n}\r\n\r\n// ------------------------------------------------------------------------------\r\n// Parameters\r\nxMessage += xLogPrefix + \" Params:\";\r\n\r\nfor (i = 0; i <= cpe.Inform.ParameterList.length - 1; i++) {\r\n    xMessage += xLogPrefix + \"    \" + cpe.Inform.ParameterList[i].Name + \"=\" + cpe.Inform.ParameterList[i].Value;\r\n    if (cpe.Inform.ParameterList[i].Name == \"InternetGatewayDevice.ManagementServer.ConnectionRequestURL\") {\r\n        ConnURL=cpe.Inform.ParameterList[i].Value;\r\n        xMessage += xLogPrefix + \"    ConURL:   \" + ConnURL;\r\n    }\r\n}\r\nxMessage += xLogPrefix + \"   *********************************************************\";\r\nlogger(xMessage);',''),('__SPVof',_binary '//\r\n//Use in other scripts\r\n// call(\'__SPVof\', key=\'keyname\', value=\'value\', type=\'type\', cmdk=\'cmdk\');\r\n// wrap in try-catch block\r\n// In case of boolean type quote the boolean expression i.e. value=\"false\"\r\n//\r\n\r\n\r\n//****** VARS *********************************************************************\r\nvar xkey = \"\";\r\nvar xvalue = \"\";\r\nvar xtype = \"\";\r\nvar xcmdk = \"\";\r\n\r\nif(key){\r\n  this.xkey = key;\r\n}\r\nelse{\r\n  throw new Error(\"useage: call(\'SPVof\', key=\'key\', value=\'value\', type=\'type\', cmdk=\'cmdk\');\")\r\n}\r\nif(value){\r\n   this.xvalue = value;\r\n}\r\nelse{\r\n  throw new Error(\"useage: call(\'SPVof\', key=\'key\', value=\'value\', type=\'type\', cmdk=\'cmdk\');\")\r\n}\r\nif(type){\r\n   this.xtype = type;\r\n}\r\nelse{\r\n  throw new Error(\"useage: call(\'SPVof\', key=\'key\', value=\'value\', type=\'type\', cmdk=\'cmdk\');\")\r\n}\r\nif(cmdk){\r\n  this.xcmdk = cmdk;\r\n}\r\nelse{\r\n  throw new Error(\"useage: call(\'SPVof\', key=\'key\', value=\'value\', type=\'type\', cmdk=\'cmdk\');\")\r\n}\r\n\r\n//******* LOG *********************************************************************\r\nxMessage = xLogPrefix + \' __SPVof(\' + this.xkey + \', \' + this.xvalue + \', \' + this.xtype + \', \' + this.xcmdk + \')\';\r\n\r\n\r\n//******* ACTION ******************************************************************\r\n\r\nvar parameters = new Array();\r\nparameters.push({ name:key, value:value, type:type});\r\n\r\ntry{\r\n    response = cpe.SetParameterValues(parameters, xcmdk);\r\n    logger(xMessage);\r\n\r\n} catch(e) {\r\n   logger(xLogPrefix + \" \" + e.message);\r\n}\r\n','');
/*!40000 ALTER TABLE `ScriptBean` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-09-03 13:58:46
