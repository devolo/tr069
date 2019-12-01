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
INSERT INTO `ScriptBean` VALUES ('0 BOOTSTRAP',_binary '//call (\"__DownloadFile\", _FILE_TYPE=\"X 000B3B CA Certificates\", _USE_SSL=false);\r\n//call (\"__DownloadFile\", _FILE_TYPE=\"X 000B3B Client Auth\", _USE_SSL=false);\r\nlogger (xLogPrefix + \"################\");\r\n\r\n',''),('7 TRANSFER COMPLETE',_binary '//\r\n// OnTransferComplete is called automatically by openACS. \r\n// During Calling the serial number of the device is not available.\r\n//\r\n\r\nsn=\"OnTransferComplete\";\r\nlogger(\"* \" + \">>>> start \"+sn+\" <<<<\");\r\n\r\nfor(var propertyName in cpe.TransferComplete) {\r\n   logger(\"* \" + propertyName + \' = \' + cpe.TransferComplete[propertyName]);\r\n}\r\n\r\nlogger(\"* \" + \">>>> end \"+sn+\" <<<<\");',''),('Default',_binary 'logger(\"\\n*************************************************************************\");\r\n\r\nvar response = new Array();\r\n\r\n//First print the device information\r\ncall(\"__PrintDeviceInfo\");\r\n\r\nvar sEvent;\r\nvar sCommandKey;\r\nvar executeEvent;\r\nvar sScriptToExecute;\r\n\r\nfor( i=0; i<=cpe.Inform.Event.length-1; i++ )\r\n{\r\n    sEvent = cpe.Inform.Event[i].EventCode;\r\n    sCommandKey = cpe.Inform.Event[i].CommandKey;\r\n\r\n    executeEvent = \"false\";\r\n    sScriptToExecute = sEvent;\r\n\r\n    logger(xLogPrefix + \">>>> \" + sEvent + \" <<<<\");\r\n\r\n    switch ( sEvent )\r\n    {\r\n        case \"0 BOOTSTRAP\":\r\n            executeEvent = \"true\";\r\n            break;\r\n\r\n        case \"1 BOOT\":\r\n            executeEvent = \"true\";\r\n            sScriptToExecute = \"0 BOOTSTRAP\";\r\n            break;\r\n\r\n        case \"2 PERIODIC\":\r\n            executeEvent = \"true\";\r\n            sScriptToExecute = \"0 BOOTSTRAP\";\r\n            break;\r\n\r\n        case \"7 TRANSFER COMPLETE\":\r\n            executeEvent = \"true\";\r\n            break;\r\n\r\n        case \"M Download\":\r\n            executeEvent = \"true\";\r\n            break;\r\n\r\n    }\r\n\r\n    if ( executeEvent === \"true\" ) {\r\n       logger(xLogPrefix + \">>>>>> calling \" + sScriptToExecute + \" <<<<<<\");\r\n       call(sScriptToExecute);\r\n       logger(xLogPrefix + \">>>>>> call \" + sScriptToExecute + \" END <<<<<<\");\r\n    } else {\r\n       logger(xLogPrefix + \">>>>>> ignored! <<<<\");\r\n    }\r\n\r\n    logger(xLogPrefix + \">>>> \" + sEvent + \" END <<<<\");\r\n}\r\nlogger(\"\\n*************************************************************************\");','Default Skript that presents the Inform Message from the CPE and allows to call other Skripts depending on the event'),('M Download',_binary 'for( i=0; i<=cpe.Inform.Event.length-1; i++ )\r\n{\r\n  logger(xLogPrefix + \'    >>>> CommandKey: \'+ cpe.Inform.Event[i].CommandKey + \'  <<<<\');\r\n}',''),('__DownloadFile',_binary '//****** VARS *********************************************************************\r\n\r\nvar _FILE_TYPE = this._FILE_TYPE;\r\nvar _USE_SSL  = this._USE_SSL;\r\n\r\nvar filename;\r\nvar filesize = 6408;  \r\nvar cmdkey = cpe.Inform.DeviceId.SerialNumber + \"_\" + _FILE_TYPE ;\r\nvar protocol;\r\nvar url = \'telco0.public/protected/\';\r\nvar user = \"Admin\"\r\nvar password = \"devolo\"\r\n\r\n//******* ACTION ******************************************************************\r\n\r\nif ( _USE_SSL ) {\r\n    protocol = \"https://\"\r\n} else {\r\n    protocol = \"http://\"\r\n}\r\n\r\nswitch ( _FILE_TYPE )\r\n{\r\n        case \"X 000B3B CA Certificates\":\r\n            filename = \"intermediate1.chain.cert.pem\";\r\n            break;\r\n\r\n        case \"X 000B3B Client Auth\":\r\n            filename = \"client.root1.cert\";\r\n            break;\r\n}\r\n\r\nxMessage = xLogPrefix + \' Downloading:  \' + _FILE_TYPE + \"  \" + filename;\r\nxMessage += xLogPrefix + \' from: \' + protocol + url;\r\nxMessage += xLogPrefix + \' Command Key: \' +cmdkey;\r\n\r\ntry{\r\n    var response = cpe.Download(cmdkey,_FILE_TYPE, protocol+url+filename,user,password,filesize,filename);\r\n    logger(xMessage);\r\n    logger (xLogPrefix + \" StartTime = \"+ response.StartTime);\r\n    logger (xLogPrefix + \" CompleteTime = \" + response.CompleteTime);\r\n    logger (xLogPrefix + \" status = \" + response.Status);\r\n    logger (xLogPrefix + \"--------------------------------------------------------------------------\");\r\n}\r\ncatch(e){\r\n    logger(xLogPrefix + \" \" + e.message);\r\n}\r\n',''),('__PrintDeviceInfo',_binary '// Get Serial Number and create Log-Prefix from Inform sent by device\r\n// Serial Number\r\nvar xLogPrefix = \"\\n* \"+cpe.Inform.DeviceId.SerialNumber+ \" \";\r\n\r\nxMessage = xLogPrefix + \" DeviceId:\";\r\nxMessage += xLogPrefix + \"    Manufacturer:  \" + cpe.Inform.DeviceId.Manufacturer;\r\nxMessage += xLogPrefix + \"    OUI:           \" + cpe.Inform.DeviceId.OUI;\r\nxMessage += xLogPrefix + \"    ProductClass:  \" + cpe.Inform.DeviceId.ProductClass;\r\nxMessage += xLogPrefix + \"    SerialNumber:  \" + cpe.Inform.DeviceId.SerialNumber;\r\nxMessage += xLogPrefix + \" Misc:\";\r\nxMessage += xLogPrefix + \"    MaxEnvelopes:  \" + cpe.Inform.MaxEnvelopes;\r\nxMessage += xLogPrefix + \"    RetryCount:    \" + cpe.Inform.RetryCount;\r\nxMessage += xLogPrefix + \"    CurrentTime:   \" + cpe.Inform.CurrentTime;\r\n\r\n// ------------------------------------------------------------------------------\r\n// Events\r\nxMessage += xLogPrefix + \" Events:\";\r\nfor (i = 0; i <= cpe.Inform.Event.length - 1; i++)\r\n    xMessage += xLogPrefix + cpe.Inform.Event[i].EventCode + \" [\" + cpe.Inform.Event[i].CommandKey + \"]\";\r\n\r\n// ------------------------------------------------------------------------------\r\n// Parameters\r\nxMessage += xLogPrefix + \" Params:\";\r\n\r\nfor (i = 0; i <= cpe.Inform.ParameterList.length - 1; i++) {\r\n    xMessage += xLogPrefix + \"    \" + cpe.Inform.ParameterList[i].Name + \"=\" + cpe.Inform.ParameterList[i].Value;\r\n    if (cpe.Inform.ParameterList[i].Name == \"InternetGatewayDevice.ManagementServer.ConnectionRequestURL\") {\r\n        ConnURL=cpe.Inform.ParameterList[i].Value;\r\n        xMessage += xLogPrefix + \"    ConURL:   \" + ConnURL;\r\n    }\r\n}\r\nxMessage += xLogPrefix + \"   *********************************************************\";\r\nlogger(xMessage);','');
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

-- Dump completed on 2019-09-13 16:56:21
